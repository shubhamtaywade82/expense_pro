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

      resources :investments, except: [ :show ]
      get "tax/itr_summary", to: "tax#itr_summary"
      delete "tax/cache", to: "tax#invalidate_cache"
      get "broker_snapshots", to: "broker_snapshots#index"

      resources :employments, except: [:show] do
        member do
          post :fnf_settlement
        end
        resources :salary_components, except: [:show]
      end

      # Multi-broker routes (generic, broker-agnostic)
      get "brokers", to: "brokers#index"
      get "brokers/:broker/token_status", to: "brokers#token_status"
      post "brokers/:broker/refresh_token", to: "brokers#refresh_token"
      get "brokers/:broker/credential", to: "brokers#credential_show"
      put "brokers/:broker/credential", to: "brokers#credential_update"
      get "brokers/:broker/profile", to: "brokers#profile"
      get "brokers/:broker/positions", to: "brokers#positions"
      get "brokers/:broker/holdings", to: "brokers#holdings"
      get "brokers/:broker/orders", to: "brokers#orders"
      get "brokers/:broker/trade_book", to: "brokers#trade_book"
      get "brokers/:broker/trade_history", to: "brokers#trade_history"
      get "brokers/:broker/fund_limits", to: "brokers#fund_limits"
      get "brokers/:broker/ledger", to: "brokers#ledger"
      get "brokers/:broker/pnl_summary", to: "brokers#pnl_summary"
      post "brokers/:broker/import_to_investments", to: "brokers#import_to_investments"
      post "brokers/:broker/sync", to: "brokers#sync"
      get "brokers/:broker/sync_status", to: "brokers#sync_status"
      post "brokers/:broker/import_trades", to: "brokers#import_trades"
      get "brokers/:broker/pnl_report", to: "brokers#pnl_report"

      # Backward-compatible Dhan aliases (delegate to generic broker routes)
      get "dhan/token_status", to: redirect("/api/v1/brokers/dhan/token_status")
      post "dhan/refresh_token", to: redirect("/api/v1/brokers/dhan/refresh_token")
      get "dhan/credential", to: redirect("/api/v1/brokers/dhan/credential")
      put "dhan/credential", to: redirect("/api/v1/brokers/dhan/credential")
      get "dhan/profile", to: redirect("/api/v1/brokers/dhan/profile")
      get "dhan/positions", to: redirect("/api/v1/brokers/dhan/positions")
      get "dhan/holdings", to: redirect("/api/v1/brokers/dhan/holdings")
      get "dhan/orders", to: redirect("/api/v1/brokers/dhan/orders")
      get "dhan/trade_book", to: redirect("/api/v1/brokers/dhan/trade_book")
      get "dhan/trade_history", to: redirect("/api/v1/brokers/dhan/trade_history")
      get "dhan/fund_limits", to: redirect("/api/v1/brokers/dhan/fund_limits")
      get "dhan/ledger", to: redirect("/api/v1/brokers/dhan/ledger")
      get "dhan/pnl_summary", to: redirect("/api/v1/brokers/dhan/pnl_summary")
      post "dhan/import_to_investments", to: redirect("/api/v1/brokers/dhan/import_to_investments")
      post "dhan/sync_investments", to: redirect("/api/v1/brokers/dhan/sync")
      get "dhan/sync_status", to: redirect("/api/v1/brokers/dhan/sync_status")
      post "dhan/import_trades", to: redirect("/api/v1/brokers/dhan/import_trades")
      get "dhan/pnl_report", to: redirect("/api/v1/brokers/dhan/pnl_report")

      get "dashboard/overview", to: "dashboard#overview"
      get "reports/monthly", to: "reports#monthly"
      get "reports/financial_year", to: "reports#financial_year"
      post "ai/chat", to: "ai#chat"

      get "net_worth", to: "net_worth#show"
      get "debt_plans/summary", to: "debt_plans#summary"
      get "debt_plans/simulate", to: "debt_plans#simulate"
      resources :debt_plans, only: %i[index create]
    end
  end

  root to: "frontend#index"
  get "*path", to: "frontend#index", constraints: ->(req) { !req.path.start_with?("/api") && !req.path.start_with?("/rails") }
end
