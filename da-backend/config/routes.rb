Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  post "/tasks", to: "tasks#create"

  root to: "home#index"
  get "/quickstart", to: "home#quickstart", as: :quickstart
  get "/actions", to: "home#actions", as: :actions
  get "/connectors/new", to: "home#new_connector", as: :new_connector
end
