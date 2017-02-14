CatarseMoip::Engine.routes.draw do
  resources :moip, only: [], path: 'payment/moip' do
    collection do
      post 'create_notification', to: "notifications#create", as: 'create_notification'
      get 'js'
    end
    member do
      post :moip_response
      get :review
      post :get_moip_token
    end
  end
end
