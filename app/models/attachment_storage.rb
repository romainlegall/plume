# Racine de stockage des pieces jointes sur le disque.
#
# En local : plume/data. Sur le NAS, le compose monte /data depuis un dossier
# local du NAS. Ne jamais pointer vers un partage SMB : le stockage des
# pieces jointes y serait lent et, sur ce materiel, deja fragile.
module AttachmentStorage
  DEFAULT_ROOT = Rails.root.join("data").freeze
  SHA256 = /\A[0-9a-f]{64}\z/

  # Leve quand un chemin enregistre sort du repertoire de stockage.
  class OutsideStorageRoot < StandardError; end

  class << self
    def root
      Pathname.new(ENV.fetch("PLUME_DATA_DIR", DEFAULT_ROOT.to_s))
    end

    # Ecrit une piece jointe et renvoie son chemin relatif au repertoire racine.
    # Le contenu est adresse par son empreinte : un fichier deja present n'est
    # pas reecrit, ce qui rend l'import repetable et les doublons gratuits.
    #
    # L'empreinte est validee avant de servir de chemin : sans cela, une
    # valeur corrompue permettrait d'ecrire hors du repertoire de stockage.
    def store(sha256, data)
      raise ArgumentError, "empreinte invalide" unless sha256.to_s.match?(SHA256)

      relative = Attachment.storage_relative_path(sha256)
      absolute = root.join(relative)
      return relative if absolute.exist?

      FileUtils.mkdir_p(absolute.dirname)
      File.binwrite(absolute, data)
      relative
    end

    def path_for(relative)
      # Un chemin enregistre ne doit jamais permettre de lire hors du repertoire
      # de stockage, meme si la base a ete alteree.
      absolute = root.join(relative.to_s).expand_path
      root_expanded = root.expand_path
      unless absolute.to_s.start_with?(root_expanded.to_s + File::SEPARATOR)
        raise OutsideStorageRoot, "chemin de piece jointe hors du repertoire de stockage : #{relative}"
      end

      absolute
    end

    def exist?(relative)
      path_for(relative).exist?
    end
  end
end
