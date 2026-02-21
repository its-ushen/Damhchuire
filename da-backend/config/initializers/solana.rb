# frozen_string_literal: true

module Solana
  PROGRAM_ID = "91XcSJyrQZpmJifL9TggBXHrXELtNrP3xSZ217DVGjWs"
  WS_URL     = ENV.fetch("SOLANA_WS_URL", "ws://127.0.0.1:8900")
end
