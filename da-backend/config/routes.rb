Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  post "/tasks", to: "tasks#create"
  get "/sdk/catalog.json", to: "sdk_catalog#show"

  root to: "home#index"
  get "/quickstart", to: "home#quickstart", as: :quickstart
  get "/actions/manage", to: "home#manage_actions", as: :manage_actions, constraints: ->(request) { request.format.html? }
  get "/actions", to: "home#actions", as: :actions, constraints: ->(request) { request.format.html? }
  get "/credentials", to: "home#credentials", as: :credentials_page, constraints: ->(request) { request.format.html? }

  resources :actions, as: :api_actions, only: %i[index show create update destroy], defaults: { format: :json } do
    member do
      post :enable
      post :disable
    end
  end

  resources :action_invocations, only: %i[index show], defaults: { format: :json }
  resources :credentials, only: %i[index create update destroy], defaults: { format: :json }
end
