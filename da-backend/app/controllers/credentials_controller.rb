class CredentialsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_credential, only: %i[update destroy]

  def index
    render json: Credential.order(:name).map { |c| serialize_credential(c) }
  end

  def create
    credential = Credential.new(credential_params)

    if credential.save
      render json: serialize_credential(credential), status: :created
    else
      render json: { errors: credential.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @credential.update(credential_params)
      render json: serialize_credential(@credential)
    else
      render json: { errors: @credential.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @credential.destroy!
    head :no_content
  end

  private

  def set_credential
    @credential = Credential.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "credential not found" }, status: :not_found
  end

  def credential_params
    params.permit(:name, :value)
  end

  def serialize_credential(credential)
    {
      id: credential.id,
      name: credential.name,
      created_at: credential.created_at,
      updated_at: credential.updated_at
    }
  end
end
