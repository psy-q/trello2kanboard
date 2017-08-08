require 'kanboard'
require 'table_print'

class Pivotal2Kanboard
  def initialize(config)
    @config = config
    @client = Kanboard::Client.new(config['kanboard'])
  end
end
