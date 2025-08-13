Rails.application.routes.draw do
  namespace :api do
    namespace :v0 do
      post "submit", controller: :efile
      get "submissions-status", to: "efile#submissions_status"
      get "acks", controller: :efile
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "health" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
