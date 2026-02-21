# frozen_string_literal: true

require_relative "../../app/services/solana/event_handler"

Solana::EventHandler.on(:task_emitted) do |event|
  data_str = event[:data].force_encoding("UTF-8")

  next if data_str.start_with?("ack:")

  puts ">>> Task ##{event[:task_id]} received with #{event[:data].bytesize} bytes"

  response = "ack:#{event[:task_id]}"
  signature = DaTaskEmitter.new.emit(response)
  puts ">>> Emitted ack tx: #{signature}"
end
