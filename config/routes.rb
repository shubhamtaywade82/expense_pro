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

      get "dashboard/overview", to: "dashboard#overview"
      get "reports/monthly", to: "reports#monthly"
      get "reports/financial_year", to: "reports#financial_year"
      post "ai/chat", to: "ai#chat"
    end
  end

  root to: "frontend#index"
  get "*path", to: "frontend#index", constraints: ->(req) { !req.path.start_with?("/api") && !req.path.start_with?("/rails") }
end
