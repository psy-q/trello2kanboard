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

    def columns(project_id)
      @rpc.getColumns(project_id)
    end

    def tasks(project_id, column_id = nil)
      all_tasks = @rpc.getAllTasks(project_id)
      if column_id != nil
        tasks = all_tasks.select { |task|
          task if task['column_id'].to_i == column_id.to_i
        }
      else
        tasks = all_tasks
      end
      tasks
    end

  end

end
