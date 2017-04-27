
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


