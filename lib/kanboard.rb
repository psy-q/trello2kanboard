require 'kanboard/client'

module Kanboard

  def self.client
    @client ||= Client.new
  end

end
