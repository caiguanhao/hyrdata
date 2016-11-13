set :rails_env, 'production'
set :branch, 'master'
set :bundle_flags, "-j4 --deployment"

server 'hyr.cgh.io', user: 'deploy', roles: %w{app db web}
