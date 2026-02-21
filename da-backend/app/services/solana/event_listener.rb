# frozen_string_literal: true

require "json"
require "websocket-client-simple"

module Solana
  class EventListener
    TAG = "[Solana::EventListener]"
    PING_INTERVAL = 20 # seconds – keepalive via JSON-RPC getHealth

    def initialize(ws_url: Solana::WS_URL, program_id: Solana::PROGRAM_ID)
      @ws_url     = ws_url
      @program_id = program_id
      @running    = true
      @request_id = 0
      @seen_signatures = {}
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

      last_ping = Time.now
      while ws.open? && @running
        if Time.now - last_ping >= PING_INTERVAL
          ping_msg = { jsonrpc: "2.0", id: next_request_id, method: "getHealth" }.to_json
          ws.send(ping_msg)
          last_ping = Time.now
        end
        sleep 0.5
      end
      ws.close if ws.open?
    rescue => e
      log "Connection error: #{e.message}"
    end

    def next_request_id
      @request_id += 1
    end

    def on_open(ws)
      log "Connected. Subscribing to logs..."
      subscribe_msg = {
        jsonrpc: "2.0",
        id: next_request_id,
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

      # Ignore RPC responses (subscription confirmations, health checks, etc.)
      if data.key?("id") && !data.key?("method")
        if data["result"].is_a?(Integer)
          log "Subscribed. ID=#{data['result']}"
        end
        return
      end

      return unless data["method"] == "logsNotification"

      process_notification(data["params"])
    rescue JSON::ParserError => e
      log "JSON parse error: #{e.message}"
    end

    def on_error(e)
      log "WebSocket error: #{e.class}: #{e.message}"
      log "  #{e.backtrace&.first(5)&.join("\n  ")}" if e.respond_to?(:backtrace)
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

      signature = value["signature"]
      slot = result["context"]&.fetch("slot", nil)

      # Deduplicate — skip if we've already processed this tx
      if @seen_signatures[signature]
        return
      end
      @seen_signatures[signature] = true

      # Evict old entries to avoid unbounded growth
      @seen_signatures.shift if @seen_signatures.size > 1000

      logs = value["logs"] || []
      events = AnchorEventDecoder.decode_logs(logs)

      events.each do |event|
        handle_event(event, signature: signature, slot: slot)
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
      log "========================="
      EventHandler.dispatch(:task_emitted, event.merge(signature: signature, slot: slot))
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
