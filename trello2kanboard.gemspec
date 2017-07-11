Gem::Specification.new do |s|
  s.name         = 'trello2kanboard'
  s.version      = '0.2.1'
  s.licenses     = ['MIT']
  s.summary      = "Converts CSV files exported from Trello into a format that can be imported to Kanboard"
  s.description  = "Export a CSV file from Trello, save it locally, create a config file that maps users and columns and run this script. The output should be a CSV file that can be imported into Kanboard."
  s.authors      = ["Ramón Cahenzli"]
  s.email        = 'rca@psy-q.ch'
  s.files        = Dir["{lib}/**/*.rb", "bin/*", "LICENSE", "*.md"]
  s.executables  = ['trello2kanboard'] 
  s.require_path = 'lib'
  s.homepage     = 'https://github.com/psy-q/trello2kanboard'

  s.add_dependency('ruby-trello', ["~> 2.0"])
  s.add_dependency('table_print', ["~> 1.5"])
  #s.add_dependency('jsonrpc-client', ["~> 0.1"])
  s.add_dependency('faraday', ["~> 0.12"])
  #s.add_dependency('saorin', ["~> 0.6"])
  #  s.add_dependency('jimson', ["~> 0.11"]) # pulls in rest-client < 2.0 which doesn't work on Ruby 2.4

end
