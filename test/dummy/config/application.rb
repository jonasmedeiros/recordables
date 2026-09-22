require "active_record/railtie"
require "active_storage/engine"
require "active_job/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_text/engine"

require "recordables"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.logger = Logger.new(IO::NULL)
    config.secret_key_base = "dummy_secret_key_base_for_the_test_suite"
    config.active_storage.service = :test
    config.active_job.queue_adapter = :test
    config.consider_all_requests_local = true
  end
end
