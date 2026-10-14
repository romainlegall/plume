class Label < ApplicationRecord
  # Etiquettes structurelles implementees par l'application, avec un nombre de
  # messages toujours vrai. Les autres viennent de X-Gmail-Labels.
  SYSTEM = {
    "inbox"   => "Boîte de réception",
    "sent"    => "Messages envoyés",
    "starred" => "Suivis",
    "archive" => "Archivés"
  }.freeze

  # Correspondance des etiquettes Gmail brutes vers nos etiquettes systeme.
  GMAIL_ALIASES = {
    "Boîte de réception" => "inbox",
    "Messages envoyés" => "sent",
    "Suivis" => "starred",
    "Archivés" => "archive"
  }.freeze

  # Signales comme spam par Gmail ou par IMAP : jamais importe.
  SPAM = [ "Spam", "IMAP_$Junk" ].freeze

  has_many :message_labels, dependent: :destroy
  has_many :messages, through: :message_labels

  scope :alphabetical, -> { order(:name) }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  def self.system?(slug)
    SYSTEM.key?(slug.to_s)
  end

  def system?
    self.class.system?(slug)
  end

  def display_name
    self.class::SYSTEM[slug] || name
  end

  # Normalise une etiquette Gmail en couple [nom lisible, slug interne].
  # Le slug finit dans une URL : il doit donc se limiter aux caracteres acceptes
  # par la route, trait d'union compris.
  def self.parse(gmail_label)
    name = gmail_label.to_s.strip
    slug = GMAIL_ALIASES[name] || name.parameterize(separator: "_").gsub(/[^a-z0-9_-]/, "")
    [ name, slug.presence || "sans_etiquette" ]
  end
end
