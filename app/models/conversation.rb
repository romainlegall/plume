class Conversation < ApplicationRecord
  has_many :messages, dependent: :destroy

  scope :recent, -> { order(latest_at: :desc) }

  validates :gm_thr_id, presence: true, uniqueness: true

  def recalculate!
    update_columns(
      message_count: messages.count,
      unread_count: messages.where(is_read: false).count,
      latest_at: messages.maximum(:sent_at)
    )
  end

  def participants
    messages.order(:sent_at).filter_map { |m| m.from_name.presence || m.from_email }.uniq
  end

  def participant_summary(limit: 3)
    names = participants
    return "" if names.empty?
    return names.first if names.size <= limit

    "#{names.first(limit).join(', ')} +#{names.size - limit}"
  end

  def increment_unread!
    Conversation.where(id: id).update_all("unread_count = unread_count + 1")
  end

  def decrement_unread!
    Conversation.where(id: id).update_all("unread_count = GREATEST(unread_count - 1, 0)")
  end

  def toggle_starred!
    update!(is_starred: !is_starred)
    messages.update_all(is_starred: is_starred)
  end

  # Le suivi d'une conversation vaut suivi de tous ses messages.
  def is_starred?
    messages.where(is_starred: true).exists?
  end
end
