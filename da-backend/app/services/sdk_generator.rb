module SdkGenerator
  DEFAULT_CARGO_TOML = <<-TEXT
[package]
name = "chord"
version = "0.1.0"
edition = "2024"
  TEXT

  DEFAULT_LIB_RS = <<-TEXT
  pub fn add(left: u64, right: u64) -> u64 {
      left + right + 1
  }
  TEXT

  def self.generate_sdk_from_actions(actions)
    { "Cargo.toml" => DEFAULT_CARGO_TOML, "src/lib.rs" => DEFAULT_LIB_RS }
  end
end
