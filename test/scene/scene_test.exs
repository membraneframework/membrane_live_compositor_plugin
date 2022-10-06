defmodule Membrane.VideoCompositor.Test.Scene.Initialization do
  use ExUnit.Case

  alias Membrane.VideoCompositor.Position
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Test.Support.Scene.Mocks

  describe "Scene transformations" do
    test "by the static initialization" do
      scene_description = [
        videos: %{
          0 => [
            position: %Position{
              x: 0,
              y: 0
            },
            setter: {Mocks.Stateful.Set, 20},
            adder: Mocks.Stateless.Add
          ],
          1 => [
            position: %Position{
              x: 0,
              y: 1080
            }
          ]
        },
        setter: {Mocks.Stateful.Set, 20},
        adder: Mocks.Stateless.Add,
        position: %Position{x: 10, y: 10}
      ]

      manager = %{cached: %{}}

      assert {:ok, {scene, manager}} = Scene.init(scene_description, manager)

      expected_scene_state = %Scene{
        components: [
          setter: Mocks.Stateful.Set,
          adder: Mocks.Stateless.Add
        ],
        scenes: %{},
        state: %{adder: %{count: 0}, setter: 0, position: %Position{x: 10, y: 10}},
        videos: %{
          0 => %Scene.Video{
            components: [
              setter: Mocks.Stateful.Set,
              adder: Mocks.Stateless.Add
            ],
            state: %{
              adder: %{count: 0},
              position: %Position{x: 0, y: 0},
              setter: 0
            }
          },
          1 => %Scene.Video{
            components: [],
            state: %{position: %Position{x: 0, y: 1080}}
          }
        }
      }

      assert scene == expected_scene_state

      expected_manager_state = %{
        cached: %{
          Mocks.Stateful.Set => 20
        }
      }

      assert manager == expected_manager_state
    end
  end
end
