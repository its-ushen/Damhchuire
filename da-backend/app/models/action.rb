require "json"

class Action < ApplicationRecord
  HTTP_METHODS = %w[GET POST PUT PATCH DELETE HEAD OPTIONS].freeze

  has_many :action_invocations,
    foreign_key: :action_slug,
    primary_key: :slug,
    inverse_of: :action

  before_validation :normalize_http_method
  before_validation :normalize_json_columns

  validates :slug,
    presence: true,
    uniqueness: true,
    format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ }
  validates :name, presence: true
  validates :url_template, presence: true
  validates :http_method, inclusion: { in: HTTP_METHODS }
  validate :headers_template_is_object
  validate :body_template_is_object
  validate :request_schema_is_object
  validate :response_schema_is_object

  scope :enabled, -> { where(enabled: true) }

  def snapshot
    {
      slug: slug,
      name: name,
      description: description,
      http_method: http_method,
      url_template: url_template,
      headers_template: headers_template,
      body_template: body_template,
      request_schema: request_schema,
      response_schema: response_schema,
      enabled: enabled,
      updated_at: updated_at
    }
  end

  private

  def normalize_http_method
    self.http_method = http_method.to_s.upcase.presence || "GET"
  end

  def normalize_json_columns
    self.headers_template = coerce_json_column(headers_template, default: {})
    self.body_template = coerce_json_column(body_template, default: {})
    self.request_schema = coerce_json_column(request_schema, default: {})
    self.response_schema = coerce_json_column(response_schema, default: {})
  end

  def coerce_json_column(value, default:)
    return default if value.nil?

    if value.is_a?(String)
      stripped = value.strip
      return default if stripped.empty?

      JSON.parse(stripped)
    else
      value
    end
  rescue JSON::ParserError
    value
  end

  def headers_template_is_object
    errors.add(:headers_template, "must be a JSON object") unless headers_template.is_a?(Hash)
  end

  def body_template_is_object
    errors.add(:body_template, "must be a JSON object") unless body_template.is_a?(Hash)
  end

  def request_schema_is_object
    errors.add(:request_schema, "must be a JSON object") unless request_schema.is_a?(Hash)
  end

  def response_schema_is_object
    errors.add(:response_schema, "must be a JSON object") unless response_schema.is_a?(Hash)
  end
end
