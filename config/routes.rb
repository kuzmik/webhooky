Rails.application.routes.draw do
  root "home#index"

  resources :tokens, only: [:create], param: :uuid do
    resources :requests, only: [:index, :show, :destroy], controller: "requests", param: :uuid
    delete "requests", to: "requests#destroy_all", on: :member
    put "", to: "tokens#update", on: :member
  end

  get "tokens/:uuid", to: "tokens#show", as: :token, constraints: { uuid: /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i }

  # Webhook capture — catch-all, must be last
  match ":uuid(/:status)", to: "webhooks#capture", via: :all,
    constraints: { uuid: /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i, status: /[1-5]\d{2}/ }
end
