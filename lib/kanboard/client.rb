require 'faraday'
require 'json'
require 'open-uri'

module Kanboard
  # Very thin wrapper around the Kanboard JSON-RPC 2.0 API
  # Mostly just gives more ruby-ish appearance to the various RPC calls
  class Client
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

    def initialize(config)
      @config = config
      @user_map = @config['user_map'] if @config['user_map']
    end

    ## Functions for finding IDs on the Kanboard side

    # Get column_id based on Trello title string
    def column_id_from_title(project_id, title)
      if columns(project_id) != []
        columns(project_id).select { |c|
          c if c['title'] == title
        }.first['id']
      end
    end

    def find_user_id_for_trello_user(trello_user)
      user = nil
      if @user_map
        kanboard_user = @user_map[trello_user]
        return nil if kanboard_user.nil?
        result = request(method: 'getUserByName', params: { username: kanboard_user })
        if result != false && !result.nil?
          user = result['id']
        else
          puts "[W] Kanboard user #{kanboard_user} does not exist, even though there is a mapping from Trello user #{trello_user}."
        end
      end
      return user
    end

    def extract_owner(card)
      kanboard_user = find_user_id_for_trello_user(card.members[0].username)
      if kanboard_user == nil 
        puts "[E] Trello user '#{card.members[0].username}' has no equivalent in Kanboard or the user_map entry in trello2kanboard.yml is missing. Cannot assign this task to the correct user."
      else
        return kanboard_user
      end
    end

    ## Functions for listing things on the Kanboard side

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

    def create_tag(project_id, tag)
      options = { project_id: project_id,
                  tag: tag }
      puts "[I] Trying to create tag '#{tag}'"
      request(method: 'createTag', params: options)
    end

    def assign_tags(card, task_id, project_id)
      tags = card.labels.map { |label| label.name unless label.name.blank? }.compact
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

    ## Functions for importing

    def import_checklists(card, task_id)
      card.checklists.each do |checklist|
        checklist.items.each do |item|
          status_map = { 'complete' => 2,
                         'incomplete' => 0 }
          result = request(method: 'createSubtask', params: { task_id: task_id,
                                                              title: item.name,
                                                              status: status_map[item.state] } )
          if result == false
            puts "[E] Couldn't create subtask '#{item.name}' on #{task_id}"
          else
            puts "[I] Subtask #{result} created on task #{task_id}"
          end
        end
      end
    end

    def import_comments(card, task_id)
      card.comments.each do |comment|
        trello_username = Trello::Member.find(comment.member_creator_id).username
        user_id = find_user_id_for_trello_user(trello_username)
        if user_id.nil?
          puts "[E] Couldn't assign comment to trello user '#{trello_username}': #{comment.text}"
        else
          result = request(method: 'createComment', params: { task_id: task_id,
                                                              content: comment.text,
                                                              user_id: user_id })
          if result == false
            puts "[E] Couldn't create comment on #{task_id}"
          else
            puts "[I] Comment #{result} created on task #{task_id}"
          end
        end
      end
    end

    def import_card(card, target_project_id)
      # Create any columns that aren't there yet (or create a new column if there are none)
      if columns(target_project_id) == [] || !columns(target_project_id).map{ |c| c['title'] }.include?(card.list.name)
        puts "[I] Creating column #{card.list.name}"
        result = create_column(target_project_id, card.list.name)
        raise "[E] Couldn't create column #{card.list.name}: #{result}" if result == false || result.nil?
      end
      column_id = column_id_from_title(target_project_id, card.list.name)
      existing_tasks = tasks(target_project_id, column_id)
      if existing_tasks.map { |t| t['title'] }.include?(card.name)
        puts "[I] Card titled '#{card.name}' already exists"
      else
        puts "[I] Trying to create '#{card.name}' in column #{card.list.name}"
        options = {}
        options['column_id'] = column_id
        options['description'] = "#{card.desc}\n\nThis task was imported from [the following card in Trello](#{card.url})."
        options['date_due'] = nil
        options['date_due'] = Date.parse(card.due.to_s).iso8601.to_s if card.due
        options['owner_id'] = extract_owner(card) if card.members.count == 1

        task_id = create_task(target_project_id, card.name, options)

        if task_id == false
          puts "[E] Error creating #{card.name}. If this task belongs to a user, does that user have permission for this Kanboard project?"
        else
          puts "[I] Success: '#{card.name}' saved to Kanboard with ID #{task_id}"
          assign_tags(card, task_id, target_project_id) if card.labels.count > 0

          if card.checklists.count > 0
            puts '[I] -> Now trying to import checklists as substasks'
            import_checklists(card, task_id)
          end

          if card.comments.count > 0
            puts '[I] -> Now trying to import comments'
            import_comments(card, task_id)
          end

          if card.attachments.count > 0
            puts '[I] -> Now trying to import attachments'
            import_attachments(card, task_id, target_project_id)
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

    def import_attachments(card, task_id, target_project_id)
      remove_all_task_files(task_id)
      card.attachments.each do |attachment|
        kanboard_attachment = Base64.encode64(open(attachment.url).read)
        result = request(method: 'createTaskFile',
                         params: {
                           task_id: task_id,
                           project_id: target_project_id,
                           filename: attachment.name,
                           blob: kanboard_attachment
                         })
        if result == false
          puts "[E] -> Could not import #{attachment.name}"
        elsif result.is_a?(Integer)
          puts "[I] -> Imported attachment #{attachment.name}"
        end
      end
    end

    # Turn labels on the Trello side into tags on the Kanboard side
    def import_labels(project_id, labels)
      tags = tags(project_id).map { |tag| tag['name'] }
      tags_to_create = labels - tags
      tags_to_create.each do |tag|
        create_tag(project_id, tag)
      end
    end

    def import_board(source_board_id, target_project_id)
      puts "[I] Trying to import board #{source_board_id}"
      board = Trello::Board.find(source_board_id)
      if board.labels
        labels = board.labels.map { |label| label.name unless label.name.blank? }.compact
        import_labels(target_project_id, labels)
      end
      begin
        board.lists.each do |list|
          puts "[I] Trying to import list #{list.id} '#{list.name}' with #{list.cards.count} cards"
          if project(target_project_id)
            import_list(list.id, target_project_id)
          end
        end
      end
    end
  end
end
