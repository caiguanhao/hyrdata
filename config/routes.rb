Rails.application.routes.draw do
  root to: 'pages#home'
  get 'sytlist', to: 'pages#sytlist'

  mount ActionCable.server => '/cable'

  resources :clients, except: [ :edit, :update ] do
    collection do
      post :fetch
    end
    member do
      post :downloads
    end
  end

  resources :accounts, except: [ :show, :destroy ] do
    collection do
      post :done
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
    post 'account'
  end
end
