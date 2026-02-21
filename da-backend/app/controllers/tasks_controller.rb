class TasksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    signature = DaTaskEmitter.new.emit(params[:data].to_s)
    render json: { signature: signature }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
