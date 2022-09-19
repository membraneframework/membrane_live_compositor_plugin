defmodule Membrane.VideoCompositor.Test.Scene.Initialization do
  use ExUnit.Case

  alias Membrane.VideoCompositor.Position
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.Video

  describe "Scene describe initial state of the editor" do
    test "by the static initialization" do
      video_0 = %Video{
        position: %Position{
          x: 0,
          y: 0
        }
      }

      video_1 = %Video{
        position: %Position{
          x: 0,
          y: 1080
        }
      }

      scene = %Scene{
        videos: %{
          0 => video_0,
          1 => video_1
        }
      }

      assert map_size(scene.videos) == 2
    end

    test "by the dynamic initialization" do
      video_0 = %Video{
        position: %Position{
          x: 0,
          y: 0
        }
      }

      video_1 = %Video{
        position: %Position{
          x: 0,
          y: 1080
        }
      }

      scene = %Scene{}

      assert scene = Scene.add_video(scene, 0, video_0)
      assert scene = Scene.add_video(scene, 1, video_1)

      assert map_size(scene.videos) == 2

      # video_0 = %Video{
      #   position: %Position{
      #       x: 0,
      #       y: 1080
      #     },
      #   start_at: 0.0,
      #   components: [
      #     rotate: %Scene.Components.Schedule {
      #       from: 4.0,
      #       to: 5.0,
      #       easing: Scene.Components.Schedule.cubic
      #       comp: %Scene.Components.Rotation{
      #         start_angle: 0,
      #         end_angle: 180.0 / 3.0
      #       }
      #     }
      #   ]
      # }

      # video_1 = %Video{
      #   id: "camera",
      #   position: %Position{
      #     x: 0,
      #     y: 0
      #   },
      #   start_at: 1.0,
      #   components: [
      #     fade_in: %Scene.Components.Schedule{
      #       from: 1.0,
      #       to: 1.5,
      #       comp: %Scene.Components.FadeIn{}
      #     },
      #     fade_out: %Scene.Components.Schedule{
      #       from: 17.0,
      #       to: 17.5,
      #       comp: %Scene.Components.FadeOut{}
      #     }
      #   ]
      # }
    end
  end
end
