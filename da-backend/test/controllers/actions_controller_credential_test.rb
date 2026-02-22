require "test_helper"

class ActionsControllerCredentialTest < ActionDispatch::IntegrationTest
  test "creating action with api_key stores credential" do
    assert_difference("Credential.count", 1) do
      post api_actions_url(format: :json), params: {
        slug: "weather",
        name: "Weather API",
        http_method: "GET",
        url_template: "https://api.weather.com/forecast",
        api_key: "sk-weather-secret"
      }
    end

    assert_response :created
    cred = Credential.find_by(name: "weather_api_key")
    assert_not_nil cred
    assert_equal "sk-weather-secret", cred.value
  end

  test "creating action without api_key does not create credential" do
    assert_no_difference("Credential.count") do
      post api_actions_url(format: :json), params: {
        slug: "no-key",
        name: "No Key Action",
        http_method: "GET",
        url_template: "https://example.com"
      }
    end

    assert_response :created
  end

  test "updating action with api_key updates credential" do
    action = Action.create!(
      slug: "updatable",
      name: "Updatable",
      http_method: "GET",
      url_template: "https://example.com"
    )
    Credential.create!(name: "updatable_api_key", value: "old-secret")

    patch api_action_url(action, format: :json), params: { api_key: "new-secret" }
    assert_response :success

    assert_equal "new-secret", Credential.find_by(name: "updatable_api_key").value
  end

  test "serialize_action includes has_api_key flag" do
    Action.create!(
      slug: "withkey",
      name: "With Key",
      http_method: "GET",
      url_template: "https://example.com"
    )
    Credential.create!(name: "withkey_api_key", value: "secret")

    get api_actions_url(format: :json), headers: { "Accept" => "application/json" }
    assert_response :success

    actions = JSON.parse(response.body)
    with_key = actions.find { |a| a["slug"] == "withkey" }
    assert_equal true, with_key["has_api_key"]
  end

  test "serialize_action never exposes credential value" do
    post api_actions_url(format: :json), params: {
      slug: "secrettest",
      name: "Secret Test",
      http_method: "GET",
      url_template: "https://example.com",
      api_key: "super-secret"
    }
    assert_response :created

    body = JSON.parse(response.body)
    assert_nil body["api_key"]
    assert_nil body["credential"]
    assert_not_includes body.values.map(&:to_s).join, "super-secret"
  end
end
