# frozen_string_literal: true

require "base64"
require "digest"

module Solana
  class AnchorEventDecoder
    PROGRAM_DATA_RE = /^Program data: (.+)$/
    DISCRIMINATOR   = Digest::SHA256.digest("event:TaskEmitted")[0, 8]

    # Scan an array of log lines and return decoded TaskEmitted events.
    def self.decode_logs(logs)
      logs.filter_map { |line| decode_line(line) }
    end

    # Decode a single log line. Returns nil unless it's a valid TaskEmitted event.
    def self.decode_line(line)
      match = PROGRAM_DATA_RE.match(line)
      return unless match

      raw = Base64.decode64(match[1])
      return if raw.bytesize < 8
      return unless raw[0, 8] == DISCRIMINATOR

      parse_task_emitted(raw[8..])
    end

    # Deserialize Borsh-encoded TaskEmitted: u64 task_id + Vec<u8> data
    def self.parse_task_emitted(buf)
      return if buf.bytesize < 12 # 8 (u64) + 4 (vec length prefix)

      task_id = buf[0, 8].unpack1("Q<")
      data_len = buf[8, 4].unpack1("V")
      return if buf.bytesize < 12 + data_len

      data = buf[12, data_len]
      { task_id: task_id, data: data }
    end
  end
end
