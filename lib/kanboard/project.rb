module Kanboard

  class Project < Base

    class << self 
      def all
        client.getBoards
      end
    end

  end

end
