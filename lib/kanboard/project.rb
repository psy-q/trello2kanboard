module Kanboard

  class Project < Base

    class << self 
      def all
        client.projects
      end
    end

  end

end
