require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/generators")
loader.ignore("#{__dir__}/recordables/railtie.rb")
loader.setup

module Recordables
end

require "recordables/railtie" if defined?(Rails::Railtie)
