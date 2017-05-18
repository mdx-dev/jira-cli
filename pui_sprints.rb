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

#returns cycle time in minutes
def get_cycle_times(issues)
    cycle_times = Hash.new
    issue_status_changes = Hash.new

    #get issue change log sets
    issues.select { |issue| issue[:issue_data]["fields"]["status"]["name"] == "Resolved" }.each do |issue|
      key = issue[:issue_data]["key"]
      issue_status_changes[key] = []

      issue[:issue_data]["changelog"]["histories"].each do |history|

        history["items"].select { |item| item["field"] == "status" }.each do |status_history|
           history_created = DateTime.parse(history["created"])
           issue_status_changes[key] << history_created 
        end
      end

      start_date = issue_status_changes[key].min
      end_date = issue_status_changes[key].max

      cycle_times[key] = ((end_date - start_date) * 24 * 60).floor
    end
    
    cycle_times
end

def to_cycle_times_csv(issues)
    cycle_times = get_cycle_times(issues)
    string_builder = StringIO.new

    string_builder << "issue key, cycle time\n"

    cycle_times.keys.each do |key|
        string_builder << "#{key},"    
        string_builder << "#{cycle_times[key]}\n"    
    end

    out_file = File.new("pui_sprint_cycle_times.csv", "w+")
    out_file.write(string_builder.string)
end

def get_changelog_csv_string(issues)
  string_builder = StringIO.new

  string_builder << "issue_id,issue_key, history_id, history_author_name, history_author_display_name, history_author_avatarURL48x48, history_created, previous_history_created, history_item_field,"
  string_builder << "history_item_fieldtype, history_item_from, history_item_fromString, history_item_to, history_item_toString\n"
  
  issues.each do |issue|
    id = issue[:issue_data]["id"]
    key = issue[:issue_data]["key"]
    histories = issue[:issue_data]["changelog"]["histories"]
    previous_history_created = nil
    histories.each do |history| 
      history_id = history["id"]
      history_author_name = history["author"]["name"]
      history_author_display_name = history["author"]["displayName"]
      history_author_avatarURL48x48 = history["author"]["avatarUrls"]["48x48"]
      history_created = DateTime.parse(history["created"]).strftime("%FT%R")

      #filtered to only record status change history items...for now
      history["items"].select { |item| item["field"] == "status" }.each do |item|
        history_item_field = item["field"]
        history_item_fieldtype = item["fieldtype"]
        history_item_from = item["from"]
        history_item_fromString = item["fromString"]
        history_item_to = item["to"]
        history_item_toString = item["toString"]

        string_builder << "\"#{id}\","
        string_builder << "\"#{key}\","
        string_builder << "\"#{history_id}\","
        string_builder << "\"#{history_author_name}\","
        string_builder << "\"#{history_author_display_name}\","
        string_builder << "\"#{history_author_avatarURL48x48}\","
        string_builder << "\"#{history_created}\","

        if(previous_history_created.nil?) then
          string_builder << ","
        elsif
          string_builder << "\"#{previous_history_created}\","
        end

        string_builder << "\"#{history_item_field}\","
        string_builder << "\"#{history_item_fieldtype}\","
        string_builder << "\"#{history_item_from}\","
        string_builder << "\"#{history_item_fromString}\","
        string_builder << "\"#{history_item_to}\","
        string_builder << "\"#{history_item_toString}\""

        string_builder << "\n"
      end

      previous_history_created = history_created
    end
  end
  string_builder.string
end

def to_changelog_csv(issues)
  out_file = File.new("pui_sprint_results_changelog.csv","w+")

  out_file.write(get_changelog_csv_string(issues))
end

def get_issue_data(issue_key,sprint_name)
  uri = "https://vitals.atlassian.net/rest/api/latest/search?jql=key=#{issue_key}&expand=changelog"
  puts uri
  query_result = HTTParty.get(uri, @options)
  issues = query_result["issues"]
  issue_count = issues.count
  issue_data = nil

  if(issue_count == 1) then
    issue_data = issues[0]
  else
    puts "Error: unexpected results for #{issue_key}. Expected 1 result and got #{issue_count}"
  end

  issue_sprint_data = {:sprint_name => sprint_name, :issue_data => issue_data }
end

def get_latest_sprints()
  puts "https://vitals.atlassian.net/rest/greenhopper/latest/sprintquery/173"
  puts "https://vitals.atlassian.net/rest/greenhopper/latest/sprintquery/174"

  blue_sprints = HTTParty.get("https://vitals.atlassian.net/rest/greenhopper/latest/sprintquery/173", @options)
  red_sprints = HTTParty.get("https://vitals.atlassian.net/rest/greenhopper/latest/sprintquery/174", @options)

  puts blue_sprints

  blue_board_id = 173
  red_board_id = 174
  black_board_id = 222

  earliest_sprint_id = 850

  latest_sprints = Hash.new
  latest_sprints[blue_board_id] = [] 
  latest_sprints[red_board_id] = [] 

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

def get_cl_arguments()
  args = Hash[ ARGV.flat_map{|s| s.scan(/--?([^=\s]+)(?:=(\S+))?/) } ]

  if(args.key?('c')) then
    @changelog = true
    puts "changelog on"
  end
end

def init()
  config = YAML.load(File.read('config/credentials.yml'))
  @auth = {username: config['username'], password: config['password']}
  @options = {basic_auth: @auth}
  @changelog = false
end

def get_sprint_issues_data(latest_sprint_data)
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

  sprint_issue_data
end

init()
get_cl_arguments()
sprint_issue_data = get_sprint_issues_data(get_latest_sprints())

puts "$$$$$$$$$$$$$$$$$$"

to_csv(sprint_issue_data)

puts "expanding the changelog for returned issues"
to_changelog_csv(sprint_issue_data)

puts "outputing cycle times"
to_cycle_times_csv(sprint_issue_data)
