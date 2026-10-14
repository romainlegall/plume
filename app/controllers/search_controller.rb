class SearchController < ApplicationController
  include Paginatable

  PER_PAGE = 30

  def index
    @query = params[:q].to_s.strip
    return show_prompt if @query.blank?

    scope = Message.search(@query).includes(:attachments, :conversation).order(sent_at: :desc)
    @pagy, @messages = paginate(scope, per_page: PER_PAGE)
    @messages = @messages.with_highlight(@query).to_a
  end

  private

  def show_prompt
    @messages = []
    @pagy = nil
  end
end
