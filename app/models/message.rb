class Message < ApplicationRecord
  MAX_SNIPPET = 220
  SEARCH_BODY_LIMIT = 30_000

  belongs_to :conversation
  has_many :attachments, dependent: :destroy
  has_many :message_labels, dependent: :destroy
  has_many :labels, through: :message_labels

  scope :recent, -> { order(sent_at: :desc) }
  scope :unread, -> { where(is_read: false) }

  # Recherche plein texte. websearch_to_tsquery accepte la syntaxe d'un moteur
  # de recherche : "expression exacte", -exclusion, mot1 OR mot2. Le trigramme
  # rattrape ce que le stemming francais laisse passer (une faute de frappe, un
  # mot que le dictionnaire ne connait pas, un radical proche).
  scope :search, ->(query) {
    next all if query.blank?

    where(
      "messages.search_document @@ websearch_to_tsquery('french', :tsq) OR messages.subject ILIKE :like",
      tsq: query.to_s,
      like: "%#{sanitize_sql_like(query.to_s.strip)}%"
    )
  }

  # Extrait surroundant le terme recherche, avec les correspondances balisees.
  scope :with_highlight, ->(query) {
    sql = sanitize_sql_array([ <<~SQL, query.to_s ])
      messages.*,
      ts_headline(
        'french',
        coalesce(body_text, subject, ''),
        websearch_to_tsquery('french', ?),
        'StartSel=<mark>, StopSel=</mark>, MaxFragments=1, MaxWords=35, MinWords=12, FragmentDelimiter= … '
      ) AS highlight
    SQL
    select(sql)
  }

  validates :subject, length: { maximum: 998 }, allow_nil: true

  def sender_label
    from_name.presence || from_email.presence || from_raw.presence || "(sans expediteur)"
  end

  def recipients
    [ to_raw, cc_raw ].compact_blank.join(", ")
  end

  # Extrait de texte plat pour la liste des messages. Les anciens clients de
  # messagerie laissaient des sauts de ligne multiples partout.
  def self.build_snippet(text)
    return nil if text.blank?

    cleaned = text.gsub(/[ \t]+/, " ").gsub(/\s*\n\s*/, " ").strip
    cleaned.length > MAX_SNIPPET ? "#{cleaned[0, MAX_SNIPPET]}…" : cleaned
  end

  def self.normalize_body(text)
    return nil if text.blank?

    text.gsub(/\r\n?/, "\n").gsub(/\n{3,}/, "\n\n").strip
  end

  def mark_read!
    return true if is_read?

    update!(is_read: true)
    conversation.decrement_unread!
    true
  end

  def mark_unread!
    return false unless is_read?

    update!(is_read: false)
    conversation.increment_unread!
    true
  end

  def toggle_starred!
    update!(is_starred: !is_starred)
  end

  def has_attachments?
    attachment_count.positive?
  end

  def inline_images
    attachments.inline.select(&:image?)
  end

  def regular_attachments
    attachments.regular.order(:filename)
  end
end
