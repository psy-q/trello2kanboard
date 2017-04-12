require 'jsonrpc-client'

module Kanboard

  class Client
    def initialize
      config_file = YAML::load_file('config/trello2kanboard.yml')
      @config = config_file['kanboard']
      @rpc = JSONRPC::Client.new("https://jsonrpc:#{@config['api_token']}@#{@config['host']}/#{@config['path']}")
    end

    def getBoards
      @rpc.getBoards
    end

  end

end
