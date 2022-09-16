fn main() {
    println!("cargo:rustc-link-lib=EGL");
    println!("cargo:rustc-link-lib=GLESv2");
    #[cfg(target_os = "macos")]
    println!("cargo:rustc-link-search=../..");
}
