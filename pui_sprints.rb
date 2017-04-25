require 'HTTParty'

def get_csv_string(issues)
  string_builder = StringIO.new

  string_builder << "id,key,creator,created,issue type,fix versions,reporter,"
  string_builder << "resolution,resolution_date,status,status category,labels,story points,sprint name\n"
  
  issues.each do |issue|
    id = issue[:issue_data]["id"]
    key = issue[:issue_data]["key"]
    sprint_name = issue[:sprint_name]
    creator = issue[:issue_data]["fields"]["creator"]["name"]
    created = DateTime.parse(issue[:issue_data]["fields"]["created"]).strftime("%m/%d/%Y")
    issue_type = issue[:issue_data]["fields"]["issuetype"]["name"]
    reporter = issue[:issue_data]["fields"]["reporter"]["name"]
    
    resolution = issue[:issue_data]["fields"]["resolution"]
    if(resolution != nil) then
      resolution_name = resolution["name"]
    end

    resolution_date = issue[:issue_data]["fields"]["resolutiondate"]
    if(resolution_date != nil) then
      resolution_date = DateTime.parse(resolution_date).strftime("%m/%d/%Y")
    end

    fix_versions = ""
    issue[:issue_data]["fields"]["fixVersions"].each do |fix_version|
       fix_versions = fix_versions + "#{fix_version['name']} | " 
    end

    status = issue[:issue_data]["fields"]["status"]
    status_name = status["name"]
    status_category_name = status["statusCategory"]["name"]

    labels = issue[:issue_data]["fields"]["labels"]
    label_values = ""
    labels.each do |label|
      label_values = label_values + label + "|"
    end

    story_points = issue[:issue_data]["fields"]["customfield_10004"]

    string_builder << "#{id},"
    string_builder << "#{key}," 
    string_builder << "#{creator}," 
    string_builder << "#{created}," 
    string_builder << "#{issue_type}," 
    string_builder << "#{fix_versions}," 
    string_builder << "#{reporter}," 
    string_builder << "#{resolution_name}," 
    string_builder << "#{resolution_date}," 
    string_builder << "#{status_name}," 
    string_builder << "#{status_category_name}," 
    string_builder << "#{label_values}," 
    string_builder << "#{story_points},"
    string_builder << "#{sprint_name}"

    string_builder << "\n"
  end
  string_builder.string
end

def to_csv(issues)
  out_file = File.new("pui_sprint_results.csv","w+")

  out_file.write(get_csv_string(issues))
end

def get_issue_data(issue_key,sprint_name)
  uri = "https://vitals.atlassian.net/rest/api/latest/issue/#{issue_key}"
  puts uri
  issue_sprint_data = {:sprint_name => sprint_name, :issue_data => HTTParty.get(uri, @options)}
end

def get_latest_sprints()
  puts "https://vitals.atlassian.net/rest/greenhopper/latest/sprintquery/173"
  puts "https://vitals.atlassian.net/rest/greenhopper/latest/sprintquery/174"

  blue_sprints = HTTParty.get("https://vitals.atlassian.net/rest/greenhopper/latest/sprintquery/173", @options)
  red_sprints = HTTParty.get("https://vitals.atlassian.net/rest/greenhopper/latest/sprintquery/174", @options)

  blue_board_id = 173
  red_board_id = 174
  black_board_id = 222

  earliest_sprint_id = 850

  latest_sprints = Hash.new
  latest_sprints[blue_board_id] = [] 
  latest_sprints[red_board_id] = [] 
  latest_sprints[black_board_id] = [] 

  blue_sprints["sprints"].each do |sprint|
    sprint_sequence = Float(sprint["sequence"])
    if(sprint_sequence >= earliest_sprint_id) then
      latest_sprints[blue_board_id] << sprint
    end
  end

  red_sprints["sprints"].each do |sprint|
    sprint_sequence = Float(sprint["sequence"])
    if(sprint_sequence >= earliest_sprint_id) then
      latest_sprints[red_board_id] << sprint
    end
  end

  latest_sprints
end

def get_sprint_issues(rapid_view_id,sprint_id)
  uri = "https://vitals.atlassian.net/rest/greenhopper/latest/rapid/charts/sprintreport?rapidViewId=#{rapid_view_id}&sprintId=#{sprint_id}"
  puts uri
  HTTParty.get(uri, @options)
end

config = YAML.load(File.read('config/credentials.yml'))
@auth = {username: config['username'], password: config['password']}
@options = {basic_auth: @auth}

latest_sprint_data = get_latest_sprints()

sprint_issue_data = []
latest_sprint_data.each do |key, value|
   value.each do |sprint|
     sprint_id = sprint["id"]
     sprint_data = get_sprint_issues(key,sprint_id)

     puts "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
     puts "found issues:"
     puts sprint_data["contents"]["completedIssues"]
     puts "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"

     sprint_issues = []
     sprint_data["contents"]["completedIssues"].collect { |issue| sprint_issues << issue }
     #sprint_data["contents"]["puntedIssues"].collect { |issue| sprint_issues << issue }
     #sprint_data["contents"]["issuesNotCompletedInCurrentSprint"].collect { |issue| sprint_issues << issue }

     sprint_name = sprint_data["sprint"]["name"]

     puts sprint_name

     sprint_issues.each do |sprint_issue|
          sprint_issue_data << get_issue_data(sprint_issue["key"], sprint_name)
     end
   end
end

puts "$$$$$$$$$$$$$$$$$$"

to_csv(sprint_issue_data)
