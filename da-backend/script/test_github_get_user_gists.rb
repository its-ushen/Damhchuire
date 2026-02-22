#!/usr/bin/env ruby
# Test: github_get_user_gists
#
# Usage:
#   GITHUB_TOKEN=ghp_xxx GITHUB_USERNAME=its-ushen ruby script/test_github_get_user_gists.rb
#
# Fetches the contributor's public gists and looks for one containing
# a Solana wallet address (file named solana-wallet.txt, content solana:<PUBKEY>).
#
# Env vars:
#   GITHUB_TOKEN      required  personal access token
#   GITHUB_USERNAME   required  the contributor's GitHub username

require_relative "github_action_runner"

WALLET_FILENAME = "solana-wallet.txt"
WALLET_PREFIX   = "solana:"

ACTION = {
  slug: "github_get_user_gists",
  name: "GitHub: Get User Gists",
  http_method: "GET",
  url_template: "https://api.github.com/users/{{username}}/gists",
  headers_template: {
    "Authorization" => "Bearer {{credentials.github_pat}}",
    "Accept"        => "application/vnd.github+json",
    "X-GitHub-Api-Version" => "2022-11-28"
  },
  body_template: {}
}.freeze

PARAMS = {
  "username" => ENV.fetch("GITHUB_USERNAME") { abort "set GITHUB_USERNAME" }
}.freeze

puts "=" * 60
puts "  ACTION: #{ACTION[:name]}"
puts "  user:   #{PARAMS["username"]}"
puts "=" * 60

result = ActionRunner.run(ACTION, PARAMS)
puts "  status: #{result[:status]}"
puts

body = result[:body]
unless body.is_a?(Array)
  puts body
  exit 1
end

puts "  #{body.length} public gist(s) found"
puts

# Find gist containing solana-wallet.txt
wallet_gist = body.find { |g| g["files"]&.key?(WALLET_FILENAME) }

unless wallet_gist
  puts "  => No gist found with file '#{WALLET_FILENAME}'"
  puts "     Contributor needs to create a public gist with:"
  puts "       filename: #{WALLET_FILENAME}"
  puts "       content:  #{WALLET_PREFIX}<SOLANA_PUBKEY>"
  exit 1
end

puts "  => Found wallet gist: #{wallet_gist["html_url"]}"
puts "     gist id:     #{wallet_gist["id"]}"
puts "     description: #{wallet_gist["description"].inspect}"
puts

# Fetch the raw content of the file
raw_url = wallet_gist.dig("files", WALLET_FILENAME, "raw_url")
puts "  Fetching raw content from: #{raw_url}"

require "open-uri"
raw_content = URI.open(raw_url).read.strip
puts "  raw content: #{raw_content.inspect}"
puts

if raw_content.start_with?(WALLET_PREFIX)
  pubkey = raw_content.delete_prefix(WALLET_PREFIX).strip
  puts "  => Solana wallet resolved"
  puts "     github_username: #{PARAMS["username"]}"
  puts "     solana_pubkey:   #{pubkey}"
  puts
  puts "  This pubkey is the recipient for sol.transfer."
else
  puts "  => Gist content does not match expected format '#{WALLET_PREFIX}<PUBKEY>'"
  puts "     got: #{raw_content.inspect}"
end
