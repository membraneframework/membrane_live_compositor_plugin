defmodule Membrane.FFmpeg.VideoFilter.BundlexProject do
  use Bundlex.Project

  def project do
    [
      natives: natives()
    ]
  end

  defp natives() do
    [
      text_overlay: [
        interface: :nif,
        sources: ["text_overlay.c", "filter.c"],
        pkg_configs: ["libavutil", "libavfilter"],
        preprocessor: Unifex
      ]
    ]
  end
end
