# We look for places in this order:
# - CONNECTORS_CONFIG environment variable
# - here: /../../config/connectors.yml
CONFIG_FILE = ENV['CONNECTORS_CONFIG'] || File.join(__dir__, '../../..', 'config', 'connectors.yml')
DEFAULT_PASSWORD = 'changeme'

puts "Parsing #{CONFIG_FILE} configuration file."

Config.setup do |config|
  config.evaluate_erb_in_yaml = false

  config.schema do
    required(:version).value(:string)
    required(:repository).value(:string)
    required(:revision).value(:string)

    required(:http).hash do
      required(:host)
      required(:port).value(:integer)
      required(:api_key).value(:string)
      required(:deactivate_auth)
      required(:connector).value(:string)
    end

    required(:worker).hash do
      required(:max_thread_count).value(:integer)
    end
  end
end

Config.load_and_set_settings(CONFIG_FILE)
