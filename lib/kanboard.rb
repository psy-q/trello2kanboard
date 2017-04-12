require 'kanboard/base'
require 'kanboard/project'
require 'kanboard/client'

module Kanboard

  def self.client
    @client ||= Client.new
  end

end
