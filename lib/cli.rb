
def list_trello_boards
  puts "\n\nTrello:\n"
  tp Trello::Board.all, 'id', 'name', url: { width: 255 }
end

def list_kanboard_projects
  puts "\n\nKanboard:\n"
  projects = @kanboard.projects.map do |project|
    {
      id: project['id'],
      name: project['name'],
      url: project['url']['board']
    }
  end
  tp projects, 'id', 'name', url: { width: 255 }
end

def column_id_from_title(project_id, title)
  @kanboard.columns(project_id).select{ |c| 
    c if c['title'] == title 
  }.first['id']
end

def checklists?(card); end

def import_card(card, target_project_id)
  unless @kanboard.columns(target_project_id).map{|c| c['title']}.include?(card.list.name)
    @kanboard.create_column(target_project_id, card.list.name)
  end
  column_id = column_id_from_title(target_project_id, card.list.name)
  existing_tasks = @kanboard.tasks(target_project_id, column_id)
  if existing_tasks.map{|t| t['title']}.include?(card.name)
    puts "Card titled #{card.name} already exists"
  else
    puts "Trying to create #{card.name} in column #{card.list.name}"
    options = {}
    options['column_id'] = column_id
    options['description'] = "#{card.desc}\n\nDiese Kanboard-Aufgabe wurde aus [dieser Trello-Karte](#{card.url}) importiert."
    options['date_due'] = nil
    options['date_due'] = Date.parse(card.due.to_s).iso8601.to_s if card.due
    result = @kanboard.create_task(target_project_id, card.name, options)
    if result == false
      puts "Creating #{card.name} failed"
    end
  end
end

def import_list(list_id, target_project_id)
  list = Trello::List.find(list_id)
  list.cards.each do |card|
    import_card(card, target_project_id)
  end
end

def import_board(source_board_id, target_project_id)
  puts "Trying to import board #{source_board_id}"
  begin
    lists = Trello::Board.find(source_board_id).lists
    lists.each do |list|
      puts "Trying to import list #{list.id} '#{list.name}' with #{list.cards.count} cards"
      if @kanboard.project(target_project_id)
        import_list(list.id, target_project_id)
      end
    end
  end
end
