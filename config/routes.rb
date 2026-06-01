Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  # Setup / onboarding
  get "setup" => "setup#new"
  post "setup" => "setup#create"

  # Account management
  get "account/password" => "account#edit_password", as: :edit_account_password
  patch "account/password" => "account#update_password", as: :update_account_password

  mount MissionControl::Jobs::Engine, at: "/jobs"

  namespace :admin do
    root to: "dashboard#index"
    get "settings", to: "dashboard#settings"
    patch "settings", to: "dashboard#update_settings"
    get "workspaces", to: "dashboard#workspaces"
    get "links", to: "dashboard#links"
    get "deep_links", to: "dashboard#deep_links"
    get "users/new", to: "dashboard#new_user", as: :new_user
    post "users", to: "dashboard#create_user", as: :create_user
    post "users/:id/ban", to: "dashboard#ban_user", as: :ban_user
    post "users/:id/unban", to: "dashboard#unban_user", as: :unban_user
  end

  # Development-only design system reference. Excluded from production routes.
  if Rails.env.development?
    namespace :dev do
      get "styleguide", to: "styleguide#show"
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "/.well-known/apple-app-site-association", to: "well_known#apple_app_site_association"
  get "/.well-known/assetlinks.json", to: "well_known#asset_links"

  # Defines the root path route ("/")
  root "home#index"
  get "about" => "home#about"
  get "privacy" => "home#privacy"
  get "pricing" => "home#pricing"
  get "self-host" => "home#self_host"
  get "dashboard" => "home#dashboard"
  get "dashboard/links" => "home#links", as: :dashboard_links

  get "articles/open_beta", to: "articles#open_beta", as: :open_beta_article

  get "sign_up" => "registrations#new"
  post "sign_up" => "registrations#create"
  delete "sign_up" => "registrations#destroy"

  # User responds to their own invitations (not scoped to workspace)
  resources :invitations, only: [] do
    member do
      patch :respond
    end
  end

  resources :workspace, only: [ :show, :update, :edit ] do
    resources :links, except: [ :new ] do
      get "visits" => "visits#index"
      member do
        put :social_tag
      end
    end
    resources :invitations, only: [ :create, :destroy ]
    resources :memberships, only: [ :destroy ]
    resource :billing, only: [ :show ], controller: "billing" do
      delete :cancel, on: :member
      get :manage, on: :member
    end
    resource :checkout, only: [ :new, :show ], controller: "checkout"
  end

  post "webhooks/polar", to: "webhooks/polar#receive"

  get "links/new" => "links#new", as: :new_link

  get "r" => "deep_links#bounce", as: :deep_link_bounce

  namespace :api do
    resources :links, only: [ :show ]
  end

  get "/:id" => "links#link", as: :link_redirect
end
