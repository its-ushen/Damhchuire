require "test_helper"

class ActionOracle::ActionLibraryInstallerTest < ActiveSupport::TestCase
  test "installs the discord action definition" do
    result = ActionOracle::ActionLibraryInstaller.call(
      actions: [ ActionOracle::ActionLibrary.discord_send_message ]
    )

    assert_equal [ "discord_send_message" ], result[:created]
    assert_empty result[:updated]

    action = Action.find_by!(slug: "discord_send_message")
    assert_equal "Discord: Send Message", action.name
    assert_equal "POST", action.http_method
    assert_equal({ "content" => "{{content}}" }, action.body_template)
    assert_equal "Bot {{credentials.discord_bot_token}}", action.headers_template["Authorization"]
  end

  test "updates an existing action definition" do
    Action.create!(
      slug: "discord_send_message",
      name: "Old Name",
      description: "old",
      enabled: false,
      http_method: "POST",
      url_template: "https://example.com/legacy",
      headers_template: {},
      body_template: {},
      request_schema: {},
      response_schema: {}
    )

    result = ActionOracle::ActionLibraryInstaller.call(
      actions: [ ActionOracle::ActionLibrary.discord_send_message ]
    )

    assert_empty result[:created]
    assert_equal [ "discord_send_message" ], result[:updated]

    action = Action.find_by!(slug: "discord_send_message")
    assert_equal "Discord: Send Message", action.name
    assert_equal true, action.enabled
    assert_equal "https://discord.com/api/v10/channels/{{channel_id}}/messages", action.url_template
  end
end
