defmodule Membrane.VideoCompositor.RegisteringTransformationTest do
  use ExUnit.Case

  alias Membrane.VideoCompositor.Native.{Adapter, Impl}

  defmodule MockTransformation do
    @behaviour Membrane.VideoCompositor.Transformation

    @impl true
    def initialize(wgpu_ctx) do
      Impl.mock_transformation(wgpu_ctx)
    end

    @impl true
    def encode(transformation) do
      Impl.encode_mock_transformation(transformation)
    end
  end

  test "initializes correctly with a mock transformation" do
    compositor = Adapter.init()
    assert :ok = Adapter.init_and_register_transformations(compositor, [MockTransformation])
  end
end
