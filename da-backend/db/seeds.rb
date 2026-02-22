result = ActionOracle::ActionLibraryInstaller.call

puts "[db:seed] action library created=#{result[:created].join(",")} updated=#{result[:updated].join(",")}"
