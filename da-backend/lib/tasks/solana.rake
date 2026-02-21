# frozen_string_literal: true

namespace :solana do
  desc "Subscribe to Solana program logs and print decoded events"
  task listen: :environment do
    puts "[solana:listen] Starting event listener..."
    puts "[solana:listen] Program: #{Solana::PROGRAM_ID}"
    puts "[solana:listen] WS URL:  #{Solana::WS_URL}"
    puts "[solana:listen] Press Ctrl+C to stop."
    puts

    $stdout.sync = true
    Solana::EventListener.new.start
  end
end
