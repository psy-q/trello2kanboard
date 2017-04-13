require 'csv'

# Note: These half-assed CSV methods don't work and are abandoned
# because it's not possible to import checklists that way, thus
# leading to an incomplete import.

def trello2kanboard_csv_row(row)
  new_row = []

  # TODO: Hrm, can't get checklists via CSV
  # Probably this is all broken. Need to use API anyhow.

  #new_row[0]  = # Reference
  new_row[1]  = row['Card Name'] # Title
  new_row[2]  = row['Card Description'] # Description
  #new_row[3]  = # Assignee Username
  #new_row[4]  = # Creator Username
  #new_row[5]  = # Color Name
  #new_row[6]  = # Column Name
  #new_row[7]  = # Category Name
  new_row[8]  = 'Default swimlane' # Swimlane Name
  new_row[9]  =  0 # Complexity
  #new_row[10] = # Time Estimated
  #new_row[11] = # Time Spent
  #new_row[12] = # Due Date
  #new_row[13] = # Closed

  new_row
end

def convert_csv_to_kanboard(file, destination_file)
  headers = ['Reference','Title', 'Description', 'Assignee Username', 'Creator Username',
             'Color Name','Column Name','Category Name','Swimlane Name','Complexity',
             'Time Estimated','Time Spent','Due Date','Closed']

  CSV.open(destination_file, 'w', headers: headers, write_headers: true) {|csv|
    CSV.foreach(file, headers: true) do |row|
      if row['Archived'] == 'false'
        csv.puts trello2kanboard_csv_row(row)
      end
    end
  }
end
