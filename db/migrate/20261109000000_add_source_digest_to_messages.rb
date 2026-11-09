class AddSourceDigestToMessages < ActiveRecord::Migration[8.1]
  def up
    add_column :messages, :source_digest, :string
    add_index :messages, :source_digest

    # Renseigne l'empreinte des messages deja importes : sans cela, un import
    # repris ne pourrait pas les reconnaitre et les dupliquerait.
    say_with_time "Calcul de l'empreinte des messages existants" do
      Message.reset_column_information
      Message.find_each do |message|
        message.update_columns(source_digest: fingerprint_for(message))
      end
    end
  end

  def down
    remove_index :messages, :source_digest
    remove_column :messages, :source_digest
  end

  private

  def fingerprint_for(message)
    MboxImport::Fingerprint.call(
      sent_at: message.sent_at,
      from_email: message.from_email,
      subject: message.subject,
      to_raw: message.to_raw,
      cc_raw: message.cc_raw,
      body_text: message.body_text,
      body_html: message.body_html
    )
  end
end
