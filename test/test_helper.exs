excluded = [
  long_wgpu: true,
  mac: true
]

ExUnit.start(capture_log: true, exclude: excluded)
