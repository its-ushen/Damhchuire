# frozen_string_literal: true

require_relative "../../app/services/solana/event_handler"

Solana::EventHandler.on(:action_requested) do |event|
  puts ">>> ActionRequested ##{event[:request_id]} slug=#{event[:action_slug]}"
  ActionOracle::ProcessActionRequest.call(event)
end
