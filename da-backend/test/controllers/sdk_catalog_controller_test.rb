require "test_helper"

class SdkCatalogControllerTest < ActionDispatch::IntegrationTest
  test "returns SDK catalog envelope" do
    get "/sdk/catalog.json"

    assert_response :success

    body = JSON.parse(response.body)
    assert body.key?("generated_at")
    assert body.key?("actions")
    assert_kind_of Array, body["actions"]
  end
end
