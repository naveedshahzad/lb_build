require 'jira-ruby'
require 'octokit'

def exec_cmd(cmd)
IO.popen(cmd) do |io|
  io.each_line do |line|
    puts line
  end
end
end

puts " Rading sourch branch from #{"code_dir/source_branch"} "
feature_branch = File.read("code_dir/source_branch.txt")&.strip
base_branch    = ENV["ANIMAL"]&.strip
if feature_branch.nil? || feature_branch.length == 0
  puts "Feature branch is not specified"
  raise "Feature branch is not specified"
end
if base_branch.nil? || base_branch.length == 0
  puts "Base branch is not specified"
  raise "Base branch is not specified"
end

bb_host_url  = "https://api.bitbucket.org"
bb_prs_url   = "/2.0/repositories/naveedshehzad/livebinders/pullrequests"
bb_username  = ENV["BB_USERNAME"]
bb_app_token = ENV["BB_PASSWORD"]

conn = Faraday.new(url: bb_host_url, headers: {'Content-Type' => 'application/json'})
conn.basic_auth(bb_username, bb_app_token)
bb_prs_resp = conn.get(bb_prs_url)

bb_prs = JSON.parse(bb_prs_resp.body)["values"]
bb_pr = bb_prs.select{|bb_pr| bb_pr["source"]["branch"]["name"] == feature_branch && bb_pr["destination"]["branch"]["name"]==base_branch}.first
if bb_pr.nil?
  puts "Deployment PR not found"
  bb_create_pr_url   = "/2.0/repositories/naveedshehzad/livebinders/pullrequests"
  data = {
    title: "[#{base_branch.upcase}] [Deployment] PR",
    description: "[#{base_branch.upcase}] [Deployment] PR",
    source: {
      branch: {
        name: feature_branch
      }
    },
    destination: {
      branch: {
        name: base_branch
      }
    }
  }
  puts "Creating new PR"
  bb_create_pr_resp = conn.post(bb_create_pr_url, data.to_json)
  bb_pr = JSON.parse(bb_create_pr_resp.body)
end

#reset base branch to latest rails5
puts "Resetting #{base_branch} to latest rails5"
exec_cmd("echo $PWD")
exec_cmd("ls")
puts "Previous dir"
exec_cmd("cd .. && ls")
puts " Further Previous dir"
exec_cmd("cd ../../ && ls")
exec_cmd("echo WorkingDirectory")
prj_dir = ".."
exec_cmd("cd #{prj_dir} && git fetch bb rails5")
exec_cmd("cd #{prj_dir} && git checkout rails5")
exec_cmd("cd #{prj_dir} && git branch -D #{base_branch}")
exec_cmd("cd #{prj_dir} && git branch -rd origin/#{base_branch}")
exec_cmd("cd #{prj_dir} && git branch -rd bb/#{base_branch}")
exec_cmd("cd #{prj_dir} && git checkout -b #{base_branch}")
exec_cmd("cd #{prj_dir} && git push -f bb #{base_branch}")
raise "incompolete"


puts "Merging the deployment PR"
bb_merge_url = "/2.0/repositories/naveedshehzad/livebinders/pullrequests/#{bb_pr["id"]}/merge"
data = {
  "close_source_branch":false,
  "merge_strategy":"squash",
  "message":bb_pr["title"],
  "type":""
}
bb_merge_pr_resp = conn.post(bb_merge_url, data.to_json)

#deploying to the base branch
puts "deploying to the #{base_branch}"
exec_cmd("cd #{prj_dir} && git checkout #{base_branch}")
exec_cmd("cd #{prj_dir} && git pull bb #{base_branch}")

exec_cmd("cd #{prj_dir} && git push -f origin #{base_branch}")

puts "Completed"

