require "sidekiq/web"

Rails.application.routes.draw do
  # Stripe webhook (no auth, no CSRF)
  namespace :webhooks do
    post "stripe", to: "stripe#create"
  end

  # Admin namespace
  namespace :admin do
    root "dashboard#index"
    resources :users
    resources :database_configs, only: [ :index, :show ]
    resources :storage_backends do
      member do
        post :test_connection
      end
    end
    resources :backup_jobs, only: [ :index, :show ]
    resources :backups, only: [ :index, :show ]
    resources :audit_logs, only: [ :index, :show ]
    resources :pricing_configs, only: [ :index, :edit, :update ]
    resources :subscription_plans do
      member do
        post :sync_to_stripe
        patch :toggle
      end
      collection do
        post :seed
      end
    end
    namespace :enterprise do
      resource :quote, only: [ :show, :create ], controller: "quote_calculator", as: :quote_calculator
      resources :quotes, only: [ :index, :show, :create ] do
        member do
          post :send_invoice
        end
      end
    end
  end

  # Sidekiq Web UI — admin-only
  constraints ->(req) { User.find_by(id: req.session[:user_id])&.admin? } do
    mount Sidekiq::Web => "/sidekiq"
  end

  # Root path
  root "dashboard#index"

  # Authentication
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Registration (simple, no email confirmation)
  get "signup", to: "registrations#new"
  post "signup", to: "registrations#create"

  # OAuth callbacks
  get "auth/google_oauth2/callback", to: "oauth_callbacks#google_oauth2"
  get "auth/failure", to: "oauth_callbacks#failure"

  # Database configurations
  resources :database_configs do
    member do
      post :test_connection
      post :vacuum
      post :kill_query
    end
    resources :health_checks, only: [ :index ]
  end

  # Health checks grid overview (all databases)
  resources :health_checks, only: [ :index ]

  # Storage backends
  resources :storage_backends do
    member do
      post :test_connection
    end
  end

  # Backup jobs with nested backups
  resources :backup_jobs do
    member do
      post :run_now
      post :pause
      post :resume
    end
    resources :backups, only: [ :index, :show, :destroy ] do
      member do
        post :restore
        get :download
      end
    end
  end

  # Standalone backups listing (all backups)
  resources :backups, only: [ :index, :show ]

  # Sync jobs (auto-sync from primary to target servers)
  resources :sync_jobs do
    member do
      post :run_now
      post :pause
      post :resume
    end
  end

  # Restores
  resources :restores, only: [ :index, :show, :new, :create ]
  post "upload_restore", to: "restores#upload"

  # Notification channels
  resources :notification_channels do
    member do
      post :test
    end
  end

  # Billing & Subscriptions
  get "billing", to: "billing#show"
  resource :subscription, only: [:create, :update, :destroy]
  post "stripe_portal", to: "stripe_portal#create"

  # Audit logs
  resources :audit_logs, only: [ :index, :show ]

  # Health check for app (not database health)
  get "up" => "rails/health#show", as: :rails_health_check
end
