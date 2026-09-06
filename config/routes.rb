Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resource :session, only: [ :show, :create, :destroy ]
      resources :registrations, only: [ :create ]

      resources :categories, only: %i[index create update destroy]
      resources :expenses, only: %i[index create update destroy]
      resources :incomes, only: %i[index create update destroy] do
        resources :tax_deductions, only: %i[index create update destroy]
        collection do
          get :summary
          get :yearly
        end
        member do
          patch :toggle_received
        end
      end
      resources :budgets, only: %i[index create update destroy]

      resources :bills, only: %i[index create update destroy] do
        member do
          patch :toggle_paid
        end
      end

      resources :loans, only: [ :index, :show, :create, :update, :destroy ] do
        member do
          post :recalculate_schedule
          post :import_schedule
          patch "emi_schedules/:schedule_id", to: "loans#update_schedule", as: :update_schedule
        end
      end
      patch "emi_payments/:id/pay", to: "emi_payments#pay", as: :pay_emi
      
      get "debt_planner/summary", to: "debt_planner#summary"
      get "debt_planner/simulate", to: "debt_planner#simulate"

      resources :investments, only: %i[index create update destroy]
      get "tax/itr_summary", to: "tax#itr_summary"
      delete "tax/cache", to: "tax#invalidate_cache"
      get "tax/compare_regimes", to: "tax#compare_regimes"
      get "broker_snapshots", to: "broker_snapshots#index"

      resources :employments, only: %i[index create update destroy] do
        member do
          post :fnf_settlement
        end
        resources :salary_components, only: %i[index create update destroy]
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

      # ── DhanHQ API ──
      # Kept alongside the unified broker API: it exposes ledger, orders,
      # trade book and the CSV P&L report, which brokers/:broker_type lacks.
      namespace :dhan do
        get  "token_status",  to: "token#status"
        post "refresh_token", to: "token#refresh"

        get "credential", to: "credential#show"
        put "credential", to: "credential#update"

        get "profile",     to: "portfolio#profile"
        get "positions",   to: "portfolio#positions"
        get "holdings",    to: "portfolio#holdings"
        get "fund_limits", to: "portfolio#fund_limits"
        get "ledger",      to: "portfolio#ledger"

        get  "orders",        to: "trades#orders"
        get  "trade_book",    to: "trades#trade_book"
        get  "trade_history", to: "trades#trade_history"
        get  "pnl_report",    to: "trades#pnl_report"
        post "import_trades", to: "trades#import"

        get  "pnl_summary",           to: "investments#pnl_summary"
        get  "sync_status",           to: "investments#sync_status"
        post "sync_investments",      to: "investments#sync"
        post "import_to_investments", to: "investments#import_to_investments"
      end

      get "dashboard/overview", to: "dashboard#overview"
      get "reports/monthly", to: "reports#monthly"
      get "reports/financial_year", to: "reports#financial_year"
      post "ai/chat", to: "ai#chat"

      # ── Debt Clearance System ──
      # Debt registry (protected + settlement accounts)
      resources :debt_accounts do
        member do
          post :snapshot
        end
      end

      # Strategy layer driving the queue and forecasts
      resources :debt_strategies do
        member do
          patch :set_default
        end
      end

      # Salary/increment scenarios ("what if my income becomes ₹X?")
      resources :income_scenarios do
        member do
          patch :activate
        end
      end

      # Settlement pipeline: cases -> offers / contributions / documents
      resources :settlement_cases do
        member do
          post :record_payment
        end

        resources :settlement_offers, only: %i[create update]
        resources :settlement_contributions, only: %i[create destroy]
        resources :settlement_documents, only: %i[index create destroy]
      end

      # Debt clearance dashboard + simulators
      get "debt_dashboard/overview", to: "debt_dashboard#overview"
      get "debt_dashboard/forecast", to: "debt_dashboard#forecast"
      get "debt_dashboard/simulate_settlement", to: "debt_dashboard#simulate_settlement"
      get "debt_dashboard/export_csv", to: "debt_dashboard#export_csv"

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
