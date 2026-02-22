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

    if action.save
      render json: serialize_action(action), status: :created
    else
      render json: { errors: action.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @action.update(action_params)
      render json: serialize_action(@action)
    else
      render json: { errors: @action.errors.full_messages }, status: :unprocessable_entity
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
    raw = params[:action].presence || params
    raw_hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h

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

  def serialize_action(action)
    action.as_json(
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
  end
end
