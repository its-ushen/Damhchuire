require "json"

module ActionOracle
  class ProcessActionRequest
    class ProcessingError < StandardError; end

    def self.call(event)
      new(event).call
    end

    def initialize(event)
      @event = event
    end

    def call
      invocation = create_invocation
      return if invocation.nil?

      process(invocation)
      invocation
    end

    private

    def process(invocation)
      action = Action.find_by(slug: action_slug)
      invocation.update!(action_snapshot: action&.snapshot)
      invocation.transition_to!("running")

      if action.nil?
        raise ProcessingError, "action '#{action_slug}' not found"
      end

      unless action.enabled?
        raise ProcessingError, "action '#{action_slug}' is disabled"
      end

      params = parsed_params
      JsonSchemaValidator.validate!(schema: action.request_schema, data: params)

      execution = RestExecutor.new(action: action, params: params).call
      response_payload = execution[:parsed_body]
      JsonSchemaValidator.validate!(schema: action.response_schema, data: response_payload)

      invocation.transition_to!(
        "succeeded",
        http_status: execution[:status],
        response_body: execution[:body]
      )

      send_callback(
        invocation: invocation,
        ok: true,
        payload: response_payload
      )
    rescue => e
      invocation.transition_to!(
        "failed",
        error_message: e.message,
        http_status: nil
      ) if invocation.persisted? && invocation.status != "failed"

      send_callback(
        invocation: invocation,
        ok: false,
        payload: { "error" => e.message }
      ) if invocation&.persisted?

      Rails.logger.error("[ActionOracle::ProcessActionRequest] #{e.class}: #{e.message}")
    end

    def send_callback(invocation:, ok:, payload:)
      serialized = JSON.generate(payload)
      signature = DaTaskEmitter.new.callback(
        request_id: request_id,
        ok: ok,
        result_json: serialized
      )

      next_status = ok ? "callback_sent" : "failed"
      invocation.transition_to!(
        next_status,
        callback_payload: payload,
        callback_tx_signature: signature
      )
    rescue => e
      invocation.transition_to!(
        "callback_failed",
        callback_payload: payload,
        error_message: [ invocation.error_message, "callback error: #{e.message}" ].compact.join(" | ")
      )

      Rails.logger.error("[ActionOracle::ProcessActionRequest] callback failed: #{e.class}: #{e.message}")
    end

    def create_invocation
      existing = ActionInvocation.find_by(
        chain_tx_signature: chain_tx_signature,
        chain_request_id: request_id
      )
      return nil if existing

      ActionInvocation.create!(
        chain_request_id: request_id,
        chain_tx_signature: chain_tx_signature,
        action_slug: action_slug,
        status: "received",
        input_params: best_effort_input_params
      )
    rescue ActiveRecord::RecordNotUnique
      nil
    rescue KeyError => e
      Rails.logger.error("[ActionOracle::ProcessActionRequest] invalid event payload: #{e.message}")
      nil
    end

    def parsed_params
      @parsed_params ||= begin
        parsed = JSON.parse(raw_params_json)
        unless parsed.is_a?(Hash)
          raise ProcessingError, "params_json must decode to a JSON object"
        end

        parsed
      rescue KeyError
        raise ProcessingError, "event missing params_json"
      rescue JSON::ParserError => e
        raise ProcessingError, "invalid params_json: #{e.message}"
      end
    end

    def best_effort_input_params
      parsed = JSON.parse(raw_params_json)
      parsed.is_a?(Hash) ? parsed : { "_raw" => raw_params_json }
    rescue JSON::ParserError
      { "_raw" => raw_params_json }
    end

    def request_id
      @event.fetch(:request_id).to_i
    end

    def action_slug
      @event.fetch(:action_slug).to_s
    end

    def chain_tx_signature
      @event.fetch(:signature).to_s
    end

    def raw_params_json
      @raw_params_json ||= @event.fetch(:params_json).force_encoding("UTF-8")
    end
  end
end
