require 'httparty'
require 'pry'


class Stopwatch
 
  def initialize()
    @start = Time.now
  end
   
  def elapsed_time
    now = Time.now
    elapsed = now - @start
    puts 'Started: ' + @start.to_s
    puts 'Now: ' + now.to_s
    puts 'Elapsed time: ' +  elapsed.to_s + ' seconds'
    elapsed.to_s
  end
   
end

def get_csv_string(issues)
  string_builder = StringIO.new

  string_builder << "id,key,creator,created,issue type,fix versions,reporter,"
  string_builder << "resolution,resolution_date,status,status category,labels,"
  string_builder << "story points, client name, project, cause, client request number\n"

  issues.each do |issue|
    id = issue["id"]
    key = issue["key"]
    creator = issue["fields"]["creator"]["name"]
    created = DateTime.parse(issue["fields"]["created"]).strftime("%m/%d/%Y")
    issue_type = issue["fields"]["issuetype"]["name"]
    reporter = issue["fields"]["reporter"]["name"]
    
    resolution = issue["fields"]["resolution"]
    if(resolution != nil) then
      resolution_name = resolution["name"]
    end

    resolution_date = issue["fields"]["resolutiondate"]
    if(resolution_date != nil) then
      resolution_date = DateTime.parse(resolution_date).strftime("%m/%d/%Y")
    end

    fix_versions = ""
    issue["fields"]["fixVersions"].each do |fix_version|
       fix_versions = fix_versions + "#{fix_version['name']} | " 
    end

    status = issue["fields"]["status"]
    status_name = status["name"]
    status_category_name = status["statusCategory"]["name"]

    labels = issue["fields"]["labels"]
    label_values = ""
    labels.each do |label|
      label_values = label_values + label + "|"
    end

    story_points = issue["fields"]["customfield_10004"]

    client_name = issue["fields"]["customfield_11600"]
    if(client_name != nil) then
      client_name = client_name["value"]
    end

    project_name = issue["fields"]["project"]
    if(project_name != nil) then
      project_name = project_name["name"]
    end

    creation_causes = issue["fields"]["customfield_12200"]
    cause_values = ""
    if(creation_causes != nil) then
      creation_causes.each do |cause|
        cause_values = cause_values + cause["value"] + "|"
      end
    end

    client_request_number = issue["fields"]["customfield_11100"]
    if(client_request_number != nil) then
      client_request_number = client_request_number.gsub(",","|")
    end

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
    string_builder << "#{client_name},"
    string_builder << "#{project_name},"
    string_builder << "#{cause_values},"
    string_builder << "#{client_request_number},"

    string_builder << "\n"
  end
  string_builder.string
end

def to_csv(issues)
  out_file = File.new("jira.csv","w+")

  out_file.write(get_csv_string(issues))
end

def get_path(start_at)
  path_builder = StringIO.new

  path_builder << "search?"

  jql_query = File.read("imp_query")

  path_builder << "jql=#{jql_query}"
  path_builder << " order by Created ASC"

  path_builder << "&"
  path_builder << "maxResults=#{@max_results}"

  path_builder << "&"
  path_builder << "startAt=#{start_at}"

  @base_uri + path_builder.string
end

def get_response(start_at,results)
  puts "getting path"
  path = get_path(start_at)
  puts "got path: #{path}"
  options = {basic_auth: @auth}
  puts "hitting api..."
  puts "#{path}"
  puts "#{options}"

  closed = HTTParty.get(path, options)

  puts closed.header.inspect

  puts "collecting issues"
  closed["issues"].collect { |issue| results << issue }
  puts "issues in page: #{closed["issues"].size}"
  puts "results: #{results.size}"
  if(closed["total"] > results.size) then
    puts "starting again at: #{results.size}"
    return get_response(results.size,results)
  else
    puts "DONE"
    return results
  end

end

config = YAML.load(File.read('config/credentials.yml'))
@auth = {username: config['username'], password: config['password']}
@base_uri = 'https://vitals.atlassian.net/rest/api/2/'
@max_results = 1000
issues = []

if(File.exist?("results")) then
  issues = Marshal.load(File.read('results'))
else
  stopwatch = Stopwatch.new
  get_response(0,issues)
  puts "$$$$$$$$$$$$$$$$$$"
  stopwatch.elapsed_time

  File.new("results","w+")
  File.open("results","w") {|f| f.write(Marshal.dump(issues))}
end

to_csv(issues)
