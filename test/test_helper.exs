excluded = [
  long: true,
  opengl: true,
  wgpu: true
]

ExUnit.start(capture_log: true, exclude: excluded)
