Rails.application.routes.draw do
  root to: redirect('/clients')

  mount ActionCable.server => '/cable'

  resources :clients, except: [ :edit, :update ] do
    collection do
      post :fetch
    end
  end
end
