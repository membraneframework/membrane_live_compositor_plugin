defmodule Mock do
  defmodule __MODULE__.CornerRounding do
    @behaviour Membrane.VideoCompositor.Texture.Transformation

    @enforce_keys [:pixels, :degrees]
    defstruct @enforce_keys

    @impl true
    def render(), do: :ok
  end

  defmodule __MODULE__.Rotate do
    @behaviour Membrane.VideoCompositor.Canvas.Manipulation

    @enforce_keys [:degrees]
    defstruct @enforce_keys

    @impl true
    def render(), do: :ok
  end

  defmodule __MODULE__.Merging do
    @behaviour Membrane.VideoCompositor.Compound.Layout

    @enforce_keys [:videos_num]
    defstruct @enforce_keys

    @impl true
    def render(), do: :ok
  end

  defmodule __MODULE__.Grid do
    @behaviour Membrane.VideoCompositor.Compound.Layout

    @impl true
    def render(), do: :ok
  end

  defmodule __MODULE__.Overlay do
    @behaviour Membrane.VideoCompositor.Compound.Layout

    @impl true
    def render(), do: :ok
  end

  defmodule __MODULE__.ToBall do
    @behaviour Membrane.VideoCompositor.Canvas.Manipulation

    @impl true
    def render(), do: :ok
  end
end
