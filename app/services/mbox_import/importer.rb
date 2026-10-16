require "digest"
require "mail"

module MboxImport
  # Importe un export Gmail Takeout dans la base.
  #
  # Les enregistrements sont inseres par lots : un message par transaction
  # coute beaucoup plus cher en allers-retours reseau, surtout vers un
  # PostgreSQL distant.
  #
  # L'import est reprenable : relancer avec SKIP egal au nombre de messages
  # deja traites reprend la ou l'execution s'etait arretee.
  class Importer
    DEFAULT_BATCH = 500
    PROGRESS_EVERY = 500

    Stats = Struct.new(
      :total, :imported, :spam_skipped, :broken_skipped, :attachments, :bytes, :elapsed,
      keyword_init: true
    )

    def initialize(path:, skip: 0, limit: nil, batch_size: DEFAULT_BATCH, own_addresses: [], logger: nil)
      @reader = Reader.new(path, limit: limit, skip: skip)
      @batch_size = batch_size
      @parser = MessageParser.new(own_addresses)
      @logger = logger
      @stats = Stats.new(total: 0, imported: 0, spam_skipped: 0, broken_skipped: 0, attachments: 0, bytes: 0, elapsed: 0.0)
      @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def call
      preload_conversations
      preload_labels

      batch = []

      @reader.each_message do |mail, position|
        if mail.nil?
          @stats.broken_skipped += 1
          next
        end

        parsed = parse(mail)
        batch << parsed if parsed

        if batch.size >= @batch_size
          persist(batch)
          batch = []
        end

        report(position) if (position % PROGRESS_EVERY).zero?
      end

      persist(batch) if batch.any?
      @stats.total = @stats.imported + @stats.spam_skipped + @stats.broken_skipped
      recalculate_conversations

      @stats.elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started
      @stats
    end

    private

    def parse(mail)
      parsed = @parser.call(mail)
      if parsed.nil?
        @stats.spam_skipped += 1
        return nil
      end
      parsed
    rescue StandardError => e
      @stats.broken_skipped += 1
      debug("message illisible ignore : #{e.class}")
      nil
    end

    def persist(batch)
      return if batch.empty?

      Message.transaction do
        batch.each { |parsed| store(parsed) }
      end
    end

    def store(parsed)
      conversation = conversation_for(parsed)
      message = conversation.messages.create!(
        sent_at: parsed.sent_at,
        subject: parsed.subject,
        from_name: truncate(parsed.from_name, 200),
        from_email: truncate(parsed.from_email, 320),
        from_raw: parsed.from_raw,
        to_raw: parsed.to_raw,
        cc_raw: parsed.cc_raw,
        body_text: parsed.body_text,
        body_html: parsed.body_html,
        snippet: parsed.snippet,
        is_outgoing: parsed.is_outgoing,
        attachment_count: parsed.attachments.size,
        byte_size: parsed.attachments.sum { |a| a.data.bytesize }
      )

      attach_labels(message, parsed.labels)
      store_attachments(message, parsed.attachments)

      @stats.imported += 1
      message
    end

    def truncate(value, limit)
      return nil if value.blank?
      value.length > limit ? "#{value[0, limit]}…" : value
    end

    # Seuls les identifiants sont memorises : 50 000 messages peuvent partager
    # quelques milliers de conversations, et les recharger a chaque fois
    # multiplierait les requetes par le nombre de messages.
    def preload_conversations
      @conversations = Conversation.pluck(:gm_thr_id, :id).to_h
      @conversation_objects = {}
    end

    def preload_labels
      @labels = Label.pluck(:name, :id).to_h
      @label_objects = {}
    end

    # conversation_for et label_for doivent renvoyer des objets, jamais des
    # identifiants. Le prechargement ne garde que des id pour rester leger ;
    # un second cache recharge chaque enregistrement une seule fois.
    def conversation_for(parsed)
      key = parsed.gm_thr_id.presence ||
            "sans-fil-#{Digest::SHA1.hexdigest("#{parsed.from_raw}#{parsed.subject}")}"

      @conversations[key] ||= Conversation.create!(
        gm_thr_id: key,
        subject: parsed.subject,
        latest_at: parsed.sent_at
      ).id

      @conversation_objects[@conversations[key]] ||= Conversation.find(@conversations[key])
    end

    def label_for(name)
      @labels[name] ||= Label.create!(name: name, slug: slug_for(name)).id

      @label_objects[@labels[name]] ||= Label.find(@labels[name])
    end

    def attach_labels(message, label_names)
      label_names.each do |name|
        message.message_labels.create!(label: label_for(name))
      end
    end

    def slug_for(name)
      Label.parse(name).last
    end

    def store_attachments(message, attachments)
      attachments.each do |attachment|
        path = AttachmentStorage.store(attachment.sha256, attachment.data)
        message.attachments.create!(
          filename: attachment.filename,
          content_type: attachment.content_type,
          content_id: attachment.content_id,
          sha256: attachment.sha256,
          storage_path: path,
          byte_size: attachment.data.bytesize,
          is_inline: attachment.is_inline
        )
        @stats.attachments += 1
        @stats.bytes += attachment.data.bytesize
      end
    end

    def recalculate_conversations
      debug("mise a jour des compteurs des conversations")
      Conversation.in_batches { |batch| batch.each(&:recalculate!) }
    end

    def report(position)
      done = @stats.imported + @stats.broken_skipped
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started
      rate = done / elapsed.clamp(0.5, Float::INFINITY)

      @logger&.call(format(
        "  %<pos>7d messages  importes %<imported>6d  spam %<spam>5d  pieces %<att>6d  %<rate>5.1f msg/s  ecoule %<time>s",
        pos: position, imported: @stats.imported, spam: @stats.spam_skipped,
        att: @stats.attachments, rate: rate, time: elapsed.round
      ))
    end

    def debug(message)
      @logger&.call("  [debug] #{message}")
    end
  end
end
