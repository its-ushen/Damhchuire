#!/usr/bin/env ruby
# Test: github_get_issue_timeline
#
# Usage:
#   GITHUB_TOKEN=ghp_xxx OWNER=rails REPO=rails ISSUE=1 ruby script/test_github_get_issue_timeline.rb
#
# Prints all timeline events and extracts the commit_id if the issue
# was closed by a commit/PR. That commit_id feeds the next script.
#
# Env vars:
#   GITHUB_TOKEN  required  personal access token
#   OWNER         required  repo owner
#   REPO          required  repo name
#   ISSUE         required  issue number

require_relative "github_action_runner"

ACTION = {
  slug: "github_get_issue_timeline",
  name: "GitHub: Get Issue Timeline",
  http_method: "GET",
  url_template: "https://api.github.com/repos/{{owner}}/{{repo}}/issues/{{issue_number}}/timeline",
  headers_template: {
    "Authorization" => "Bearer {{credentials.github_pat}}",
    "Accept"        => "application/vnd.github+json",
    "X-GitHub-Api-Version" => "2022-11-28"
  },
  body_template: {}
}.freeze

PARAMS = {
  "owner"        => ENV.fetch("OWNER") { abort "set OWNER" },
  "repo"         => ENV.fetch("REPO")  { abort "set REPO" },
  "issue_number" => ENV.fetch("ISSUE") { abort "set ISSUE" }
}.freeze

puts "=" * 60
puts "  ACTION: #{ACTION[:name]}"
puts "  issue:  #{PARAMS["owner"]}/#{PARAMS["repo"]}##{PARAMS["issue_number"]}"
puts "=" * 60

result = ActionRunner.run(ACTION, PARAMS)
puts "  status: #{result[:status]}"
puts

body = result[:body]
unless body.is_a?(Array)
  puts body
  exit 1
end

puts "  #{body.length} timeline event(s) total"
puts

# Print a summary line per event
body.each_with_index do |event, i|
  actor = event.dig("actor", "login") || "-"
  label = event["event"]
  commit = event["commit_id"]
  line   = "  [#{i.to_s.rjust(2)}] #{label.ljust(20)} actor=#{actor}"
  line  += "  commit_id=#{commit}" if commit
  puts line
end

puts

# Find the closed event with a commit_id
closed_event = body.find { |e| e["event"] == "closed" && e["commit_id"] }

if closed_event
  commit_id = closed_event["commit_id"]
  actor     = closed_event.dig("actor", "login")
  puts "  => Found CLOSED event"
  puts "     actor:     #{actor}"
  puts "     commit_id: #{commit_id}"
  puts
  puts "  Next step — verify the PR was merged:"
  puts "  GITHUB_TOKEN=... OWNER=#{PARAMS["owner"]} REPO=#{PARAMS["repo"]} COMMIT_SHA=#{commit_id} ruby script/test_github_get_commit_pulls.rb"
else
  closed_event_no_commit = body.find { |e| e["event"] == "closed" }
  if closed_event_no_commit
    puts "  => Issue was CLOSED but with no commit_id — closed manually, no bounty payout."
  else
    puts "  => No closed event found — issue is still open."
  end
end
