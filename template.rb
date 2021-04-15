# frozen_string_literal: true

def add_gems
  gem "rolify"
  gem "activerecord-import"
  gem "sidekiq"
  gem "sidekiq-cron", "~> 1.1"

  gem_group :development, :test do
    gem 'standard'
  end

  gem_group :test do
    gem "rspec-rails", "~> 5.0.0"
    gem "factory_bot_rails"
    gem "faker", git: "https://github.com/faker-ruby/faker.git", branch: "master"
  end
end

def add_sidekiq_config
  environment "config.active_job.queue_adapter = :sidekiq"

  insert_into_file "config/routes.rb",
    "require 'sidekiq/web'\n\n",
    before: "Rails.application.routes.draw do"

  content = <<~RUBY
                authenticate :user, lambda { |u| u.is_admin? } do
                  namespace :admin do
                    mount Sidekiq::Web => '/sidekiq'
                  end
                end
            RUBY
  insert_into_file "config/routes.rb", "#{content}\n", after: "Rails.application.routes.draw do\n"

  file "config/initializers/sidekiq.rb", <<~RUBY
    Sidekiq.configure_client do |config|
      config.redis = {url: ENV["REDIS_URL"]}
    end
    
    Sidekiq.configure_server do |config|
      config.redis = {url: ENV["REDIS_URL"]}
    end
    
    cron_jobs = [
      # {
      #   "name" => "generate_calorie_limits_for_tomorrow",
      #   "class" => "GenerateCalorieLimitsForTomorrowJob",
      #   "cron" => "0 10 * * *",
      #   "cron" => "* * * * *"
      # }
    ]
    
    if Sidekiq.server?
      Rails.application.config.after_initialize do
        Sidekiq::Cron::Job.load_from_array cron_jobs
      end
    end
  RUBY

end

def add_rolify_config
  file "config/initializers/rolify.rb", <<~RUBY
    Rolify.configure do |config|
      # Dynamic shortcuts for User class (user.is_admin? like methods). Default is: false
      config.use_dynamic_shortcuts
    
      # Configuration to remove roles from database once the last resource is removed. Default is: true
      config.remove_role_if_empty = false
    end
  RUBY
  
end

def do_initial_commit
  after_bundle do
    git :init
    git add: "."
    git commit: %Q{ -m 'Project initialized' }
  end
end

add_gems

add_sidekiq_config
add_rolify_config

do_initial_commit
