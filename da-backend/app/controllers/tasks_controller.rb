class TasksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    action_slug = params[:action_slug].to_s
    raise ArgumentError, "action_slug is required" if action_slug.blank?

    signature = DaTaskEmitter.new.on_call(
      action_slug: action_slug,
      params_json: normalized_params_json
    )

    render json: { signature: signature }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def normalized_params_json
    raw = params[:params_json]
    return {} if raw.nil?

    case raw
    when String
      parsed = JSON.parse(raw)
      raise ArgumentError, "params_json must decode to a JSON object" unless parsed.is_a?(Hash)

      parsed
    when ActionController::Parameters
      raw.to_unsafe_h
    when Hash
      raw
    else
      raise ArgumentError, "params_json must be a JSON object or JSON string"
    end
  rescue JSON::ParserError => e
    raise ArgumentError, "invalid params_json: #{e.message}"
  end
end
