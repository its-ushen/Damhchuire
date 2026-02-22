Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  post "/tasks", to: "tasks#create"
  get "/sdk/catalog.json", to: "sdk_catalog#show"

  root to: "home#index"
  get "/quickstart", to: "home#quickstart", as: :quickstart
  get "/actions", to: "home#actions", as: :actions, constraints: ->(request) { request.format.html? }
  get "/connectors/new", to: "home#new_connector", as: :new_connector

  resources :actions, as: :api_actions, only: %i[index show create update], defaults: { format: :json } do
    member do
      post :enable
      post :disable
    end
  end

  resources :action_invocations, only: %i[index show], defaults: { format: :json }
  resources :credentials, only: %i[index create update destroy], defaults: { format: :json }
end
