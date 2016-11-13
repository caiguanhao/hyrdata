Rails.application.routes.draw do
  root to: redirect('/clients')

  mount ActionCable.server => '/cable'

  resources :clients
end
