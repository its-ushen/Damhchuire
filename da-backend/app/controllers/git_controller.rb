require "zlib"
require "digest"

class GitController < ActionController::API
  def info_refs
    files = SdkGenerator::generate_sdk_from_actions(Action.all)
    hash_map = Git::calculate_git_hashes(files)
    head_hash = hash_map["HEAD"]

    render plain: "#{head_hash}\trefs/heads/main\n"
  end

  def head
    render plain: "ref: refs/heads/main\n"
  end

  def objects
    files = SdkGenerator::generate_sdk_from_actions(Action.all)
    hash_map = Git::calculate_git_hashes(files)
    total_hash = params[:start_hex] + params[:end_hex]

    if !total_hash.in?(hash_map)
      raise "unknown hash"
    end

    send_data Zlib::Deflate.deflate(hash_map[total_hash])
  end
end
