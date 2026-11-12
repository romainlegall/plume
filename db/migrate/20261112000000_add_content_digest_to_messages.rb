class AddContentDigestToMessages < ActiveRecord::Migration[8.1]
  def up
    add_column :messages, :content_digest, :string
    add_index :messages, :content_digest

    # Deux messages distincts peuvent partager un Message-ID (listes de
    # diffusion anciennes) : l'empreinte de contenu permet de ne fusionner que
    # les vraies copies, meme quand leur en-tete Date manque.
    say_with_time "Calcul de l'empreinte de contenu des messages existants" do
      Message.reset_column_information
      Message.find_each do |message|
        message.update_columns(content_digest: content_digest_for(message))
      end
    end
  end

  def down
    remove_index :messages, :content_digest
    remove_column :messages, :content_digest
  end

  private

  def content_digest_for(message)
    MboxImport::Fingerprint.content(
      from_email: message.from_email,
      subject: message.subject,
      to_raw: message.to_raw,
      cc_raw: message.cc_raw,
      body_text: message.body_text,
      body_html: message.body_html
    )
  end
end
