require 'faraday'
require 'json'
require 'open-uri'

module Kanboard
  # Very thin wrapper around the Kanboard JSON-RPC 2.0 API
  # Mostly just gives more ruby-ish appearance to the various RPC calls
  class Client

    def initialize(config)
      @config = config
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

    def all_tasks(project_id)
      request(method: 'getAllTasks', params: { project_id: project_id })
    end

    def subtasks(task_id)
      request(method: 'getAllSubTasks', params: { task_id: task_id })
    end

    def tags(project_id)
      request(method: 'getTagsByProject', params: { project_id: project_id })
    end

    def project_users(project_id)
      request(method: 'getProjectUsers', params: { project_id: project_id })
    end

    def swimlanes(project_id)
      request(method: 'getAllSwimlanes', params: { project_id: project_id })
    end

    def swimlane_by_name(project_id, name)
      request(method: 'getSwimlaneByName', params: { project_id: project_id, name: name })
    end

    def search(project_id, string)
      request(method: 'searchTasks', params: { project_id: project_id, query: string })
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

    def create_comment(task_id, user_id, text)
      request(method: 'createComment', params: { task_id: task_id,
                                                 content: text,
                                                 user_id: user_id })
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
    def remove_column(column_id)
      request(method: 'removeColumn', params: { column_id: column_id })
    end

    def remove_task(task_id)
      request(method: 'removeTask', params: { task_id: task_id })
    end

    def remove_all_tasks(project_id)
      all_tasks(project_id).each do |task|
        result = remove_task(task['id'])
        if result == true
          puts "[I] Removed task #{task['id']}: '#{task['title']}'"
        else
          puts "[E] Failed to remove task #{task['id']}: '#{task['title']}'"
        end
      end
    end

    def remove_all_columns(project_id)
      columns(project_id).each do |column|
        result = remove_column(column['id'])
        if result == true
          puts "[I] Removed column #{column['id']}: '#{column['title']}'"
        else
          puts "[E] Failed to remove column #{column['id']}: '#{column['title']}'"
        end
      end
    end

    # Kill everything about a project (tasks, then columns)
    # but leave users, title, settings, permissions etc. intact.
    # Useful for clearing out a project before attempting an import
    def nuke(project_id)
      remove_all_tasks(project_id)
      remove_all_columns(project_id)
    end

    def remove_all_task_files(task_id)
      request(method: 'removeAllTaskFiles', params: { task_id: task_id })
    end

    # Functions for moving things
    def move_task_to_project(project_id, task_id, column_id, swimlane_id)
      request(method: 'moveTaskToProject', params: { 
        project_id: project_id,
        task_id: task_id,
        column_id: column_id,
        swimlane_id: swimlane_id
      })
    end

    def bulk_move_tasks(project_id, query, to_swimlane_name, to_column_name) 
      tasks_to_move = search(project_id, query)
      raise "No tasks matching query '#{query}' found to move" if tasks_to_move == nil || tasks_to_move.count == 0

      begin
        to_swimlane = swimlane_by_name(project_id, to_swimlane_name)
      rescue
        raise "to_swimlane called '#{to_swimlane_name}' not found"
      end

      to_column = columns(project_id).select { |col| col['title'] == to_column_name }.first
      raise "to_column called '#{to_column_name}' not found" if to_column.nil?

      tasks_to_move.each do |task|
        puts "Moving task #{task['title']} to column #{to_column['title']} (#{to_column['id']})"
        result = move_task_to_project(project_id, task['id'].to_i, 
                             to_column['id'].to_i, to_swimlane['id'].to_i)
        if result == true
          puts 'Move successful'
          if task['is_active'].to_i == 0
            puts 'Closing task because it was closed before'
            close_task(task['id'].to_i)
          end
        else
          puts 'Problem moving'
        end
      end
    end

    def bulk_move_to_same_column_in_all_swimlanes(project_id, query, to_column_name)
      swimlanes(project_id).each do |swimlane|
        puts "Processing swimlane '#{swimlane['name']}' using query #{query} swimlane:\"#{swimlane['name']}\""
        bulk_move_tasks(project_id, "#{query} swimlane:\"#{swimlane['name']}\"", 
                        swimlane['name'], to_column_name) 
      end
    end

    def close_task(task_id)
      request(method: 'closeTask', params: { task_id: task_id })
    end

  end
end
