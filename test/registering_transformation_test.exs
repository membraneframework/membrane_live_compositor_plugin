defmodule Membrane.VideoCompositor.RegisteringTransformationTest do
  use ExUnit.Case

  alias Membrane.VideoCompositor.{Wgpu.Native, WgpuAdapter}

  defmodule MockTransformation do
    @behaviour Membrane.VideoCompositor.Transformation

    @impl true
    def initialize(wgpu_ctx) do
      Native.mock_transformation(wgpu_ctx)
    end

    @impl true
    def encode(transformation) do
      Native.encode_mock_transformation(transformation)
    end
  end

  test "initializes correctly with a mock transformation" do
    compositor = WgpuAdapter.init()
    assert :ok = WgpuAdapter.init_and_register_transformations(compositor, [MockTransformation])
  end
end
