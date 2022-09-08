excluded = [
  long: true,
  opengl: true,
  opengl_cpp: true,
  opengl_rust: true
]

ExUnit.start(capture_log: true, exclude: excluded)
