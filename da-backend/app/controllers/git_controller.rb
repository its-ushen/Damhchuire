require "zlib"
require "digest"

class GitController < ActionController::API
  DEMO_FILES = { "filey" => "contenty" }

  def info_refs
    hash_map = Git::calculate_git_hashes(DEMO_FILES)
    head_hash = hash_map["HEAD"]

    render plain: "#{head_hash}\trefs/heads/main\r\n"
  end

  def head
    render plain: "ref: refs/heads/main"
  end

  def objects
    hash_map = Git::calculate_git_hashes(DEMO_FILES)
    total_hash = params[:start_hex] + params[:end_hex]

    if !total_hash.in?(hash_map)
      raise "unknown hash"
    end

    send_data Zlib::Deflate.deflate(hash_map[total_hash])
  end
end
