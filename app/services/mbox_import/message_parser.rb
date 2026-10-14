require "digest"

module MboxImport
  # Convertit un message Mail en enregistrement pour Message.
  #
  # Les messages de 2006 a 2010 viennent de logicielsvaries : encodages
  # casses, pieces jointes sans nom, HTML completement casse. Chaque etape
  # degradee doit rester silencieuse : mieux vaut un message partiellement
  # affiche qu'un message absent.
  class MessageParser
    SPAM_LABELS = Label::SPAM
    MAX_FILENAME = 200

    Parsed = Struct.new(
      :sent_at, :subject, :from_name, :from_email, :from_raw, :to_raw, :cc_raw,
      :body_text, :body_html, :labels, :attachments, :is_outgoing, :gm_thr_id, :snippet,
      keyword_init: true
    )

    ParsedAttachment = Struct.new(
      :filename, :content_type, :content_id, :sha256, :data, :is_inline,
      keyword_init: true
    )

    def initialize(own_addresses)
      @own_addresses = own_addresses.map { |a| a.to_s.downcase }.compact_blank
    end

    def call(mail)
      labels = gmail_labels(mail)
      return nil if spam?(labels)

      parsed_text = plain_text_part(mail)
      html = extract_html(mail)

      Parsed.new(
        sent_at: sent_at(mail),
        subject: clean_subject(decode(mail.subject)),
        from_name: address_name(mail[:from]),
        from_email: address_email(mail[:from]),
        from_raw: truncate(decode(mail[:from]), 500),
        to_raw: truncate(decode(mail[:to]), 1000),
        cc_raw: truncate(decode(mail[:cc]), 1000),
        body_text: parsed_text,
        body_html: html,
        labels: labels,
        attachments: extract_attachments(mail, referenced_cids(html)),
        is_outgoing: outgoing?(mail),
        gm_thr_id: thread_id(mail),
        snippet: Message.build_snippet(plain_source(parsed_text) || plain_source(plain_text_from_html(html)))
      )
    end

    # Pour un extrait de liste, tout ce qui ressemble a une balise doit disparaitre :
    # certains clients servent du HTML dans une partie annoncee text/plain, avec
    # une declaration ou un commentaire avant la premiere balise.
    def plain_source(text)
      return nil if text.blank?

      text.match?(%r{</?[a-z][^>]*>}i) ? plain_text_from_html(text) : text
    end

    private

    # Identifiant de conversation fourni par Gmail. Present dans 100 % de
    # l'archive : le regroupement est donc fidele a ce que Gmail affichait.
    def thread_id(mail)
      value = mail[:x_gm_thrid] || mail[:x_gm_thr_id]
      value.to_s.strip.presence
    rescue StandardError
      nil
    end

    def decode(value)
      return nil if value.nil?

      Mail::Encodings.value_decode(value.to_s)
    rescue StandardError
      value.to_s
    end

    def truncate(value, limit)
      return nil if value.blank?
      value.length > limit ? "#{value[0, limit]}…" : value
    end

    def clean_subject(subject)
      return "(sans objet)" if subject.blank?

      subject.squish
    end

    def gmail_labels(mail)
      raw = mail[:x_gmail_labels]
      return [] if raw.blank?

      decode(raw).to_s.split(",").map { |label| label.strip }.reject(&:empty?)
    end

    def spam?(labels)
      labels.any? { |label| SPAM_LABELS.include?(label) }
    end

    def address_name(field)
      return nil if field.blank?

      decoded = decode(field)
      name = decoded.to_s[/"?([^"<,]+)"?\s*</, 1] || decoded.to_s.split("<").first
      name&.strip.presence
    rescue StandardError
      nil
    end

    def address_email(field)
      return nil if field.blank?

      match = decode(field).to_s[/<([^>]+)>/, 1]
      (match || decode(field).to_s.split(",").first).to_s.strip.presence
    rescue StandardError
      nil
    end

    def outgoing?(mail)
      from = address_email(mail[:from])
      return false if from.blank? || @own_addresses.empty?

      @own_addresses.any? { |own| from.casecmp?(own) }
    end

    def sent_at(mail)
      date = mail.date
      return mail.received.first&.at if date.blank? && mail.received.any?

      date
    rescue StandardError
      nil
    end

    # Certains messages declarent text/plain mais servent du HTML.
    def plain_text_part(mail)
      return nil if mail.multipart?

      body = mail.text_part&.decoded || mail.decoded
      return nil if body.blank?

      text = normalize(body)
      return plain_text_from_html(text) if html?(text)

      text
    rescue StandardError
      nil
    end

    def html?(text)
      text.to_s.lstrip.start_with?("<!doctype", "<html", "<head", "<body", "<?xml")
    end

    def extract_html(mail)
      html = mail.html_part&.decoded
      return nil if html.blank?

      normalize(html)
    rescue StandardError
      nil
    end

    def normalize(body)
      return nil if body.blank?

      body.to_s.dup.force_encoding("UTF-8").scrub("").gsub(/\r\n?/, "\n").gsub(/\n{3,}/, "\n\n").strip.presence
    end

    # Version texte d'un corps HTML, pour l'extrait affiche dans la liste.
    # Les newsletters n'ont presque jamais de partie text/plain : sans cela la
    # liste afficherait des balises.
    def plain_text_from_html(html)
      return nil if html.blank?

      fragment = Nokogiri::HTML5.fragment(html.to_s)
      fragment.css("script, style, head, noscript, title, meta").each(&:unlink)
      fragment.text.gsub(/\s+/, " ").strip.presence
    rescue StandardError
      html.to_s.gsub(/<[^>]*>/, " ").gsub(/\s+/, " ").strip.presence
    end

