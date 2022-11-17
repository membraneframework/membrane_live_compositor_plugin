excluded = [
  long_wgpu: true,
  wgpu: true
]

ExUnit.start(capture_log: true, exclude: excluded)
