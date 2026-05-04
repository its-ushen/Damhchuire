fn main() {
    cc::Build::new().file("asm/asm.s").compile("asm");
    println!("cargo::rerun-if-changed=asm/asm.s");
}
