class ActionInvocationsController < ApplicationController
  def index
    limit = params.fetch(:limit, 100).to_i.clamp(1, 500)
    invocations = ActionInvocation.recent_first.limit(limit)

    render json: invocations.map { |invocation| serialize_invocation(invocation) }
  end

  def show
    invocation = ActionInvocation.find(params[:id])
    render json: serialize_invocation(invocation)
  rescue ActiveRecord::RecordNotFound
    render json: { error: "action invocation not found" }, status: :not_found
  end

  private

  def serialize_invocation(invocation)
    invocation.as_json(
      only: [
        :id,
        :chain_request_id,
        :chain_tx_signature,
        :action_slug,
        :status,
        :input_params,
        :action_snapshot,
        :http_status,
        :response_body,
        :callback_payload,
        :callback_tx_signature,
        :error_message,
        :created_at,
        :updated_at
      ]
    )
  end
end
