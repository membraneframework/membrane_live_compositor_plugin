defmodule Membrane.VideoCompositor.Test.Scene.Initialization do
  use ExUnit.Case

  alias Membrane.VideoCompositor.Position
  alias Membrane.VideoCompositor.Scene
  alias Membrane.VideoCompositor.Scene.ComponentsManager, as: Manager
  alias Membrane.VideoCompositor.Test.Support.Scene.Mocks

  setup do
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
      position: %Position{x: 10, y: 10},
      size: %{width: 1920, height: 1080}
    ]

    manager = %Manager{}

    %{scene_description: scene_description, manager: manager}
  end

  describe "Scene" do
    test "static initialization", %{scene_description: scene_description, manager: manager} do
      assert {scene, manager} = Scene.init(scene_description, manager)

      expected_scene_state = %Scene{
        components: [
          setter: Mocks.Stateful.Set,
          adder: Mocks.Stateless.Add
        ],
        scenes: %{},
        state: %{
          adder: %{count: 0},
          setter: 0,
          position: %Position{x: 10, y: 10},
          size: %{width: 1920, height: 1080}
        },
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

      expected_manager_state = %Manager{
        cached: %{
          Mocks.Stateful.Set => 20
        }
      }

      assert manager == expected_manager_state
    end

    test "update ok", %{scene_description: scene_description, manager: manager} do
      assert {scene, manager} = Scene.init(scene_description, manager)

      assert scene = Scene.update(scene, manager, 10)

      expected_updated_scene = %Scene{
        components: [
          setter: Mocks.Stateful.Set,
          adder: Mocks.Stateless.Add
        ],
        scenes: %{},
        state: %{
          adder: %{count: 1},
          position: %Position{x: 10, y: 10},
          setter: 20,
          size: %{width: 1920, height: 1080}
        },
        videos: %{
          0 => %Scene.Video{
            components: [
              setter: Mocks.Stateful.Set,
              adder: Mocks.Stateless.Add
            ],
            state: %{
              adder: %{count: 1},
              position: %Position{x: 0, y: 0},
              setter: 20
            }
          },
          1 => %Scene.Video{
            components: [],
            state: %{position: %Position{x: 0, y: 1080}}
          }
        }
      }

      assert scene == expected_updated_scene
    end

    test "update error", %{scene_description: scene_description, manager: manager} do
      assert {scene, manager} = Scene.init(scene_description, manager)

      assert_raise RuntimeError, "Error msg set", fn -> Scene.update(scene, manager, :error) end
    end

    test "update done", %{scene_description: scene_description, manager: manager} do
      assert {scene, manager} = Scene.init(scene_description, manager)

      assert scene = Scene.update(scene, manager, :done)

      expected_done_scene = %Scene{
        components: [],
        scenes: %{},
        state: %{
          adder: %{count: 0},
          position: %Position{x: 10, y: 10},
          setter: 0,
          size: %{width: 1920, height: 1080}
        },
        videos: %{
          0 => %Scene.Video{
            components: [],
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

      assert scene == expected_done_scene
    end
  end
end
