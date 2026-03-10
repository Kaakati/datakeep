require "sidekiq/web"

Rails.application.routes.draw do
  # Sidekiq Web UI for monitoring background jobs
  # TODO: Add authentication for production
  mount Sidekiq::Web => "/sidekiq"

  # Root path
  root "dashboard#index"

  # Authentication
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Registration (simple, no email confirmation)
  get "signup", to: "registrations#new"
  post "signup", to: "registrations#create"

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

  # Audit logs
  resources :audit_logs, only: [ :index, :show ]

  # Health check for app (not database health)
  get "up" => "rails/health#show", as: :rails_health_check
end
