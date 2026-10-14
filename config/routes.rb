Rails.application.routes.draw do
  root "conversations#index"

  get "boite/:slug", to: "conversations#index", as: :label_conversations, constraints: { slug: /[a-z0-9_-]+/ }
  get "conversation/:id", to: "conversations#show", as: :conversation
  get "recherche", to: "search#index", as: :search

  post "message/:id/lu", to: "messages#mark_read", as: :mark_message_read
  post "message/:id/non-lu", to: "messages#mark_unread", as: :mark_message_unread
  post "message/:id/suivi", to: "messages#toggle_star", as: :toggle_message_star

  get "piece/:id", to: "attachments#show", as: :attachment
  get "piece/:id/telecharger", to: "attachments#download", as: :download_attachment

  get "up" => "rails/health#show", as: :rails_health_check
end