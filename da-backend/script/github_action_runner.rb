# Shared inline runner used by all github action test scripts.
# No Rails required — just stdlib Net::HTTP.

require "net/http"
require "uri"
require "json"

module ActionRunner
  PLACEHOLDER_RE = /\{\{\s*([a-zA-Z0-9_.-]+)\s*\}\}/.freeze

  def self.render_string(template, values)
    template.to_s.gsub(PLACEHOLDER_RE) do
      key = Regexp.last_match(1)
      value = dig_value(values, key)
      abort "  [error] missing template value: #{key}" if value.nil?
      value.to_s
    end
  end

  def self.render_hash(hash, values)
    hash.each_with_object({}) do |(k, v), out|
      out[k] = v.is_a?(Hash) ? render_hash(v, values) : render_string(v.to_s, values)
    end
  end

  def self.dig_value(values, key_path)
    key_path.split(".").reduce(values) do |current, key|
      return nil unless current.is_a?(Hash)
      current[key] || current[key.to_sym]
    end
  end

  def self.run(action, params)
    values = params.merge("credentials" => {
      "github_pat" => ENV.fetch("GITHUB_TOKEN") { abort "  [error] GITHUB_TOKEN env var not set" }
    })

    url     = render_string(action[:url_template], values)
    headers = render_hash(action[:headers_template], values)
    method  = action[:http_method].upcase

    uri     = URI.parse(url)
    http    = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"

    request_klass = {
      "GET"  => Net::HTTP::Get,
      "POST" => Net::HTTP::Post
    }.fetch(method) { abort "  [error] unsupported method: #{method}" }

    req = request_klass.new(uri.request_uri)
    headers.each { |k, v| req[k] = v }

    puts
    puts "  -> #{method} #{url}"
    puts

    response      = http.request(req)
    parsed        = JSON.parse(response.body) rescue response.body
    status        = response.code.to_i

    { status: status, body: parsed }
  end
end
