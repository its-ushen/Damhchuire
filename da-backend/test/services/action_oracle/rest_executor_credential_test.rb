require "test_helper"

class ActionOracle::RestExecutorCredentialTest < ActiveSupport::TestCase
  setup do
    @action = Action.create!(
      slug: "cred-test",
      name: "Credential Test",
      http_method: "GET",
      url_template: "https://api.example.com/data",
      headers_template: { "Authorization" => "Bearer {{ credential.test_api_key }}" }
    )
    Credential.create!(name: "test_api_key", value: "sk-secret-123")
  end

  test "template_values includes credential namespace" do
    executor = ActionOracle::RestExecutor.new(action: @action, params: { "foo" => "bar" })
    tv = executor.send(:template_values)

    assert_equal "bar", tv["foo"]
    assert_equal "sk-secret-123", tv["credential"]["test_api_key"]
  end

  test "template_values strips credential key from params to prevent override" do
    executor = ActionOracle::RestExecutor.new(
      action: @action,
      params: { "credential" => "hijack" }
    )
    tv = executor.send(:template_values)

    assert_kind_of Hash, tv["credential"]
    assert_equal "sk-secret-123", tv["credential"]["test_api_key"]
  end

  test "rendered_headers resolves credential placeholders" do
    executor = ActionOracle::RestExecutor.new(action: @action, params: {})
    headers = executor.send(:rendered_headers)

    assert_equal "Bearer sk-secret-123", headers["Authorization"]
  end

  test "rendered_headers raises for missing credential" do
    @action.update!(headers_template: { "Authorization" => "Bearer {{ credential.nonexistent }}" })
    executor = ActionOracle::RestExecutor.new(action: @action, params: {})

    assert_raises(ActionOracle::TemplateRenderer::MissingVariableError) do
      executor.send(:rendered_headers)
    end
  end
end
