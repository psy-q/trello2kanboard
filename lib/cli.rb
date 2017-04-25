
def list_trello_boards
  puts "\n\nTrello:\n"
  tp Trello::Board.all, "id", "name", url: { width: 255 }
end

def list_kanboard_projects
  puts "\n\nKanboard:\n"
  projects = @rpc.projects.map {|project|
    { 
      id: project['id'],
      name: project['name'],
      url: project['url']['board']
    }
  }
  tp projects, 'id', 'name', url: { width: 255 }
end

def has_checklists?(task_id)

end

def import_board(source_board_id, target_project_id)
  lists = Trello::Board.find(source_board_id)
  lists.each do |list|
    # und hier list.cards.each usw.
  end
  byebug
  puts 'foo'
end
