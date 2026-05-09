require "zlib"
require "digest"

class GitController < ActionController::API
  _file_contents = "hey hi:)"
  FILE_CONTENTS = "blob #{_file_contents.length}\x00#{_file_contents}"
  FILE_HASH = Digest::SHA1.hexdigest FILE_CONTENTS\

  _tree_contents = "100644 filey\x00#{FILE_HASH.scan(/../).map { |x| x.hex.chr }.join}"
  TREE_CONTENTS = "tree #{_tree_contents.length}\x00#{_tree_contents}"
  TREE_HASH = Digest::SHA1.hexdigest TREE_CONTENTS

  _HEAD_CONTENT = <<-TEXT
tree #{TREE_HASH}
author chord <chord@chord.ie> 1777585149 -0400
committer chord <chord@chord.ie> 1777585149 -0400

Hey hi!
TEXT

  HEAD_CONTENT = "commit #{_HEAD_CONTENT.length}\x00#{_HEAD_CONTENT}"

  HEAD_HASH = Digest::SHA1.hexdigest HEAD_CONTENT

  def info_refs
    render plain: "#{HEAD_HASH}\trefs/heads/main\r\n"
  end

  def head
    render plain: "ref: refs/heads/main"
  end

  def objects
    Rails.logger.info(HEAD_HASH)
    Rails.logger.info(TREE_HASH)
    Rails.logger.info(FILE_HASH)

    case params[:start_hex]
    when HEAD_HASH[0..1]
      contents = HEAD_CONTENT
    when TREE_HASH[0..1]
      contents = TREE_CONTENTS
    when FILE_HASH[0..1]
      contents = FILE_CONTENTS
    else
      raise "unknown hash"
    end

    send_data Zlib::Deflate.deflate(contents)
  end
end
