require 'faraday'
require 'json'
require 'open-uri'

module Kanboard
  # Very thin wrapper around the Kanboard JSON-RPC 2.0 API
  # Mostly just gives more ruby-ish appearance to the various RPC calls
  class Client

    def initialize(config)
      @config = config
      @user_map = @config['user_map'] if @config['user_map']
    end

    def request(body = {})
      @connection ||= Faraday.new(url: "https://#{@config['host']}/#{@config['path']}") do |connection|
        connection.adapter Faraday.default_adapter
        connection.ssl.verify = false
        connection.basic_auth('jsonrpc', @config['api_token'])
      end

      body['jsonrpc'] = '2.0'
      body['id'] = '1'
      response = @connection.post do |req|
        #req.url '/jsonrpc.php'
        req.headers['Content-Type'] = 'application/json'
        req.body = body.to_json
      end

      if response.status != 200
        raise "Something unexpected happened during the request #{response.status}: #{response.body}"
      else
        parsed = JSON.parse(response.body)
        raise "[E] Error from Kanboard: #{parsed['error']}" if parsed['error']
        return parsed['result']
      end
    end

    ## Functions for listing things
    def projects
      request(method: 'getAllProjects')
    end

    def project(id)
      request(method: 'getProjectById', params: { project_id: id })
    end

    def columns(project_id)
      request(method: 'getColumns', params: { project_id: project_id })
    end

    def tasks(project_id, column_id = nil)
      all_tasks = request(method: 'getAllTasks', params: { project_id: project_id })
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
      request(method: 'getAllSubTasks', params: { task_id: task_id })
    end

    def tags(project_id)
      request(method: 'getTagsByProject', params: { project_id: project_id })
    end

    ## Functions for creating things
    def create_column(project_id, name)
      request(method: 'addColumn', params: { project_id: project_id, title: name })
    end

    def create_task(project_id, title, options = {})
      options['project_id'] = project_id
      options['title'] = title
      request(method: 'createTask', params: options)
    end

    # blob: A base64 encoded string representing the file to attach
    def create_task_file(task_id, project_id, filename, blob)
      request(method: 'createTaskFile',
              params: {
                task_id: task_id,
                project_id: project_id,
                filename: filename,
                blob: blob
              })
    end

    def create_tag(project_id, tag)
      options = { project_id: project_id,
                  tag: tag }
      puts "[I] Trying to create tag '#{tag}'"
      request(method: 'createTag', params: options)
    end

    def assign_tags(tags, task_id, project_id)
      if request(method: 'setTaskTags', params: { task_id: task_id,
                                                  project_id: project_id,
                                                  tags: tags })
        puts "[I] Tags #{tags.inspect} assigned to task ##{task_id}"
      else
        puts "[E] Error assigning tags #{tags.inspect} to task ##{task_id}"
      end
    end

    ## Functions for removing things
    def remove_all_task_files(task_id)
      request(method: 'removeAllTaskFiles', params: { task_id: task_id })
    end
  end
end
