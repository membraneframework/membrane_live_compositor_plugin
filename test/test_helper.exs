excluded = [
  long: true,
  opengl_rust: true
]

ExUnit.start(capture_log: true, exclude: excluded)
