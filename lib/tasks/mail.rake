namespace :mail do
  desc "Importe un export Gmail Takeout (.mbox). Variables : MBOX, SKIP, LIMIT, PLUME_OWN_ADDRESSES"
  task import: :environment do
    path = ENV["MBOX"].presence || ARGV[0]
    skip = (ENV["SKIP"] || ARGV[1] || 0).to_i
    limit = (ENV["LIMIT"] || ARGV[2]).presence&.to_i

    if path.blank?
      abort "Usage : MBOX=/chemin/emails.mbox bin/rails mail:import"
    end

    source = Pathname.new(path).expand_path
    unless source.file?
      abort "Archive introuvable : #{source}"
    end

    own_addresses = ENV.fetch("PLUME_OWN_ADDRESSES", "").split(",").map(&:strip)

    puts "=" * 74
    puts "  plume — import d'archive Gmail"
    puts "=" * 74
    puts "  archive   : #{source} (#{(source.size / 1024.0**3).round(2)} Go)"
    puts "  reprise   : #{skip} message(s) deja traites"
    puts "  limite    : #{limit || 'aucune'}"
    puts "  pieces    : #{AttachmentStorage.root}"
    puts "  exclusion : #{MboxImport::MessageParser::SPAM_LABELS.join(', ')}"
    puts

    importer = MboxImport::Importer.new(
      path: source,
      skip: skip,
      limit: limit,
      own_addresses: own_addresses,
      logger: ->(line) { puts line }
    )

    stats = importer.call

    puts
    puts "=" * 74
    puts "  Termine en #{stats.elapsed.round}s"
    puts "=" * 74
    puts "  messages dans l'archive : #{stats.total}"
    puts "  importes               : #{stats.imported}"
    puts "  spam exclus            : #{stats.spam_skipped}"
    puts "  illisibles ignores     : #{stats.broken_skipped}"
    puts "  pieces jointes         : #{stats.attachments} (#{(stats.bytes / 1024.0**3).round(2)} Go)"
    puts "  conversations          : #{Conversation.count}"
    puts "  etiquettes             : #{Label.count}"
    puts
  end

  desc "Vide les donnees importees (conversations, messages, pieces jointes)"
  task reset: :environment do
    print "Supprimer tous les messages importes ? (oui/non) : "
    answer = $stdin.gets&.strip
    abort "Annule." unless answer == "oui"

    Attachment.delete_all
    MessageLabel.delete_all
    Message.delete_all
    Conversation.delete_all
    Label.delete_all

    root = AttachmentStorage.root
    FileUtils.rm_rf(Dir.glob(root.join("*"))) if root.exist?

    puts "Donnees effacees."
  end
end
