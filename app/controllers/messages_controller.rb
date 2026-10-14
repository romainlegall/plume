class MessagesController < ApplicationController
  def mark_read
    message = Message.find(params[:id])
    message.mark_read!
    redirect_back_or_to_conversation(message)
  end

  def mark_unread
    message = Message.find(params[:id])
    message.mark_unread!
    redirect_back_or_to_conversation(message)
  end

  def toggle_star
    message = Message.find(params[:id])
    message.toggle_starred!
    redirect_back_or_to_conversation(message)
  end

  private

  def redirect_back_or_to_conversation(message)
    destination = params[:return_to].presence || conversation_path(message.conversation_id)
    redirect_to destination, allow_other_host: false, status: :see_other
  end
end
