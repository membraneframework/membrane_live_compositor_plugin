fn main() {
  println!("cargo:rustc-link-lib=EGL");
  println!("cargo:rustc-link-lib=GLESv2");
  println!("cargo:rustc-link-search=../..");
}
