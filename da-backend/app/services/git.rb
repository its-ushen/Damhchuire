module Git
  def self.calculate_git_hashes(files)
    inner_tree_contents = ""

    hash_map = files.map do |file_name, file_content|
      file_blob = "blob #{file_content.length}\x00#{file_content}"
      file_blob_hash = Digest::SHA1.hexdigest file_blob

      inner_tree_contents += "100644 #{file_name}\x00#{file_blob_hash.scan(/../).map { |x| x.hex.chr }.join}"

      [file_blob_hash, file_blob]
    end.to_h

    tree_contents = "tree #{inner_tree_contents.length}\x00#{inner_tree_contents}"
    tree_hash = Digest::SHA1.hexdigest tree_contents
    hash_map[tree_hash] = tree_contents

    inner_head_content = <<-TEXT
tree #{tree_hash}
author chord <chord@chord.ie> 1777585149 -0400
committer chord <chord@chord.ie> 1777585149 -0400

SDK commit
  TEXT


    head_content = "commit #{inner_head_content.length}\x00#{inner_head_content}"
    head_hash = Digest::SHA1.hexdigest head_content
    hash_map[head_hash] = head_content
    hash_map["HEAD"] = head_hash

    hash_map
  end
end
