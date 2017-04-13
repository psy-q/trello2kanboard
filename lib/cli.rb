
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

def import_board(source_board_id, target_project_id)
end
