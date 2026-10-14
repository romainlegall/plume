class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_label_slug, :sidebar_labels, :reading_conversation?

  private

  # Sur un petit ecran, la liste et la conversation ne peuvent pas cohabiter :
  # celle qui n'est pas consultee est masquee. Sur grand ecran, les deux
  # colonnes restent visibles.
  def reading_conversation?
    action_name == "show"
  end

  def current_label_slug
    slug = params[:slug].presence || "inbox"
    Label::SYSTEM.key?(slug) || Label.exists?(slug: slug) ? slug : "inbox"
  end

  # Etiquettes structurelles d'abord, puis celles de Gmail, chacune avec son
  # compteur de messages non lus.
  def sidebar_labels
    @sidebar_labels ||= SidebarLabels.new.call
  end
end
