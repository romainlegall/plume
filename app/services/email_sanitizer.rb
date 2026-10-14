# Assainissement du HTML contenu dans les messages.
#
# Ce code affiche du HTML ecrit par des tiers, recueille sur vingt ans : scripts
# de tracking, pixels de suivi, liens javascript:, iframes, formulaires de
# vol d'identifiants. Rien de tout cela ne doit atteindre le navigateur.
#
# Les images distantes sont en plus neutralisees. Un message de 2006 chargerait
# des centaines de ressources sur des serveurs aujourd'hui disparus, chez des
# tiers qui n'ont rien a faire du fait que le message a ete ouvert.
module EmailSanitizer
  ALLOWED_TAGS = %w[
    a b blockquote br caption cite code col colgroup dd div dl dt em figcaption
    figure h1 h2 h3 h4 h5 h6 hr i img li ol p pre s small span strong sub sup
    table tbody td tfoot th thead tr u ul center font
  ].freeze

  ALLOWED_ATTRIBUTES = %w[href title alt width height align valign border cellpadding cellspacing colspan rowspan dir lang].freeze

  # Ressources chargeables depuis l'application : uniquement nos pieces
  # jointes locales.
  REMOTE_HOST = %r{\Ahttps?://}i

  # Balises retirees en bloc : scripts, cadres, formulaires.
  FORBIDDEN_TAGS = %w[
    script style iframe object embed applet form input button select textarea
    meta link base frame frameset noscript
  ].freeze

  class << self
    # inline_index : { content_id => attachment } pour substituer les images
    # embarquees par leur piece jointe locale.
    def sanitize(html, inline_index: {})
      return nil if html.blank?

      fragment = Loofah.fragment(html.to_s)

      FORBIDDEN_TAGS.each do |tag|
        fragment.css(tag).each(&:remove)
      end

      fragment.css("a").each { |node| harden_link(node) }
      fragment.css("img").each { |node| harden_image(node, inline_index) }
      fragment.css("table").each { |node| node.remove_attribute("style") }

      fragment.to_html
    rescue StandardError => e
      Rails.logger.warn("[EmailSanitizer] #{e.class}: #{e.message}")
      "<p>Le contenu HTML de ce message n'a pas pu etre affiche.</p>"
    end

    private

    def harden_link(node)
      href = node["href"].to_s
      return node.remove if href.blank?
      return node.remove unless href.match?(%r{\A(https?://|mailto:|tel:)}i)

      node["target"] = "_blank"
      node["rel"] = "noopener noreferrer nofollow"
    end

    # Trois cas pour une image :
    #   - referencee en cid: : elle est stockee avec le message, on la sert
    #     depuis nos propres Pieces jointes ;
    #   - distante : neutralisee, l'utilisateur peut la charger volontairement ;
    #   - deja locale : conservee.
    def harden_image(node, inline_index)
      src = node["src"].to_s.strip
      return node.remove if src.blank?

      if src.start_with?("cid:")
        key = src.delete("<>").delete_prefix("cid:").downcase
        attachment = inline_index[key]
        if attachment
          node["src"] = "/piece/#{attachment.id}"
          return node
        end
        return node.remove
      end

      return node unless src.match?(REMOTE_HOST)

      node["data-src-original"] = src
      node["src"] = "/image-bloquee.svg"
      node["data-src-bloquee"] = "1"
      node["class"] = [ node["class"], "remote-blocked" ].compact.join(" ").strip
    end
  end
end
