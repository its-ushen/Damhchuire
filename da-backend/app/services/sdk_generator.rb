module SdkGenerator
  DEFAULT_CARGO_TOML = <<-TEXT
[package]
name = "chord"
version = "0.1.0"
edition = "2024"

[dependencies]
chord_core = { path = "/home/violet/src/Damhchuire/chord_core" }
solana-program = "4.0.0"
TEXT

  ENTRYPOINT = <<-TEXT
  pub use chord_core::check_reentrancy;

  #[macro_export]
  macro_rules! entrypoint {
      ($main:ident) => {

        #[unsafe(no_mangle)]
        pub extern "C" fn entrypoint(input: *mut u8) -> u64 {
            unsafe { $crate::check_reentrancy(); }
            main();
            0
        }
      }
  }

TEXT

  def self.generate_sdk_from_actions(actions)
    functions = actions.each_with_index.map do |a, i|
      url_variables = a.url_template.scan(/{{([a-zA-Z]+)}}/i).flatten
      header_variables = a.headers_template.map { |k, v| v.scan(/{{([a-zA-Z]+)}}/i) }.flatten

      variables = url_variables + header_variables

      args = variables.map { |v| "#{v}: u64" }.join(", ")

      "pub fn #{a.slug}(#{args}) -> u64 { chord_core::rpc_call(); 46 }"
    end.join("\n")

    { "Cargo.toml" => DEFAULT_CARGO_TOML, "src/lib.rs" => functions + "\n" + ENTRYPOINT }
  end
end
