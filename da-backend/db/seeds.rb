# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# ── Weather Now action ───────────────────────────────────────────────────────
Action.find_or_create_by!(slug: "weather_now") do |a|
  a.name = "Weather Now"
  a.description = "Gets the current weather with more detail"
  a.http_method = "GET"
  a.url_template = "https://wttr.in/{{city}}?format=j1"
  a.headers_template = {}
  a.request_schema = {
    "type" => "object",
    "required" => ["city"],
    "properties" => {
      "city" => { "type" => "string" },
      "unit" => { "type" => "string" }
    }
  }
  a.response_schema = {
    "type" => "object",
    "required" => ["temp_c"],
    "properties" => {
      "temp_c"    => { "type" => "number" },
      "condition" => { "type" => "string" }
    }
  }
end

# ── Weather action ───────────────────────────────────────────────────────────
Action.find_or_create_by!(slug: "weather") do |a|
  a.name = "Weather"
  a.description = "Gets the current weather for a city"
  a.http_method = "GET"
  a.url_template = "https://wttr.in/{{city}}?format=j1"
  a.headers_template = {}
  a.request_schema = {
    "type" => "object",
    "required" => ["city"],
    "properties" => {
      "city" => { "type" => "string" }
    }
  }
  a.response_schema = {
    "type" => "object",
    "required" => ["temp_c"],
    "properties" => {
      "temp_c" => { "type" => "number" }
    }
  }
end

# ── Crypto Price action ─────────────────────────────────────────────────────
Action.find_or_create_by!(slug: "crypto_price") do |a|
  a.name = "Crypto Price"
  a.description = "Fetches the current price of a cryptocurrency"
  a.http_method = "GET"
  a.url_template = "https://api.coingecko.com/api/v3/simple/price?ids={{symbol}}&vs_currencies=usd"
  a.headers_template = {}
  a.request_schema = {
    "type" => "object",
    "required" => ["symbol"],
    "properties" => {
      "symbol" => { "type" => "string" }
    }
  }
  a.response_schema = {
    "type" => "object",
    "required" => ["price_usd", "symbol"],
    "properties" => {
      "price_usd" => { "type" => "number" },
      "symbol"    => { "type" => "string" }
    }
  }
end

# ── Quote of the Day action ─────────────────────────────────────────────────
Action.find_or_create_by!(slug: "quote_of_day") do |a|
  a.name = "Quote of the Day"
  a.description = "Returns a random quote of the day"
  a.http_method = "GET"
  a.url_template = "https://zenquotes.io/api/today"
  a.headers_template = {}
  a.request_schema = {
    "type" => "object",
    "properties" => {}
  }
  a.response_schema = {
    "type" => "object",
    "required" => ["quote"],
    "properties" => {
      "quote"  => { "type" => "string" },
      "author" => { "type" => "string" }
    }
  }
end

# ── AI Chat (OpenRouter) action ──────────────────────────────────────────────
Action.find_or_create_by!(slug: "ai_chat") do |a|
  a.name = "AI Chat (OpenRouter)"
  a.description = "Calls OpenRouter chat completions. Model and prompt are set by the calling contract."
  a.http_method = "POST"
  a.url_template = "https://openrouter.ai/api/v1/chat/completions"
  a.headers_template = {
    "Authorization" => "Bearer {{credential.ai_chat_api_key}}",
    "HTTP-Referer"  => "https://damhchuire.io",
    "X-Title"       => "Damhchuire Oracle"
  }
  a.request_schema = {
    "type" => "object",
    "required" => ["model", "messages"],
    "properties" => {
      "model"    => { "type" => "string" },
      "messages" => { "type" => "array", "items" => { "type" => "object" } }
    }
  }
  a.response_schema = {
    "type" => "object",
    "properties" => {
      "id"      => { "type" => "string" },
      "choices" => { "type" => "array", "items" => { "type" => "object" } },
      "usage"   => { "type" => "object" }
    }
  }
end

# ── OpenRouter API key credential ────────────────────────────────────────────
if ENV["OPENROUTER_API_KEY"].present?
  Credential.find_or_create_by!(name: "ai_chat_api_key") do |c|
    c.value = ENV["OPENROUTER_API_KEY"]
  end
end
