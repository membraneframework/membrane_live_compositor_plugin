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
        sources: ["video_compositor.c", "filter.c"],
        pkg_configs: ["libavutil", "libavfilter"],
        preprocessor: Unifex,
        src_base: "ffmpeg_video_compositor"
      ]
    ]
  end
end
