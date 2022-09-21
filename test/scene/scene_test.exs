defmodule Membrane.VideoCompositor.Test.Scene.Initialization do
  use ExUnit.Case

  alias Membrane.VideoCompositor.Position
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.Transformation
  alias Membrane.VideoCompositor.Scene.Video

  describe "Scene transformations" do
    test "by the static initialization" do
      _scene = %Scene{
        videos: %{
          0 => %Video{
            position: %Position{
              x: 0,
              y: 0
            }
          },
          1 => %Video{
            position: %Position{
              x: 0,
              y: 1080
            },
            transformations: [
              one: %Transformation{
                module: nil,
                state: %{}
              }
            ]
          }
        },
        components: %{
          counter: 0
        },
        transformations: [
          one: %Transformation{
            module: nil,
            state: %{}
          }
        ]
      }
    end
  end
end
