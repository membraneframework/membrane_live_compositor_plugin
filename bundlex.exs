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
        sources: ["video_compositor.c", "filter.c", "raw_video.c"],
        includes: ["filter.h", "raw_video.h"],
        pkg_configs: ["libavutil", "libavfilter"],
        preprocessor: Unifex,
        src_base: "ffmpeg_video_compositor"
      ],
      opengl_video_compositor: [
        sources: [
          "BasicFBO.cpp",
          "Compositor.cpp",
          "gles2.cpp",
          "opengl_video_compositor.cpp",
          "RectVAO.cpp",
          "Shader.cpp",
          "YUVRenderer.cpp",
          "YUVTexture.cpp"
        ],
        interface: :nif,
        preprocessor: Unifex,
        pkg_configs: [],
        libs: ["EGL", "GLESv2"],
        language: :cpp,
        src_base: "opengl_video_compositor",
        includes: ["c_src/opengl_video_compositor/include"],
        lib_dirs: ["."]
      ]
    ]
  end
end
