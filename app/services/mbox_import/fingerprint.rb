require "digest"

module MboxImport
  # Empreinte stable d'un message, pour ne jamais l'importer deux fois.
  #
  # L'identifiant RFC 5322 (Message-ID) suffit quand il est present, mais une
  # partie des messages anciens n'en a pas. On calcule donc aussi une empreinte
  # de contenu : deux copies du meme message produisent la meme valeur, deux
  # messages distincts (meme objet, meme expediteur) restent separes.
  module Fingerprint
    SEPARATOR = "\x1f".freeze

    module_function

    def call(sent_at:, from_email:, subject:, to_raw:, cc_raw:, body_text:, body_html:)
      canonical = [
        timestamp(sent_at),
        from_email,
        subject,
        to_raw,
        cc_raw,
        body_text,
        body_html
      ].map { |value| value.to_s }.join(SEPARATOR)

      Digest::SHA256.hexdigest(canonical)
    end

    # Format fixe (microsecondes comprises) pour que la valeur calculee a
    # l'import soit identique a celle relue depuis la base.
    def timestamp(value)
      return "" if value.nil?

      value.respond_to?(:utc) ? value.utc.iso8601(6) : value.to_s
    end
  end
end
