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
        parsed = JSON.parse(response.body)
        raise "Error from Kanboard: #{parsed['error']}" if parsed['error']
        return parsed['result']
      end
    end

    def initialize
      config_file = YAML::load_file('config/trello2kanboard.yml')
      @config = config_file['kanboard']
      @user_map = @config['user_map'] if @config['user_map']
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
      request(method: 'addColumn', params: {project_id: project_id, title: name})
    end

    def create_task(project_id, title, options = {})
      options['project_id'] = project_id
      options['title'] = title
      request(method: 'createTask', params: options)
    end

    def import_board(source_board_id, target_project_id)
      puts "Trying to import board #{source_board_id}"
      begin
        lists = Trello::Board.find(source_board_id).lists
        lists.each do |list|
          puts "Trying to import list #{list.id} '#{list.name}' with #{list.cards.count} cards"
          if project(target_project_id)
            import_list(list.id, target_project_id)
          end
        end
      end
    end

    def column_id_from_title(project_id, title)
      if columns(project_id) != []
        columns(project_id).select{ |c| 
          c if c['title'] == title 
        }.first['id']
      else
        return nil
      end
    end

    def checklists?(card); end

    def find_user_id_for_trello_user(trello_user)
      user = false
      if @user_map
        kanboard_user = @user_map[trello_user]
        return false if kanboard_user == nil
        result = request(method: 'getUserByName', params: { username: kanboard_user })
        if result != false && result != nil && result.dig('id') != nil
          user = result['id']
        end
      end
      return user
    end

    def import_checklists(card, task_id)
      card.checklists.each do |checklist|
        checklist.items.each do |item|
          status_map = { 'complete' => 2,
                         'incomplete' => 0 }
          result = request(method: 'createSubtask', params: { task_id: task_id,
                                                              title: item.name,
                                                              status: status_map[item.state]} )
          if result == false
            puts "Couldn't create subtask '#{item.name}' on #{task_id}"
          else
            puts "Subtask #{result} created on task #{task_id}"
          end
        end
      end
    end

    def import_comments(card, task_id)
      card.comments.each do |comment|
        trello_username = Trello::Member.find(comment.member_creator_id).username
        user_id = find_user_id_for_trello_user(trello_username)
        if user_id == false
          puts "Trello user '#{trello_username}' has no equivalent in Kanboard or the user_map entry in trello2kanboard.yml is missing. Cannot import comment: '#{comment}'"
        else
          result = request(method: 'createComment', params: { task_id: task_id,
                                                              content: comment.text,
                                                              user_id: user_id })
          if result == false
            puts "Couldn't create comment on #{task_id}"
          else
            puts "Comment #{result} created on task #{task_id}"
          end
        end
      end
    end

    def import_card(card, target_project_id)
      # Create any columns that aren't there yet (or create a new column if there are none)
      if columns(target_project_id) == [] || !columns(target_project_id).map{|c| c['title']}.include?(card.list.name)
        puts "Creating column #{card.list.name}"
        result = create_column(target_project_id, card.list.name)
        raise "Couldn't create column #{card.list.name}: #{result}" if result == false or result == nil
      end
      column_id = column_id_from_title(target_project_id, card.list.name)
      existing_tasks = tasks(target_project_id, column_id)
      if existing_tasks.map{|t| t['title']}.include?(card.name)
        puts "Card titled '#{card.name}' already exists"
      else
        puts "Trying to create '#{card.name}' in column #{card.list.name}"
        options = {}
        options['column_id'] = column_id
        options['description'] = "#{card.desc}\n\nDiese Kanboard-Aufgabe wurde aus [dieser Trello-Karte](#{card.url}) importiert."
        options['date_due'] = nil
        options['date_due'] = Date.parse(card.due.to_s).iso8601.to_s if card.due
        # This can't work right now, since Trello doesn't care who created a card
        #options['creator_id'] = find_user_id_for_trello_user(card.creator)
        if card.members.count == 1
          kanboard_user = find_user_id_for_trello_user(card.members[0].username)
          if kanboard_user == false 
            puts "ERROR: Trello user '#{card.members[0].username}' has no equivalent in Kanboard or the user_map entry in trello2kanboard.yml is missing. Cannot assign this task to the correct user."
          else
            options['owner_id'] = kanboard_user
          end
        end
        task_id = create_task(target_project_id, card.name, options)
        if task_id == false
          puts "Error creating #{card.name}"
        else
          puts "Success: '#{card.name}' saved to Kanboard with ID #{task_id}"
          if card.checklists.count > 0
            puts "___ Now trying to import checklists as substasks"
            import_checklists(card, task_id)
          end
          if card.comments.count > 0
            puts "___ Now trying to import comments"
            import_comments(card, task_id)
          end
        end
      end
    end

    def import_list(list_id, target_project_id)
      list = Trello::List.find(list_id)
      list.cards.each do |card|
        import_card(card, target_project_id)
      end
    end

  end
end
