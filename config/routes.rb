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
      get "broker_snapshots", to: "broker_snapshots#index"

      resources :employments, except: [:show] do
        member do
          post :fnf_settlement
        end
        resources :salary_components, except: [:show]
      end

      get "dhan/token_status", to: "dhan/token#status"
      post "dhan/refresh_token", to: "dhan/token#refresh"
      get "dhan/credential", to: "dhan/credential#show"
      put "dhan/credential", to: "dhan/credential#update"
      get "dhan/profile", to: "dhan/portfolio#profile"
      get "dhan/positions", to: "dhan/portfolio#positions"
      get "dhan/holdings", to: "dhan/portfolio#holdings"
      get "dhan/orders", to: "dhan/trades#orders"
      get "dhan/trade_book", to: "dhan/trades#trade_book"
      get "dhan/trade_history", to: "dhan/trades#trade_history"
      get "dhan/fund_limits", to: "dhan/portfolio#fund_limits"
      get "dhan/ledger", to: "dhan/portfolio#ledger"
      get "dhan/pnl_summary", to: "dhan/investments#pnl_summary"
      post "dhan/import_to_investments", to: "dhan/investments#import_to_investments"
      post "dhan/sync_investments", to: "dhan/investments#sync"
      get "dhan/sync_status", to: "dhan/investments#sync_status"
      post "dhan/import_trades", to: "dhan/trades#import"
      get "dhan/pnl_report", to: "dhan/trades#pnl_report"

      get "dashboard/overview", to: "dashboard#overview"
      get "reports/monthly", to: "reports#monthly"
      get "reports/financial_year", to: "reports#financial_year"
      post "ai/chat", to: "ai#chat"
    end
  end

  root to: "frontend#index"
  get "*path", to: "frontend#index", constraints: ->(req) { !req.path.start_with?("/api") && !req.path.start_with?("/rails") }
end
