defmodule Membrane.VideoCompositor.Scene.RustlerFriendly.Layout do
  @moduledoc false
  alias Membrane.VideoCompositor.Scene.Resolution
  alias Membrane.VideoCompositor.Scene.RustlerFriendly.Object

  @type output_resolution :: {:resolution, Resolution.t()} | {:name, Object.name()}

  @type t :: atom()
end
