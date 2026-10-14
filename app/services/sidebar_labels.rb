# Construit la liste des etiquettes affichees dans la colonne de gauche.
#
# Les quatre etiquettes systemes existent toujours, meme quand aucun message ne
# les porte : sans cela la barre laterale changerait de forme apres un import
# partiel, ce qui est deroutant.
class SidebarLabels
  Entry = Struct.new(:slug, :name, :unread, :total, :system, keyword_init: true)

  SYSTEM_ORDER = %w[inbox sent starred archive].freeze

  def call
    system = SYSTEM_ORDER.map do |slug|
      build(slug, Label::SYSTEM.fetch(slug), unread_for_system(slug), total_for_system(slug), true)
    end

    custom = Label.where.not(slug: SYSTEM_ORDER)
                  .order(:name)
                  .map { |label| build(label.slug, label.name, unread_for(label.id), label.messages.count, false) }

    (system + custom).reject { |entry| !entry.system && entry.total.zero? }
  end

  private

  def build(slug, name, unread, total, system)
    Entry.new(slug: slug, name: name, unread: unread, total: total, system: system)
  end

  def unread_for(label_id)
    Message.joins(:message_labels).where(message_labels: { label_id: label_id }, is_read: false).count
  end

  def total_for(label_id)
    Message.joins(:message_labels).where(message_labels: { label_id: label_id }).count
  end

  def label_id_for(slug)
    Label.find_by(slug: slug)&.id
  end

  # Les etiquettes systemes se definissent par la presence d'un label Gmail
  # correspondant, ce qui evite de maintenir un second jeu de criteres.
  def unread_for_system(slug)
    id = label_id_for(slug)
    id ? unread_for(id) : 0
  end

  def total_for_system(slug)
    id = label_id_for(slug)
    id ? total_for(id) : 0
  end
end
