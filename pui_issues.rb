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
  string_builder << "resolution,resolution_date,status,status category,labels,story points\n"

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

  path_builder << "jql=project='VitalsChoice Platform'"
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
  closed = HTTParty.get(path, options)

  puts closed.header.inspect

  puts "collecting issues"
  closed["issues"].collect { |issue| results << issue }
  puts "issues in page: #{closed["issues"].size}"
  puts "results: #{results.size}"
  if(closed["issues"].size == @max_results) then
    puts "starting at: #{start_at + @max_results}"
    return get_response(start_at + @max_results,results)
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
