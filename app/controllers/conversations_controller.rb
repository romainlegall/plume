class ConversationsController < ApplicationController
  include Paginatable

  PER_PAGE = 50

  def index
    @label = current_label_slug
    @pagy, @conversations = paginate(conversation_scope, per_page: PER_PAGE)
  end

  def show
    @conversation = Conversation.includes(messages: [ :attachments, :labels ]).find(params[:id])
    @messages = @conversation.messages.includes(:attachments).order(:sent_at)

    # Ouvrir une conversation la marque lue, comme dans Gmail.
    @messages.each { |message| message.mark_read! unless message.is_read? }
    @conversation.reload

    # Colonne de liste conservee a gauche sur grand ecran.
    @sidebar_pagy, @sidebar_conversations = paginate(conversation_scope, per_page: PER_PAGE)
  end

  private

  def conversation_scope
    base = Conversation.includes(messages: [ :attachments, :labels ]).joins(:messages).distinct

    case current_label_slug
    when "inbox" then base.where(labels: { slug: "inbox" })
    when "sent" then base.where(messages: { is_outgoing: true })
    when "starred" then base.where(messages: { is_starred: true })
    when "archive" then base.where(labels: { slug: "archive" })
    else base.where(labels: { slug: current_label_slug })
    end
  end
end