def extract_attachments(mail, referenced_cids = [])
      parts = mail.all_parts.reject(&:multipart?)
      found = []

      parts.each do |part|
        inline = inline_part?(part, referenced_cids)
        next unless part.attachment? || inline || present_filename?(part)

        data = begin
          part.body.decoded
        rescue StandardError
          nil
        end
        next if data.blank?

        found << ParsedAttachment.new(
          filename: filename_for(part),
          content_type: part.mime_type.to_s.downcase,
          content_id: part.cid.to_s.strip.delete("<>").presence,
          sha256: Digest::SHA256.hexdigest(data),
          data: data,
          is_inline: inline
        )
      end

      found
    end

    # Les Content-ID cites dans le corps du message, en minuscules.
    def referenced_cids(html)
      return [] if html.blank?

      html.to_s.scan(/cid:([^"'\s>)]+)/i).flatten.map { |cid| cid.delete("<>").strip.downcase }.uniq
    rescue StandardError
      []
    end

    # Une image est incorporee au corps si le HTML y fait reference par son
    # Content-ID. Certains clients la declarent malgre tout comme piece jointe :
    # se fier a la disposition ferait|display| disparaitre l'image du message.
    def inline_part?(part, referenced)
      cid = part.cid.to_s.delete("<>").strip.downcase
      return false if cid.blank?
      return false unless part.mime_type.to_s.start_with?("image/")

      referenced.include?(cid)
    end

    def present_filename?(part)
      part.filename.present? || part[:content_name].present?
    end

    def filename_for(part)
      name = decode(part.filename).to_s.strip
      name = nil if name.empty?
      name ||= decode(part[:content_name]).to_s.strip.presence
      name ||= generated_name(part)
      truncate(sanitize_filename(name), MAX_FILENAME)
    end

    def generated_name(part)
      extension = File.extname(part.filename.to_s)
      extension = ".#{part.mime_type.to_s.split("/").last}" if extension.empty? && part.mime_type.present?
      "piece-#{Digest::SHA1.hexdigest(part.to_s)[0, 10]}#{extension}"
    end

    def sanitize_filename(name)
      base = File.basename(name.to_s.tr("\\", "/"))
      cleaned = base.gsub(/[\u0000-\u001f\u007f]/, "").strip
      cleaned = cleaned.gsub(/[^\p{L}\p{N}._ -]/, "_")
      cleaned = cleaned.gsub(/\s+/, " ").presence || "piece"
      cleaned.start_with?(".") ? "piece#{cleaned}" : cleaned
    end
  end
end
