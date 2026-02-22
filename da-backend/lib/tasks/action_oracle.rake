# frozen_string_literal: true

namespace :action_oracle do
  desc "Install or update the built-in action library"
  task install_library: :environment do
    result = ActionOracle::ActionLibraryInstaller.call

    puts "[action_oracle:install_library] created=#{result[:created].join(",")} updated=#{result[:updated].join(",")}"
  end
end
