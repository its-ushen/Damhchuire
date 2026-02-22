#!/usr/bin/env ruby
# Test: github_get_issue
#
# Usage:
#   GITHUB_TOKEN=ghp_xxx OWNER=rails REPO=rails ISSUE=1 ruby script/test_github_get_issue.rb
#
# Env vars:
#   GITHUB_TOKEN  required  personal access token (read:public_repo scope)
#   OWNER         required  repo owner e.g. its-ushen
#   REPO          required  repo name  e.g. Damhchuire
#   ISSUE         required  issue number e.g. 42

require_relative "github_action_runner"

ACTION = {
  slug: "github_get_issue",
  name: "GitHub: Get Issue",
  http_method: "GET",
  url_template: "https://api.github.com/repos/{{owner}}/{{repo}}/issues/{{issue_number}}",
  headers_template: {
    "Authorization" => "Bearer {{credentials.github_pat}}",
    "Accept"        => "application/vnd.github+json",
    "X-GitHub-Api-Version" => "2022-11-28"
  },
  body_template: {}
}.freeze

PARAMS = {
  "owner"        => ENV.fetch("OWNER")  { abort "set OWNER" },
  "repo"         => ENV.fetch("REPO")   { abort "set REPO" },
  "issue_number" => ENV.fetch("ISSUE")  { abort "set ISSUE" }
}.freeze

puts "=" * 60
puts "  ACTION: #{ACTION[:name]}"
puts "  issue:  #{PARAMS["owner"]}/#{PARAMS["repo"]}##{PARAMS["issue_number"]}"
puts "=" * 60

result = ActionRunner.run(ACTION, PARAMS)

puts "  status: #{result[:status]}"

body = result[:body]
if body.is_a?(Hash)
  puts "  title:        #{body["title"]}"
  puts "  state:        #{body["state"]}"
  puts "  state_reason: #{body["state_reason"].inspect}"
  puts "  created_at:   #{body["created_at"]}"
  puts "  closed_at:    #{body["closed_at"].inspect}"
  puts "  html_url:     #{body["html_url"]}"
else
  puts body
end

puts
if result[:status] == 200 && body.is_a?(Hash)
  state = body["state"]
  reason = body["state_reason"]
  if state == "closed" && reason != "not_planned"
    puts "  => Issue is CLOSED and looks like it was resolved. Run timeline script next."
  elsif state == "closed" && reason == "not_planned"
    puts "  => Issue was closed as not_planned — no bounty payout."
  else
    puts "  => Issue is still OPEN."
  end
end
