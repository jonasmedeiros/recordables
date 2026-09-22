require "rails/railtie"

module Recordables
  class Railtie < ::Rails::Railtie
    initializer "recordables.macros" do
      ActiveSupport.on_load(:active_record) do
        extend Recordables::Macros
      end
    end
  end
end
