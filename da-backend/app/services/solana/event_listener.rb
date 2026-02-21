# frozen_string_literal: true

require "json"
require "websocket-client-simple"

module Solana
  class EventListener
    TAG = "[Solana::EventListener]"

    def initialize(ws_url: Solana::WS_URL, program_id: Solana::PROGRAM_ID)
      @ws_url     = ws_url
      @program_id = program_id
      @running    = true
      @request_id = 0
    end

    def start
      trap("INT") { graceful_shutdown }
      trap("TERM") { graceful_shutdown }

      while @running
        run_connection
        break unless @running

        log "Disconnected. Reconnecting in 5s..."
        sleep 5
      end

      log "Shut down."
    end

    private

    def run_connection
      listener = self
      ws = WebSocket::Client::Simple.connect(@ws_url)

      ws.on :open do
        listener.send(:on_open, ws)
      end

      ws.on :message do |msg|
        listener.send(:on_message, msg)
      end

      ws.on :error do |e|
        listener.send(:on_error, e)
      end

      ws.on :close do
        listener.send(:on_close)
      end

      sleep 0.5 while ws.open? && @running
      ws.close if ws.open?
    rescue => e
      log "Connection error: #{e.message}"
    end

    def on_open(ws)
      log "Connected. Subscribing to logs..."
      @request_id += 1
      subscribe_msg = {
        jsonrpc: "2.0",
        id: @request_id,
        method: "logsSubscribe",
        params: [
          { mentions: [@program_id] },
          { commitment: "confirmed" }
        ]
      }
      ws.send(subscribe_msg.to_json)
    end

    def on_message(msg)
      data = JSON.parse(msg.data)

      if data["result"] && !data.key?("method")
        log "Subscribed. ID=#{data["result"]}"
        return
      end

      return unless data["method"] == "logsNotification"

      process_notification(data["params"])
    rescue JSON::ParserError => e
      log "JSON parse error: #{e.message}"
    end

    def on_error(e)
      log "WebSocket error: #{e.message}"
    end

    def on_close
      log "WebSocket closed."
    end

    def process_notification(params)
      result = params&.dig("result")
      return unless result

      value = result["value"]
      return unless value

      # Skip failed transactions
      if value.dig("err")
        log "Skipping failed tx: #{value["signature"]}"
        return
      end

      logs = value["logs"] || []
      events = AnchorEventDecoder.decode_logs(logs)

      events.each do |event|
        handle_event(
          event,
          signature: value["signature"],
          slot: result["context"]&.fetch("slot", nil)
        )
      end
    end

    def handle_event(event, signature:, slot:)
      hex = event[:data].unpack1("H*")
      log "=== TaskEmitted Event ==="
      log "  task_id: #{event[:task_id]}"
      log "  data (hex): #{hex}"
      log "  data (raw): <#{event[:data].bytesize} bytes>"
      log "  tx: #{signature}"
      log "  slot: #{slot}"
      log "========================"
    end

    def graceful_shutdown
      log "Shutting down..."
      @running = false
    end

    def log(message)
      puts "#{TAG} #{message}"
    end
  end
end
