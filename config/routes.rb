Rails.application.routes.draw do
  root to: redirect('/clients')

  mount ActionCable.server => '/cable'

  resources :clients, except: [ :edit, :update ] do
    collection do
      post :fetch
    end
    member do
      post :downloads
    end
  end

  resources :brokers do
    member do
      post 'toggle-status'
    end
  end

  scope controller: :check do
    post 'version'
    post 'broker'
  end
end
