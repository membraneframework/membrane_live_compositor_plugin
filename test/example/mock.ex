defmodule Mock do
  @moduledoc false

  defmodule __MODULE__.CornerRounding do
    @moduledoc false

    @behaviour Membrane.VideoCompositor.Texture.Transformation

    @enforce_keys [:pixels, :degrees]
    defstruct @enforce_keys

    @impl true
    def render(), do: :ok
  end

  defmodule __MODULE__.Rotate do
    @moduledoc false

    @behaviour Membrane.VideoCompositor.Canvas.Transformation

    @enforce_keys [:degrees]
    defstruct @enforce_keys

    @impl true
    def render(), do: :ok
  end

  defmodule __MODULE__.Merging do
    @moduledoc false

    @behaviour Membrane.VideoCompositor.Compound.Layout

    @enforce_keys [:videos_num]
    defstruct @enforce_keys

    @impl true
    def render(), do: :ok
  end

  defmodule __MODULE__.Grid do
    @moduledoc false

    @behaviour Membrane.VideoCompositor.Compound.Layout

    @impl true
    def render(), do: :ok
  end

  defmodule __MODULE__.Overlay do
    @moduledoc false

    @behaviour Membrane.VideoCompositor.Compound.Layout

    @impl true
    def render(), do: :ok
  end

  defmodule __MODULE__.ToBall do
    @moduledoc false

    @behaviour Membrane.VideoCompositor.Canvas.Transformation

    @impl true
    def render(), do: :ok
  end
end
