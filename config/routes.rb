require 'sidekiq/web'

Rails.application.routes.draw do
  # Mount Sidekiq web interface
  mount Sidekiq::Web => '/sidekiq'
  
  # API routes
  namespace :api do
    namespace :v1 do
      # Authentication
      post 'login', to: 'authentication#login'
      post 'logout', to: 'authentication#logout'
      get 'me', to: 'authentication#me'
      
      # Products
      resources :products do
        collection do
          get 'most_purchased_by_category'
          get 'top_revenue_by_category'
        end
      end
      
      # Purchases
      resources :purchases, only: [:create] do
        collection do
          get 'filtered'
          get 'count_by_granularity'
          get 'daily_report'
        end
      end
      
      # Categories
      resources :categories
      
      # Customers
      resources :customers
      
      # Audit Logs (for testing)
      resources :audit_logs, only: [:index] do
        collection do
          get 'recent'
          get 'by_entity/:entity_type/:entity_id', to: 'audit_logs#by_entity'
        end
      end
      
      # Scheduler management
      get 'scheduler/status', to: 'scheduler#status'
      post 'scheduler/trigger_daily_report', to: 'scheduler#trigger_daily_report'
      post 'scheduler/trigger_first_purchase_test', to: 'scheduler#trigger_first_purchase_test'
    end
  end
  
  # Health check
  get 'health', to: 'health#check'
end

