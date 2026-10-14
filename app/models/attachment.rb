class Attachment < ApplicationRecord
  belongs_to :message

  scope :inline, -> { where(is_inline: true) }
  scope :regular, -> { where(is_inline: false) }

  validates :storage_path, presence: true

  IMAGE_TYPES = %r{\Aimage/}i

  def image?
    content_type.to_s.match?(IMAGE_TYPES)
  end

  def inline?
    is_inline?
  end

  # Le nom est renvoye dans l'en-tete Content-Disposition lors du
  # telechargement : les caracteres de controle y sont interdits.
  def display_name
    candidate = filename.presence || "piece-#{id}"
    candidate.to_s.gsub(/[\u0000-\u001f\u007f]/, "").strip.presence || "piece-#{id}"
  end

  # Les pieces jointes sont rangees par empreinte : deux messages qui partagent
  # le meme fichier ne le stockent qu'une fois sur le disque.
  def self.storage_relative_path(sha256)
    sha = sha256.to_s
    File.join(sha[0, 2], sha[2, 2], sha)
  end

  def absolute_path(root = AttachmentStorage.root)
    File.join(root, storage_path)
  end

  def human_size
    return "0 o" if byte_size.zero?

    units = %w[o Ko Mo Go]
    value = byte_size.to_f
    unit = units.shift
    while value >= 1024 && units.any?
      value /= 1024
      unit = units.shift
    end
    format("%.0f %s", value, unit)
  end
end
