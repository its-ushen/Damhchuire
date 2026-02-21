# frozen_string_literal: true

require_relative "../../app/services/solana/event_handler"

Solana::EventHandler.on(:task_emitted) do |event|
  puts ">>> Task ##{event[:task_id]} received with #{event[:data].bytesize} bytes"
end
