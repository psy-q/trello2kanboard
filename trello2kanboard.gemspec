Gem::Specification.new do |s|
  s.name         = 'trello2kanboard'
  s.version      = '0.4.2'
  s.licenses     = ['MIT']
  s.summary      = "Imports kanban boards from Trello to Kanboard via API"
  s.description  = "Connects to both services and allows you to import boards, columns and tasks from Trello to Kanboard."
  s.authors      = ["Ramón Cahenzli"]
  s.email        = 'rca@psy-q.ch'
  s.files        = Dir["{lib}/**/*.rb", "bin/*", "LICENSE", "*.md"]
  s.executables  = ['trello2kanboard'] 
  s.require_path = 'lib'
  s.homepage     = 'https://gitlab.com/psy-q/trello2kanboard'

  s.add_dependency('ruby-trello', ["~> 2.0"])
  s.add_dependency('table_print', ["~> 1.5"])
  s.add_dependency('faraday', ["~> 0.12"])

end
