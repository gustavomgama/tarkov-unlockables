Rails.application.routes.draw do
  resources :items, only: [:index, :show] do
    collection do
      get :autocomplete
    end
  end
  resources :tasks, only: [:index, :show]

  get "up" => "rails/health#show", as: :rails_health_check

  root "items#index"
end
