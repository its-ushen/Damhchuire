require "digest"
require "json"
require "base64"
require "net/http"
require "uri"

class DaTaskEmitter
  PROGRAM_ID = "NyoBmLiHMDcNRHWrUp2mJei79DCY6mGEj9UdREvoQw1"

  # ed25519 curve parameters
  P = 2**255 - 19
  D = 37095705934669439343138083508754565189542113879843219016388785533085940283555

  def initialize
    @rpc_url     = ENV.fetch("SOLANA_RPC_URL", "http://127.0.0.1:8899")
    keypair_path = ENV.fetch("SOLANA_KEYPAIR_PATH", File.expand_path("~/.config/solana/id.json"))

    keypair = JSON.parse(File.read(keypair_path))
    seed    = keypair[0, 32].pack("C*")

    @signing_key      = Ed25519::SigningKey.new(seed)
    @public_key_bytes = @signing_key.verify_key.to_bytes.bytes
  end

  def emit(data)
    data_bytes = data.bytes

    blockhash        = fetch_blockhash
    config_pda       = derive_config_pda
    instruction_data = build_instruction_data(data_bytes)
    message          = build_message(blockhash, config_pda, instruction_data)

    signature = @signing_key.sign(message.pack("C*"))
    sig_bytes = signature.bytes

    tx_bytes = encode_transaction(sig_bytes, message)
    tx_b64   = Base64.strict_encode64(tx_bytes.pack("C*"))

    rpc_call("sendTransaction", [ tx_b64, { encoding: "base64" } ])
  end

  private

  def fetch_blockhash
    result = rpc_call("getLatestBlockhash", [ { commitment: "finalized" } ])
    result["value"]["blockhash"]
  end

  def rpc_call(method, params = [])
    uri  = URI.parse(@rpc_url)
    http = Net::HTTP.new(uri.host, uri.port)

    request      = Net::HTTP::Post.new(uri.path.empty? ? "/" : uri.path)
    request["Content-Type"] = "application/json"
    request.body = JSON.generate({ jsonrpc: "2.0", id: 1, method: method, params: params })

    response = http.request(request)
    body     = JSON.parse(response.body)

    raise "RPC error: #{body["error"]}" if body["error"]

    body["result"]
  end

  # Base58 → array of 32 bytes (big-endian, zero-padded)
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

  # Iterate bump 255→0, return first SHA256 hash that is NOT on the ed25519 curve
  def derive_config_pda
    program_id_bytes = base58_decode(PROGRAM_ID)
    seed             = "config".bytes

    255.downto(0) do |bump|
      hash_input = seed + [bump] + program_id_bytes + "ProgramDerivedAddress".bytes
      hash       = Digest::SHA256.digest(hash_input.pack("C*")).bytes
      return hash unless on_ed25519_curve?(hash)
    end

    raise "Could not find a valid config PDA"
  end

  # Returns true if the 32-byte array represents a point on the ed25519 curve
  def on_ed25519_curve?(bytes)
    y_bytes     = bytes.dup
    y_bytes[31] &= 0x7f  # clear sign bit

    y = 0
    y_bytes.each_with_index { |b, i| y += b * (256**i) }

    return false if y >= P

    y2 = y.pow(2, P)
    u  = (y2 - 1) % P
    v  = (D * y2 + 1) % P

    return true if u == 0  # y = ±1, x = 0 is valid (identity neighbourhood)

    v_inv = v.pow(P - 2, P)
    x2    = u * v_inv % P

    x = x2.pow((P + 3) / 8, P)

    if x.pow(2, P) != x2
      sqrt_m1 = 2.pow((P - 1) / 4, P)
      x = x * sqrt_m1 % P
      return false if x.pow(2, P) != x2
    end

    true
  end

  # Anchor discriminator (first 8 bytes of SHA256("global:emit_task"))
  # + Borsh-encoded Vec<u8>: u32-LE length prefix + raw bytes
  def build_instruction_data(data_bytes)
    discriminator = Digest::SHA256.digest("global:emit_task").bytes.first(8)
    length_bytes  = [ data_bytes.length ].pack("V").bytes  # 32-bit little-endian
    discriminator + length_bytes + data_bytes
  end

  # Solana legacy transaction message
  #
  # Account order:  [0] authority (writable signer)
  #                 [1] config_pda (writable, not signer)
  #                 [2] program_id (readonly, not signer)
  #
  # Header: [num_required_sigs=1, num_readonly_signed=0, num_readonly_unsigned=1]
  # Instruction account indices: [1, 0]  (config first, authority second – matches Anchor struct)
  def build_message(blockhash, config_pda, instruction_data)
    authority_bytes  = @public_key_bytes
    program_id_bytes = base58_decode(PROGRAM_ID)
    blockhash_bytes  = base58_decode(blockhash)

    header   = [1, 0, 1]
    accounts = authority_bytes + config_pda + program_id_bytes

    instruction =
      [2] +                                  # program_id account index
      compact_u16(2) + [1, 0] +              # 2 account indices: config(1), authority(0)
      compact_u16(instruction_data.length) +
      instruction_data

    header +
      compact_u16(3) + accounts +            # 3 accounts
      blockhash_bytes +                      # recent blockhash
      compact_u16(1) + instruction           # 1 instruction
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
