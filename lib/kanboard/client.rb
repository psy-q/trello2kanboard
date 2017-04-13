require 'jsonrpc-client'
require 'faraday'

module Kanboard

  # Very thin wrapper around the Kanboard JSON-RPC 2.0 API
  # Mostly just gives more ruby-ish appearance to the various RPC calls
  class Client
    def initialize
      config_file = YAML::load_file('config/trello2kanboard.yml')
      @config = config_file['kanboard']
      @connection = Faraday.new { |connection|
        connection.adapter Faraday.default_adapter
        connection.ssl.verify = false
        connection.basic_auth('jsonrpc', @config['api_token']) 
      }
      @rpc = JSONRPC::Client.new("https://#{@config['host']}/#{@config['path']}", {connection: @connection})
    end

    def projects
      @rpc.getAllProjects
    end

  end

end
