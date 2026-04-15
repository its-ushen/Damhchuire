class ActionsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_action, only: %i[show update enable disable]

  def index
    render json: Action.order(:slug).map { |action| serialize_action(action) }
  end

  def show
    render json: serialize_action(@action)
  end

  def create
    action = Action.new(action_params)

    Action.transaction do
      store_credential!(action.slug) if raw_api_key.present?

      if action.save
        render json: serialize_action(action), status: :created
      else
        render json: { errors: action.errors.full_messages }, status: :unprocessable_entity
        raise ActiveRecord::Rollback
      end
    end
  end

  def update
    Action.transaction do
      store_credential!(@action.slug) if raw_api_key.present?

      if @action.update(action_params)
        render json: serialize_action(@action)
      else
        render json: { errors: @action.errors.full_messages }, status: :unprocessable_entity
        raise ActiveRecord::Rollback
      end
    end
  end

  def enable
    @action.update!(enabled: true)
    render json: serialize_action(@action)
  end

  def disable
    @action.update!(enabled: false)
    render json: serialize_action(@action)
  end

  private

  def set_action
    @action = Action.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "action not found" }, status: :not_found
  end

  def action_params
    raw_hash = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h

    raw_hash.with_indifferent_access.slice(
      :slug,
      :name,
      :description,
      :enabled,
      :http_method,
      :url_template,
      :headers_template,
      :body_template,
      :request_schema,
      :response_schema
    )
  end

  def raw_api_key
    params[:api_key].presence
  end

  def store_credential!(slug)
    cred_name = "#{slug}_api_key"
    cred = Credential.find_or_initialize_by(name: cred_name)
    cred.value = raw_api_key
    cred.save!
  end

  def serialize_action(action)
    data = action.as_json(
      only: [
        :id,
        :slug,
        :name,
        :description,
        :enabled,
        :http_method,
        :url_template,
        :headers_template,
        :body_template,
        :request_schema,
        :response_schema,
        :created_at,
        :updated_at
      ]
    )
    cred = Credential.find_by(name: "#{action.slug}_api_key")
    data["has_api_key"] = cred.present?
    data
  end
end
