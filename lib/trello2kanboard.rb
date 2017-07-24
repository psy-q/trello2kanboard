require 'kanboard'
require 'trello'
require 'table_print'

class Trello2Kanboard
  def initialize(config)
    @config = config
    @user_map = @config['kanboard']['user_map'] if @config['kanboard']['user_map']
    @client = Kanboard::Client.new(config['kanboard'])
    Trello.configure do |c|
      c.developer_public_key = @config['trello']['developer_public_key']
      c.member_token = @config['trello']['member_token']
    end
  end

  def list_trello_boards
    puts "\n\nTrello:\n"
    tp Trello::Board.all, 'id', 'name', url: { width: 255 }
  end

  def list_kanboard_projects
    puts "\n\nKanboard:\n"
    projects = @client.projects.map do |project|
      {
        id: project['id'],
        name: project['name'],
        url: project['url']['board']
      }
    end
    tp projects, 'id', 'name', url: { width: 255 }
  end


  # Get column_id based on Trello title string
  def column_id_from_title(project_id, title)
    if @client.columns(project_id) != []
      @client.columns(project_id).select { |c|
        c if c['title'] == title
      }.first['id']
    end
  end

  def find_user_id_for_trello_user(trello_user)
    user = nil
    if @user_map
      kanboard_user = @user_map[trello_user]
      return nil if kanboard_user.nil?
      result = @client.request(method: 'getUserByName', params: { username: kanboard_user })
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

  def import_checklists(card, task_id)
    card.checklists.each do |checklist|
      checklist.items.each do |item|
        status_map = { 'complete' => 2,
                       'incomplete' => 0 }
        result = @client.request(method: 'createSubtask', params: { task_id: task_id,
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
        puts "[W] Couldn't assign comment to Trello user '#{trello_username}': #{comment.text}"

        # Can we assign the comment to a fallback user?
        if @config['kanboard']['comment_fallback_user_id'] > 0
          puts "[I] Using fallback user with ID #{@config['kanboard']['comment_fallback_user_id']} instead"
          text_with_signature = "#{comment.text}\n- #{trello_username}"
          result = @client.create_comment(task_id, @config['kanboard']['comment_fallback_user_id'], text_with_signature)
        end
      else
        result = @client.create_comment(task_id, user_id, comment.text)
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
    if @client.columns(target_project_id) == [] || !@client.columns(target_project_id).map{ |c| c['title'] }.include?(card.list.name)
      puts "[I] Creating column #{card.list.name}"
      result = @client.create_column(target_project_id, card.list.name)
      raise "[E] Couldn't create column #{card.list.name}: #{result}" if result == false || result.nil?
    end
    column_id = column_id_from_title(target_project_id, card.list.name)
    existing_tasks = @client.tasks(target_project_id, column_id)
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

      task_id = @client.create_task(target_project_id, card.name, options)

      if task_id == false
        puts "[E] Error creating #{card.name}. If this task belongs to a user, does that user have permission for this Kanboard project?"
      else
        puts "[I] Success: '#{card.name}' saved to Kanboard with ID #{task_id}"
        if card.labels.count > 0
          tags = card.labels.map { |label| label.name unless label.name.blank? }.compact
          @client.assign_tags(tags, task_id, target_project_id) 
        end

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
    @client.remove_all_task_files(task_id)
    card.attachments.each do |attachment|
      begin
        kanboard_attachment = Base64.encode64(open(attachment.url).read)
        result = @client.create_task_file(task_id, target_project_id, attachment.name, kanboard_attachment)

        if result == false
          puts "[E] -> Could not import #{attachment.name}"
        elsif result.is_a?(Integer)
          puts "[I] -> Imported attachment #{attachment.name}"
        end
      rescue OpenURI::HTTPError => e
        puts "[E] -> Attachment import failed for #{attachment.url}: #{e.inspect}"
      rescue Net::ReadTimeout
        puts "[E] -> Timed out while trying to fetch #{attachment.url}"
      end
    end
  end

  # Turn labels on the Trello side into tags on the Kanboard side
  def import_labels(project_id, labels)
    tags = @client.tags(project_id).map { |tag| tag['name'] }
    tags_to_create = labels - tags
    tags_to_create.each do |tag|
      @client.create_tag(project_id, tag)
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
        if @client.project(target_project_id)
          import_list(list.id, target_project_id)
        end
      end
    end
  end
end
