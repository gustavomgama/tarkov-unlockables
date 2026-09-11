Rails.application.routes.draw do
  resources :items, only: [ :index, :show ]
  resources :tasks, only: [ :index, :show ] do
    collection do
      get :chains
    end
  end

  namespace :admin do
    resources :items, :tasks, :requirements, :rewards, :leads_tos,
              :barter_unlocks, :craft_unlocks, :offer_unlocks, :previous_tasks
    root to: "dashboard#index"
  end

  get "/admin", to: redirect("/admin/items")

  get "up" => "rails/health#show", as: :rails_health_check

  root "items#index"
  resources :favorites, only: [ :create, :destroy ], param: :item_id
end
