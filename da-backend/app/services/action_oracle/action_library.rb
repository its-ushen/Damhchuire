module ActionOracle
  class ActionLibrary
    def self.actions
      [
        discord_send_message,
        slack_send_message,
        http_get_json
      ]
    end

    def self.discord_send_message
      {
        slug: "discord_send_message",
        name: "Discord: Send Message",
        description: "Send a message to a Discord channel using credential 'discord_bot_token'.",
        enabled: true,
        http_method: "POST",
        url_template: "https://discord.com/api/v10/channels/{{channel_id}}/messages",
        headers_template: {
          "Authorization" => "Bot {{credentials.discord_bot_token}}",
          "Content-Type" => "application/json"
        },
        body_template: {
          "content" => "{{content}}"
        },
        request_schema: {
          "type" => "object",
          "required" => [ "channel_id", "content" ],
          "properties" => {
            "channel_id" => { "type" => "string" },
            "content" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "object",
          "required" => [ "id" ],
          "properties" => {
            "id" => { "type" => "string" }
          },
          "additionalProperties" => true
        }
      }
    end

    def self.slack_send_message
      {
        slug: "slack_send_message",
        name: "Slack: Send Incoming Webhook Message",
        description: "Send a simple text message to a Slack incoming webhook URL.",
        enabled: true,
        http_method: "POST",
        url_template: "{{webhook_url}}",
        headers_template: {
          "Content-Type" => "application/json"
        },
        body_template: {
          "text" => "{{text}}"
        },
        request_schema: {
          "type" => "object",
          "required" => [ "webhook_url", "text" ],
          "properties" => {
            "webhook_url" => { "type" => "string" },
            "text" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {
          "type" => "string"
        }
      }
    end

    def self.http_get_json
      {
        slug: "http_get_json",
        name: "HTTP: GET JSON",
        description: "Perform a GET request to a public URL and return the JSON response.",
        enabled: true,
        http_method: "GET",
        url_template: "{{url}}",
        headers_template: {},
        body_template: {},
        request_schema: {
          "type" => "object",
          "required" => [ "url" ],
          "properties" => {
            "url" => { "type" => "string" }
          },
          "additionalProperties" => false
        },
        response_schema: {}
      }
    end
  end
end
