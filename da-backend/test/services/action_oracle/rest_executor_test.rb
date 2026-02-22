require "test_helper"

class ActionOracle::RestExecutorTest < ActiveSupport::TestCase
  class FakeHttpResponse
    attr_reader :code, :body

    def initialize(code:, body:, headers:)
      @code = code
      @body = body
      @headers = headers
    end

    def to_hash
      @headers
    end
  end

  class FakeHttp
    attr_accessor :use_ssl, :open_timeout, :read_timeout
    attr_reader :captured_request

    def initialize(response)
      @response = response
    end

    def request(request)
      @captured_request = request
      @response
    end
  end

  test "renders credentials and body templates for discord action" do
    Credential.create!(name: "discord_bot_token", value: "token-123")

    action = Action.create!(
      slug: "discord_send_message_test",
      name: "Discord test",
      http_method: "POST",
      url_template: "https://discord.com/api/v10/channels/{{channel_id}}/messages",
      headers_template: {
        "Authorization" => "Bot {{credentials.discord_bot_token}}"
      },
      body_template: {
        "content" => "{{content}}"
      },
      request_schema: {},
      response_schema: {}
    )

    fake_response = FakeHttpResponse.new(
      code: "200",
      body: "{\"id\":\"999\"}",
      headers: { "content-type" => [ "application/json" ] }
    )
    fake_http = FakeHttp.new(fake_response)

    result = Net::HTTP.stub(:new, ->(_host, _port) { fake_http }) do
      ActionOracle::RestExecutor.new(
        action: action,
        params: { "channel_id" => "123", "content" => "hello world" }
      ).call
    end

    assert_equal "/api/v10/channels/123/messages", fake_http.captured_request.path
    assert_equal "Bot token-123", fake_http.captured_request["Authorization"]
    assert_equal({ "content" => "hello world" }, JSON.parse(fake_http.captured_request.body))
    assert_equal 200, result[:status]
    assert_equal({ "id" => "999" }, result[:parsed_body])
  end

  test "falls back to full params when body_template is blank" do
    action = Action.create!(
      slug: "post_echo_test",
      name: "Post echo",
      http_method: "POST",
      url_template: "https://example.com/echo",
      headers_template: {},
      body_template: {},
      request_schema: {},
      response_schema: {}
    )

    fake_response = FakeHttpResponse.new(
      code: "200",
      body: "{\"ok\":true}",
      headers: { "content-type" => [ "application/json" ] }
    )
    fake_http = FakeHttp.new(fake_response)
    input_params = { "message" => "hi", "count" => 2 }

    Net::HTTP.stub(:new, ->(_host, _port) { fake_http }) do
      ActionOracle::RestExecutor.new(action: action, params: input_params).call
    end

    assert_equal input_params, JSON.parse(fake_http.captured_request.body)
  end
end
