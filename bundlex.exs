defmodule Membrane.VideoCompositor.BundlexProject do
  use Bundlex.Project

  def project do
    [
      natives: natives()
    ]
  end

  defp natives() do
    [
      video_compositor: [
        interface: :nif,
        sources: ["video_compositor.c", "filter.c", "raw_video.c", "utility.c", "vstate.c"],
        pkg_configs: ["libavutil", "libavfilter"],
        preprocessor: Unifex,
        src_base: "ffmpeg_video_compositor",
        compiler_flags: ["-g"]
      ]
    ]
  end
end
