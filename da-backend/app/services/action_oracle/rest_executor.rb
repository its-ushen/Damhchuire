require "json"
require "ipaddr"
require "net/http"
require "uri"

module ActionOracle
  class RestExecutor
    TRANSIENT_ERRORS = [
      Timeout::Error,
      Errno::ECONNRESET,
      Errno::ECONNREFUSED,
      Errno::EHOSTUNREACH,
      Errno::ETIMEDOUT,
      EOFError,
      SocketError,
      Net::OpenTimeout,
      Net::ReadTimeout
    ].freeze

    RETRYABLE_HTTP_STATUSES = [429, 500, 502, 503, 504].freeze
    REQUEST_CLASS = {
      "GET" => Net::HTTP::Get,
      "POST" => Net::HTTP::Post,
      "PUT" => Net::HTTP::Put,
      "PATCH" => Net::HTTP::Patch,
      "DELETE" => Net::HTTP::Delete,
      "HEAD" => Net::HTTP::Head,
      "OPTIONS" => Net::HTTP::Options
    }.freeze

    def initialize(action:, params:)
      @action = action
      @params = params.is_a?(Hash) ? params : {}
    end

    def call
      attempts = 0

      loop do
        attempts += 1
        response = begin
          perform_request
        rescue *TRANSIENT_ERRORS
          raise if attempts >= max_attempts

          sleep(backoff_for(attempts))
          next
        end

        if retryable_http_status?(response[:status]) && attempts < max_attempts
          sleep(backoff_for(attempts))
          next
        end

        return response
      end
    end

    private

    def perform_request
      method = @action.http_method.to_s.upcase
      request_klass = REQUEST_CLASS[method]
      raise ArgumentError, "unsupported HTTP method: #{method}" unless request_klass

      url = TemplateRenderer.render_string(@action.url_template, template_values)
      uri = URI.parse(url)
      validate_target!(uri)

      request = request_klass.new(uri.request_uri)
      headers = rendered_headers
      headers.each { |key, value| request[key.to_s] = value.to_s }

      if request.request_body_permitted?
        body = rendered_body
        request["Content-Type"] ||= "application/json"
        request.body = JSON.generate(body)
      end

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = open_timeout_seconds
      http.read_timeout = read_timeout_seconds

      response = http.request(request)
      response_body = response.body.to_s

      {
        status: response.code.to_i,
        body: response_body,
        parsed_body: parse_response_body(response_body),
        headers: normalize_headers(response.to_hash)
      }
    end

    def rendered_headers
      template = @action.headers_template.is_a?(Hash) ? @action.headers_template : {}
      rendered = TemplateRenderer.render_json(template, template_values)
      rendered.is_a?(Hash) ? rendered : {}
    end

    def rendered_body
      template = @action.body_template.is_a?(Hash) ? @action.body_template : {}
      return @params if template.blank?

      rendered = TemplateRenderer.render_json(template, template_values)
      rendered.is_a?(Hash) ? rendered : @params
    end

    def template_values
      @template_values ||= begin
        values = @params.dup
        values.delete("credential")
        values.delete(:credential)
        values["credential"] = Credential.values_hash
        values
      end
    end

    def normalize_headers(raw_headers)
      raw_headers.each_with_object({}) do |(key, value), normalized|
        normalized[key] = value.is_a?(Array) && value.length == 1 ? value.first : value
      end
    end

    def parse_response_body(raw_body)
      return nil if raw_body.strip.empty?

      JSON.parse(raw_body)
    rescue JSON::ParserError
      raw_body
    end

    def retryable_http_status?(status)
      RETRYABLE_HTTP_STATUSES.include?(status.to_i)
    end

    def validate_target!(uri)
      return if allow_private_urls?

      host = uri.host.to_s
      raise ArgumentError, "action URL must include a host" if host.empty?

      if host == "localhost" || host.end_with?(".local")
        raise ArgumentError, "private/internal hosts are not allowed: #{host}"
      end

      ip = IPAddr.new(host)
      if ip.private? || ip.loopback? || ip.link_local?
        raise ArgumentError, "private/internal IPs are not allowed: #{host}"
      end
    rescue IPAddr::InvalidAddressError
      # Host is a DNS name. Skip IP checks here.
    end

    def allow_private_urls?
      ENV.fetch("ALLOW_PRIVATE_ACTION_URLS", "false") == "true"
    end

    def max_attempts
      ENV.fetch("ACTION_HTTP_MAX_ATTEMPTS", "3").to_i.clamp(1, 10)
    end

    def open_timeout_seconds
      ENV.fetch("ACTION_HTTP_OPEN_TIMEOUT", "5").to_i.clamp(1, 60)
    end

    def read_timeout_seconds
      ENV.fetch("ACTION_HTTP_READ_TIMEOUT", "10").to_i.clamp(1, 120)
    end

    def backoff_for(attempt)
      [0.2 * attempt, 2.0].min
    end
  end
end
