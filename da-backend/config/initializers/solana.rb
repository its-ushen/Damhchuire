# frozen_string_literal: true

module Solana
  PROGRAM_ID = ENV.fetch("SOLANA_PROGRAM_ID", "9JsLkqyRpEJxBXoGGtaRobMUyGvtxijVet7YGXCCsDD5")
  WS_URL     = ENV.fetch("SOLANA_WS_URL", "ws://127.0.0.1:8900")
end
