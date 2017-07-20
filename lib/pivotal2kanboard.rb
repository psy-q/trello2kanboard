require 'kanboard'
#require 'trello'
require 'table_print'

class Pivotal2Kanboard
  def initialize(config)
    @config = config
    @client = Kanboard::Client.new(config['kanboard'])
    Trello.configure do |c|
      c.developer_public_key = @config['trello']['developer_public_key']
      c.member_token = @config['trello']['member_token']
    end
  end
end
