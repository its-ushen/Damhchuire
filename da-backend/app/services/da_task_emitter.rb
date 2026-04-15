require "base64"
require "digest"
require "json"
require "net/http"
require "uri"
require "ed25519"

class DaTaskEmitter
  DEFAULT_BLOCKHASH_COMMITMENT = "confirmed"
  DEFAULT_PREFLIGHT_COMMITMENT = "confirmed"
  DEFAULT_MAX_SEND_ATTEMPTS = 4
  DEFAULT_RETRY_SLEEP_SECONDS = 0.4

  RETRYABLE_RPC_MARKERS = [
    "ProgramAccountNotFound",
    "AccountNotInitialized"
  ].freeze

  # ed25519 curve parameters
  P = 2**255 - 19
  D = 37095705934669439343138083508754565189542113879843219016388785533085940283555

  def initialize
    @program_id = Solana::PROGRAM_ID
    @rpc_url = ENV.fetch("SOLANA_RPC_URL", "http://127.0.0.1:8899")
    @keypair_path = ENV.fetch("SOLANA_KEYPAIR_PATH", File.expand_path("~/.config/solana/id.json"))
    @blockhash_commitment = ENV.fetch("SOLANA_BLOCKHASH_COMMITMENT", DEFAULT_BLOCKHASH_COMMITMENT)
    @preflight_commitment = ENV.fetch("SOLANA_PREFLIGHT_COMMITMENT", DEFAULT_PREFLIGHT_COMMITMENT)
    @max_send_attempts = ENV.fetch("SOLANA_SEND_MAX_ATTEMPTS", DEFAULT_MAX_SEND_ATTEMPTS.to_s).to_i.clamp(1, 12)
    @retry_sleep_seconds = ENV.fetch("SOLANA_SEND_RETRY_SLEEP_SECONDS", DEFAULT_RETRY_SLEEP_SECONDS.to_s).to_f

    keypair = JSON.parse(File.read(@keypair_path))
    seed = keypair[0, 32].pack("C*")

    @signing_key = Ed25519::SigningKey.new(seed)
    @public_key_bytes = @signing_key.verify_key.to_bytes.bytes
  end

  def callback(request_id:, ok:, result_json:)
    payload = result_json.is_a?(String) ? result_json : JSON.generate(result_json)

    send_with_retry do
      instruction_data = build_callback_instruction_data(request_id.to_i, !!ok, payload.bytes)
      send_callback_instruction(
        instruction_data: instruction_data,
        request_id: request_id.to_i
      )
    end
  end

  private

  def send_with_retry
    attempts = 0

    begin
      attempts += 1
      yield
    rescue => e
      raise unless retryable_rpc_error?(e)
      raise if attempts >= @max_send_attempts

      sleep(@retry_sleep_seconds * attempts)
      retry
    end
  end

  def retryable_rpc_error?(error)
    message = error.message.to_s
    RETRYABLE_RPC_MARKERS.any? { |marker| message.include?(marker) }
  end

  # Build and send a callback transaction matching the invoice_processor's CallbackCtx:
  #   [0] config    – PDA seeds ["config"], readonly
  #   [1] oracle_authority – signer / fee payer / writable
  #   [2] invoice   – PDA seeds ["invoice", request_id_le_bytes], writable
  #   [3] program_id
  def send_callback_instruction(instruction_data:, request_id:)
    program_id_bytes = base58_decode(@program_id)
    blockhash = fetch_blockhash
    config_pda = derive_pda(["config".bytes], program_id_bytes)
    invoice_pda = derive_pda(["invoice".bytes, [request_id].pack("Q<").bytes], program_id_bytes)

    message = build_callback_message(
      blockhash: blockhash,
      config_pda: config_pda,
      invoice_pda: invoice_pda,
      instruction_data: instruction_data,
      program_id_bytes: program_id_bytes
    )

    signature = @signing_key.sign(message.pack("C*"))
    tx_bytes = encode_transaction(signature.bytes, message)
    tx_b64 = Base64.strict_encode64(tx_bytes.pack("C*"))

    send_transaction(tx_b64)
  end

  # Solana transaction message for callback.
  #
  # Account meta ordering (sorted by signer/writable as Solana requires):
  #   [0] oracle_authority – signer + writable (fee payer)
  #   [1] invoice          – writable (not signer)
  #   [2] config           – readonly (not signer, not writable)
  #   [3] program_id       – readonly (not signer, not writable, executable)
  #
  # Header: [num_required_signatures, num_readonly_signed, num_readonly_unsigned]
  #   1 signer (oracle_authority)
  #   0 readonly signed
  #   2 readonly unsigned (config + program_id)
  #
  # Instruction account indices map to Anchor struct order (CallbackCtx):
  #   config=2, oracle_authority=0, invoice=1
  def build_callback_message(blockhash:, config_pda:, invoice_pda:, instruction_data:, program_id_bytes:)
    authority_bytes = @public_key_bytes
    blockhash_bytes = base58_decode(blockhash)

    # Header: 1 signer, 0 readonly-signed, 2 readonly-unsigned (config + program)
    header = [1, 0, 2]

    # Accounts in Solana wire order: signers+writable first, then writable, then readonly
    accounts = authority_bytes + invoice_pda + config_pda + program_id_bytes

    # Instruction: program is at index 3, accounts in Anchor struct order
    instruction =
      [3] +                                         # program_id index
      compact_u16(3) + [2, 0, 1] +                  # 3 accounts: config=2, oracle_authority=0, invoice=1
      compact_u16(instruction_data.length) +
      instruction_data

    header +
      compact_u16(4) + accounts +
      blockhash_bytes +
      compact_u16(1) + instruction
  end

  def fetch_blockhash
    result = rpc_call("getLatestBlockhash", [ { commitment: @blockhash_commitment } ])
    result.fetch("value").fetch("blockhash")
  end

  def send_transaction(tx_b64)
    opts = {
      encoding: "base64",
      preflightCommitment: @preflight_commitment,
      maxRetries: 3
    }

    rpc_call("sendTransaction", [ tx_b64, opts ])
  end

  def rpc_call(method, params = [])
    uri = URI.parse(@rpc_url)
    http = Net::HTTP.new(uri.host, uri.port)

    request = Net::HTTP::Post.new(uri.path.empty? ? "/" : uri.path)
    request["Content-Type"] = "application/json"
    request.body = JSON.generate({ jsonrpc: "2.0", id: 1, method: method, params: params })

    response = http.request(request)
    body = JSON.parse(response.body)

    raise "RPC error: #{body["error"]}" if body["error"]

    body["result"]
  end

  # Base58 -> array of 32 bytes (big-endian, zero-padded)
  def base58_decode(str)
    alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    n = 0
    str.each_char { |c| n = n * 58 + alphabet.index(c) }

    bytes = []
    while n > 0
      bytes.unshift(n & 0xff)
      n >>= 8
    end

    bytes.unshift(0) while bytes.length < 32
    bytes
  end

  # Derive a PDA given an array of seed byte-arrays and the program_id bytes.
  # Iterates bump 255->0, returns first SHA256 hash NOT on the ed25519 curve.
  def derive_pda(seeds, program_id_bytes)
    255.downto(0) do |bump|
      hash_input = seeds.flatten + [bump] + program_id_bytes + "ProgramDerivedAddress".bytes
      hash = Digest::SHA256.digest(hash_input.pack("C*")).bytes
      return hash unless on_ed25519_curve?(hash)
    end

    raise "Could not find a valid PDA"
  end

  # Returns true if the 32-byte array represents a point on the ed25519 curve.
  def on_ed25519_curve?(bytes)
    y_bytes = bytes.dup
    y_bytes[31] &= 0x7f # clear sign bit

    y = 0
    y_bytes.each_with_index { |b, i| y += b * (256**i) }

    return false if y >= P

    y2 = y.pow(2, P)
    u = (y2 - 1) % P
    v = (D * y2 + 1) % P

    return true if u == 0

    v_inv = v.pow(P - 2, P)
    x2 = u * v_inv % P

    x = x2.pow((P + 3) / 8, P)

    if x.pow(2, P) != x2
      sqrt_m1 = 2.pow((P - 1) / 4, P)
      x = x * sqrt_m1 % P
      return false if x.pow(2, P) != x2
    end

    true
  end

  # Anchor discriminator: SHA256("global:callback")[0..8)
  # + u64 request_id + bool ok + Borsh Vec<u8>(result_json)
  def build_callback_instruction_data(request_id, ok, result_bytes)
    discriminator = Digest::SHA256.digest("global:callback").bytes.first(8)
    request_id_bytes = [request_id].pack("Q<").bytes
    ok_byte = [ok ? 1 : 0]
    result_len = [result_bytes.length].pack("V").bytes

    discriminator + request_id_bytes + ok_byte + result_len + result_bytes
  end

  # Solana compact-u16 encoding
  def compact_u16(n)
    if n <= 0x7f
      [n]
    elsif n <= 0x3fff
      [(n & 0x7f) | 0x80, n >> 7]
    else
      [(n & 0x7f) | 0x80, ((n >> 7) & 0x7f) | 0x80, n >> 14]
    end
  end

  # Wire format: compact_u16(1) + 64-byte signature + message bytes
  def encode_transaction(sig_bytes, message)
    compact_u16(1) + sig_bytes + message
  end
end
