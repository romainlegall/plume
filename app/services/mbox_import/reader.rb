require "mail"

module MboxImport
  # Parcourt une archive mbox et fournit chaque message a un bloc.
  #
  # L'indexation prealable de toutes les cles d'un mbox de 10 Go prend plus
  # d'une minute et occupe de la memoire pour rien : on renonce volontairement a
  # l'index, et on avance sequentiellement, ce qui est le seul ordre utile pour
  # un import.
  class Reader
    DEFAULT_BATCH_PROGRESS = 1_000

    def initialize(path, limit: nil, skip: 0)
      @path = Pathname.new(File.expand_path(path.to_s))
      @limit = limit
      @skip = skip
    end

    def total_count
      count = 0
      each_message { count += 1 }
      count
    end

    def each_message
      reader = MboxReader.new(@path)
      index = 0

      reader.each_raw_message do |raw|
        index += 1
        next if index <= @skip

        yield parse(raw), index if block_given?
        break if @limit && index >= @skip + @limit
      end
    end

    private

    def parse(raw)
      Mail.new(raw)
    rescue StandardError
      nil
    end
  end
end
