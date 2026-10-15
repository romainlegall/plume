module MboxImport
  # Lecteur mbox en flux.
  #
  # Une archive Gmail de 10 Go ne peut pas etre chargee en memoire. Ce lecteur
  # decoupe le fichier sur la ligne separatrice "From " en sautant d'une
  # fenetre de lecture a l'autre, et ne materialise qu'un message a la fois.
  #
  # Il remplace le gem mailbox, absent de Ruby 3.3 et introuvable sur RubyGems
  # sous ce nom (le gem existant est une bibliotheque JVM sans rapport).
  class MboxReader
    SEPARATOR = "\nFrom "
    ENVELOPE_PREFIX = "From "
    CHUNK_SIZE = 16 * 1024 * 1024
    COMPACT_THRESHOLD = 1024 * 1024
    # Presque tous les en-tetes tiennent dans 8 Ko. Les rebonds automatiques
    # (PostageApp et consorts) en produisent parfois plusieurs dizaines de
    # kilo-octets : une seconde fenetre, plus large, les rattrape.
    HEADER_WINDOW = 8 * 1024
    HEADER_WINDOW_LARGE = 512 * 1024

    def initialize(path, chunk_size: CHUNK_SIZE)
      @path = Pathname.new(path).expand_path
      @chunk_size = chunk_size
    end

    def each_raw_message
      raise ArgumentError, "archive introuvable : #{@path}" unless @path.file?

      File.open(@path, "rb") do |file|
        buffer = +""
        buffer.force_encoding(Encoding::BINARY)
        pos = 0
        eof = false

        loop do
          if !eof && buffer.bytesize - pos < COMPACT_THRESHOLD
            buffer = buffer.byteslice(pos, buffer.bytesize - pos) || +""
            buffer.force_encoding(Encoding::BINARY)
            pos = 0
            more = file.read(@chunk_size)
            if more
              buffer << more.b
            else
              eof = true
            end
          end

          start = locate_start(buffer, pos, eof)
          if start == :retry
            buffer = buffer.byteslice(buffer.bytesize - (SEPARATOR.bytesize - 1), SEPARATOR.bytesize - 1) || +""
            buffer.force_encoding(Encoding::BINARY)
            pos = 0
            next
          elsif start.nil?
            break
          end

          header_end = header_end(buffer, start)
          if header_end.nil?
            # Aucune fin d en-tetes, meme dans la fenetre large. Plutot que
            # d abandonner ce message, on le livre entierement jusqu au
            # separateur suivant : un message perdu pese plus lourd qu un
            # message mal analyse.
            header_end = start
          end

          buffer, eof = fill_until_separator(file, buffer, header_end, eof)

          separator_at = buffer.index(SEPARATOR, header_end)
          message_end = separator_at || buffer.bytesize

          raw = buffer.byteslice(start, message_end - start) || +""
          newline = raw.index("\n")
          raw = raw.byteslice(newline + 1, raw.bytesize) if newline
          yield raw

          pos = header_end
        end
      end
    end

    private

    def locate_start(buffer, pos, eof)
      if pos.zero? && buffer.start_with?(ENVELOPE_PREFIX)
        0
      else
        index = buffer.index(SEPARATOR, pos)
        return nil if index.nil? && eof
        return :retry if index.nil?

        index + 1
      end
    end

    # Position de la ligne vide qui clot les en-tetes, ou nil si introuvable.
    # Deux fenetres sont essayees pour ne pas copier 512 Ko a chaque message.
    def header_end(buffer, start)
      [ HEADER_WINDOW, HEADER_WINDOW_LARGE ].each do |taille|
        window = buffer.byteslice(start, taille) || +""
        crlf = window.index("\r\n\r\n")
        lf = window.index("\n\n")
        offset = if crlf && (lf.nil? || crlf < lf)
          crlf
        else
          lf
        end
        return start + offset if offset
      end

      nil
    end

    # Garantit que le message complet est dans le tampon avant de le rendre :
    # sans cela, un message a cheval sur deux fenetres serait tronque.
    def fill_until_separator(file, buffer, from, eof)
      until eof || buffer.index(SEPARATOR, from)
        more = file.read(@chunk_size)
        break if more.nil?

        buffer << more.b
      end
      [ buffer, eof ]
    end
  end
end
