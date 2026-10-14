class AddSearchVectorToMessages < ActiveRecord::Migration[8.1]
  # Colonne generee : PostgreSQL la calcule a l'ecriture, elle ne peut pas
  # diverger du contenu. Le corps est tronque a 30 000 caracteres pour garder
  # l'index GIN a une taille raisonnable sur une base_NAS : le texte integral
  # reste stocke dans body_text, seul l'index de recherche est abrege.
  SEARCH_EXPRESSION = <<~SQL.squish
    to_tsvector('french',
      coalesce(subject, '') || ' ' ||
      coalesce(from_name, '') || ' ' ||
      coalesce(from_email, '') || ' ' ||
      left(coalesce(body_text, ''), 30000))
  SQL

  def up
    add_column :messages, :search_document, :virtual, type: :tsvector, as: SEARCH_EXPRESSION, stored: true
    add_index :messages, :search_document, using: :gin
    add_index :messages, :subject, using: :gin, opclass: :gin_trgm_ops, name: "index_messages_on_subject_trgm"
  end

  def down
    remove_index :messages, :subject, name: "index_messages_on_subject_trgm"
    remove_index :messages, :search_document
    remove_column :messages, :search_document
  end
end