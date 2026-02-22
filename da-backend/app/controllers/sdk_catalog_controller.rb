class SdkCatalogController < ApplicationController
  def show
    render json: {
      generated_at: Time.current.iso8601,
      actions: catalog_actions
    }
  end

  private

  def catalog_actions
    return [] unless action_model_available?

    Action.enabled.order(:slug).map { |action| catalog_action(action) }
  end

  def action_model_available?
    return false unless Object.const_defined?(:Action)
    return false unless Action.respond_to?(:enabled)
    return false unless Action.respond_to?(:table_exists?)

    Action.table_exists?
  rescue StandardError
    false
  end

  def catalog_action(action)
    {
      slug: action.slug,
      description: action.description,
      request_schema: action.request_schema,
      response_schema: action.response_schema,
      invocation: {
        contract_method: "on_call",
        callback_method: "callback",
        params_encoding: "json_utf8_bytes"
      }
    }
  end
end
