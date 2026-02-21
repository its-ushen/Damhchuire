# frozen_string_literal: true

module Solana
  class EventHandler
    def self.on(event_type, &block)
      handlers[event_type] << block
    end

    def self.dispatch(event_type, event)
      handlers[event_type].each { |h| h.call(event) }
    end

    def self.handlers
      @handlers ||= Hash.new { |h, k| h[k] = [] }
    end
  end
end
