Rails.application.routes.draw do
  resources :items, only: [ :index, :show ] do
    collection do
      # Typeahead for the search field. Collected routes come before :id, so
      # /items/search never resolves as an item id.
      get :search
    end
  end
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

  # PWA files are rendered from app/views/pwa/*. Without these routes the
  # service worker registration in application.js 404s on every page load.
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, defaults: { format: :json }
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker, defaults: { format: :js }

  root "items#index"
  resources :favorites, only: [ :index, :create, :destroy ], param: :item_id
end
