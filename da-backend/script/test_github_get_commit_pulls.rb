#!/usr/bin/env ruby
# Test: github_get_commit_pulls
#
# Usage:
#   GITHUB_TOKEN=ghp_xxx OWNER=rails REPO=rails COMMIT_SHA=abc123 ruby script/test_github_get_commit_pulls.rb
#
# Takes a commit SHA (from the timeline script's output) and finds the PRs
# associated with it. Verifies that one is merged and extracts the contributor.
#
# Env vars:
#   GITHUB_TOKEN  required  personal access token
#   OWNER         required  repo owner
#   REPO          required  repo name
#   COMMIT_SHA    required  the commit_id from the closed timeline event

require_relative "github_action_runner"

ACTION = {
  slug: "github_get_commit_pulls",
  name: "GitHub: Get PRs for Commit",
  http_method: "GET",
  url_template: "https://api.github.com/repos/{{owner}}/{{repo}}/commits/{{commit_sha}}/pulls",
  headers_template: {
    "Authorization" => "Bearer {{credentials.github_pat}}",
    "Accept"        => "application/vnd.github+json",
    "X-GitHub-Api-Version" => "2022-11-28"
  },
  body_template: {}
}.freeze

PARAMS = {
  "owner"      => ENV.fetch("OWNER")      { abort "set OWNER" },
  "repo"       => ENV.fetch("REPO")       { abort "set REPO" },
  "commit_sha" => ENV.fetch("COMMIT_SHA") { abort "set COMMIT_SHA" }
}.freeze

puts "=" * 60
puts "  ACTION: #{ACTION[:name]}"
puts "  repo:   #{PARAMS["owner"]}/#{PARAMS["repo"]}"
puts "  commit: #{PARAMS["commit_sha"]}"
puts "=" * 60

result = ActionRunner.run(ACTION, PARAMS)
puts "  status: #{result[:status]}"
puts

body = result[:body]
unless body.is_a?(Array)
  puts body
  exit 1
end

puts "  #{body.length} PR(s) associated with this commit"
puts

body.each_with_index do |pr, i|
  puts "  [#{i}] PR ##{pr["number"]} — #{pr["title"]}"
  puts "       author:    #{pr.dig("user", "login")}"
  puts "       state:     #{pr["state"]}"
  puts "       merged:    #{pr["merged"]}"
  puts "       merged_at: #{pr["merged_at"].inspect}"
  puts "       merged_by: #{pr.dig("merged_by", "login").inspect}"
  puts
end

merged_pr = body.find { |pr| pr["merged_at"] != nil }

if merged_pr
  contributor = merged_pr.dig("user", "login")
  puts "  => PR ##{merged_pr["number"]} is MERGED"
  puts "     contributor (PR author): #{contributor}"
  puts "     merged_at:               #{merged_pr["merged_at"]}"
  puts
  puts "  Next step — resolve contributor's Solana wallet:"
  puts "  GITHUB_TOKEN=... GITHUB_USERNAME=#{contributor} ruby script/test_github_get_user_gists.rb"
else
  puts "  => No merged PR found for this commit — no bounty payout."
end
