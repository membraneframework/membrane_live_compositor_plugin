defmodule Membrane.VideoCompositor.Native.Adapter do
  @moduledoc false

  alias Membrane.VideoCompositor.Native.Impl
  alias Membrane.VideoCompositor.Object
  alias Membrane.VideoCompositor.Object.Layout
  alias Membrane.VideoCompositor.Transformation

  @type error() :: any()

  @opaque native_state :: Impl.native_state()

  @doc """
  Initialize the native part of the compositor
  """
  @spec init() :: native_state()
  def init() do
    case Impl.init() do
      {:ok, state} ->
        state

      {:error, reason} ->
        raise "Error while initializing the compositor, reason: #{inspect(reason)}"
    end
  end

  # Gets the wgpu context necessary for initializing transformation modules and layout modules.
  #
  # Safety
  # It's vital that this struct is used according to the safety sections in the docs for the rust
  # mirror of the struct this function returns
  # (`membrane_video_compositor_common::elixir_transfer::StructElixirPacket::<WgpuContext>`)
  @spec wgpu_ctx(native_state()) :: Object.wgpu_ctx()
  defp wgpu_ctx(state) do
    Impl.wgpu_ctx(state)
  end

  @doc """
  This function takes a list of transformation modules, initializes them and registers them in
  the compositor so that they're available to use in the scene.
  """
  @spec init_and_register_transformations(
          native_state(),
          list(Transformation.transformation_module())
        ) :: :ok
  def init_and_register_transformations(state, transformations) do
    transformations
    |> Enum.each(fn transformation_module ->
      wgpu_ctx = wgpu_ctx(state)
      initialized = transformation_module.initialize(wgpu_ctx)

      case Impl.register_transformation(state, initialized) do
        :ok -> :ok
        {:error, reason} -> raise "Error when registering a transformation: #{inspect(reason)}"
      end
    end)
  end

  @doc """
  This function takes a list of layout modules, initializes them and registers them in
  the compositor so that they're available to use in the scene.
  """
  @spec init_and_register_layouts(
          native_state(),
          list(Layout.layout_module())
        ) :: :ok
  def init_and_register_layouts(state, layouts) do
    layouts
    |> Enum.each(fn layout_module ->
      wgpu_ctx = wgpu_ctx(state)
      initialized = layout_module.initialize(wgpu_ctx)

      case Impl.register_layout(state, initialized) do
        :ok -> :ok
        {:error, reason} -> raise "Error when registering layout: #{inspect(reason)}"
      end
    end)
  end
end
