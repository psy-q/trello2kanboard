require 'faraday'
require 'json'

module Kanboard

  # Very thin wrapper around the Kanboard JSON-RPC 2.0 API
  # Mostly just gives more ruby-ish appearance to the various RPC calls
  class Client

    def self.connection
      config_file = YAML::load_file('config/trello2kanboard.yml')
      @config = config_file['kanboard']
      @connection ||= Faraday.new(url: "https://#{@config['host']}/#{@config['path']}") do |connection|
        #connection.response :logger
        connection.adapter Faraday.default_adapter
        connection.ssl.verify = false
        connection.basic_auth('jsonrpc', @config['api_token']) 
      end
    end

    def request(body = {})
      connection = Kanboard::Client.connection
      body['jsonrpc'] = '2.0'
      body['id'] = '1'
      response = connection.post do |req|
        #req.url '/jsonrpc.php'
        req.headers['Content-Type'] = 'application/json'
        req.body = body.to_json
      end

      if response.status != 200
        raise "Some shit happened during the request #{response.status}: #{response.body}" 
      else
        parsed = JSON.parse(response.body)['result']
        raise "Some shit happened in the response" if parsed == false
        return parsed
      end
    end

    def initialize
    end

    def projects
      request(method: 'getAllProjects')
    end

    def project(id)
      request(method: 'getProjectById', params: {project_id: id})
    end

    def columns(project_id)
      request(method: 'getColumns', params: {project_id: project_id})
    end

    def tasks(project_id, column_id = nil)
      all_tasks = request(method: 'getAllTasks', params: {project_id: project_id})
      if column_id != nil
        tasks = all_tasks.select { |task|
          task if task['column_id'].to_i == column_id.to_i
        }
      else
        tasks = all_tasks
      end
      tasks
    end

    def subtasks(task_id)
      request(method: 'getAllSubTasks', params: {task_id: task_id})
    end
   
    def create_column(project_id, name)
      request(method: 'addColumn', params: {project_id: project_id, name: name})
    end

    def create_task(project_id, title, options = {})
      options['project_id'] = project_id
      options['title'] = title
      request(method: 'createTask', params: options)
    end
  end
end
