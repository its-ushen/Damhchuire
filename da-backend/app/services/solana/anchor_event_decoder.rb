# frozen_string_literal: true

require "base64"
require "digest"

module Solana
  class AnchorEventDecoder
    PROGRAM_DATA_RE = /^Program data: (.+)$/
    ACTION_REQUESTED_DISCRIMINATOR = Digest::SHA256.digest("event:ActionRequested")[0, 8]
    ACTION_COMPLETED_DISCRIMINATOR = Digest::SHA256.digest("event:ActionCompleted")[0, 8]

    # Scan an array of log lines and return decoded Anchor events.
    def self.decode_logs(logs)
      logs.filter_map { |line| decode_line(line) }
    end

    # Decode a single log line. Returns nil unless it's a valid known event.
    def self.decode_line(line)
      match = PROGRAM_DATA_RE.match(line)
      return unless match

      raw = Base64.decode64(match[1])
      return if raw.bytesize < 8

      discriminator = raw[0, 8]
      payload = raw.byteslice(8, raw.bytesize - 8) || +""

      case discriminator
      when ACTION_REQUESTED_DISCRIMINATOR
        parse_action_requested(payload)&.merge(event_type: :action_requested)
      when ACTION_COMPLETED_DISCRIMINATOR
        parse_action_completed(payload)&.merge(event_type: :action_completed)
      end
    end

    # Deserialize Borsh-encoded ActionRequested: u64 + String + Vec<u8>
    def self.parse_action_requested(buf)
      request_id, offset = read_u64(buf, 0)
      return unless request_id

      action_slug, offset = read_string(buf, offset)
      return unless action_slug

      params_json, offset = read_vec_u8(buf, offset)
      return unless params_json
      return unless offset == buf.bytesize

      { request_id: request_id, action_slug: action_slug, params_json: params_json }
    end

    # Deserialize Borsh-encoded ActionCompleted: u64 + bool + Vec<u8>
    def self.parse_action_completed(buf)
      request_id, offset = read_u64(buf, 0)
      return unless request_id

      ok, offset = read_bool(buf, offset)
      return if ok.nil?

      result_json, offset = read_vec_u8(buf, offset)
      return unless result_json
      return unless offset == buf.bytesize

      { request_id: request_id, ok: ok, result_json: result_json }
    end

    def self.read_u32(buf, offset)
      return [ nil, offset ] if buf.bytesize < offset + 4

      [ buf[offset, 4].unpack1("V"), offset + 4 ]
    end

    def self.read_u64(buf, offset)
      return [ nil, offset ] if buf.bytesize < offset + 8

      [ buf[offset, 8].unpack1("Q<"), offset + 8 ]
    end

    def self.read_bool(buf, offset)
      return [ nil, offset ] if buf.bytesize < offset + 1

      value = buf.getbyte(offset)
      return [ nil, offset ] unless value == 0 || value == 1

      [ value == 1, offset + 1 ]
    end

    def self.read_vec_u8(buf, offset)
      length, offset = read_u32(buf, offset)
      return [ nil, offset ] if length.nil?
      return [ nil, offset ] if buf.bytesize < offset + length

      [ buf[offset, length], offset + length ]
    end

    def self.read_string(buf, offset)
      bytes, offset = read_vec_u8(buf, offset)
      return [ nil, offset ] unless bytes

      [ bytes.force_encoding("UTF-8"), offset ]
    end
  end
end
