Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resource :session, only: [ :show, :create, :destroy ]
      resources :registrations, only: [ :create ]

      resources :categories, except: [ :show ]
      resources :expenses, except: [ :show ]
      resources :incomes, except: [ :show ] do
        resources :tax_deductions, except: [:show]
        collection do
          get :summary
          get :yearly
        end
        member do
          patch :toggle_received
        end
      end
      resources :budgets, except: [ :show ]

      resources :bills, except: [ :show ] do
        member do
          patch :toggle_paid
        end
      end

      resources :loans, only: [ :index, :show, :create, :destroy ]
      patch "emi_payments/:id/pay", to: "emi_payments#pay", as: :pay_emi
      
      get "debt_planner/summary", to: "debt_planner#summary"
      get "debt_planner/simulate", to: "debt_planner#simulate"

      resources :investments, except: [ :show ]
      get "tax/itr_summary", to: "tax#itr_summary"
      delete "tax/cache", to: "tax#invalidate_cache"
      get "tax/compare_regimes", to: "tax#compare_regimes"
      get "broker_snapshots", to: "broker_snapshots#index"

      resources :employments, except: [:show] do
        member do
          post :fnf_settlement
        end
        resources :salary_components, except: [:show]
      end

      # ── Unified Broker API ──
      get "brokers/available", to: "brokers#available"
      get "brokers/connected", to: "brokers#connected"
      post "brokers/connect", to: "brokers#connect"

      scope "brokers/:broker_type" do
        get "status",            to: "brokers#status"
        get "profile",           to: "brokers#profile"
        get "holdings",          to: "brokers#holdings"
        get "positions",         to: "brokers#positions"
        get "fund_limits",       to: "brokers#fund_limits"
        get "pnl_summary",       to: "brokers#pnl_summary"
        get "sync_status",       to: "brokers#sync_status"

        post "import_investments", to: "brokers#import_investments"
        post "import_trades",      to: "brokers#import_trades"
        post "sync",               to: "brokers#sync"

        patch "credential",      to: "brokers#update_credential"
        delete "",               to: "brokers#destroy_credential"
      end

      get "dashboard/overview", to: "dashboard#overview"
      get "reports/monthly", to: "reports#monthly"
      get "reports/financial_year", to: "reports#financial_year"
      post "ai/chat", to: "ai#chat"

      resources :tax_documents, only: %i[index create destroy] do
        member do
          patch :verify
          patch :correct
          get :preview
        end
      end

      namespace :itr_filing do
        get :prefill
        get :download
        get :readiness
        get :checklist
      end

      get "net_worth", to: "net_worth#show"
      get "debt_plans/summary", to: "debt_plans#summary"
      get "debt_plans/simulate", to: "debt_plans#simulate"
      resources :debt_plans, only: %i[index create]

      # Notification Center
      resources :notifications, only: [:index, :destroy] do
        collection do
          get :unread_count
          post :mark_all_read
        end
        member do
          patch :mark_read
          patch :archive
        end
      end
    end
  end

  root to: "frontend#index"
  get "*path", to: "frontend#index", constraints: ->(req) { !req.path.start_with?("/api") && !req.path.start_with?("/rails") }
end
