class ReinvokingRpcController < ActionController::API
  def rpc_call
    # TODO - can this caller invoke this action?

    action = Action.find(params[:action_id])

    execution = RestExecutor.new(action: action, params: params).call

    Rails.logger.info(execution)

    # TODO: result
    render json: { 1 => 2 }
  end
end
