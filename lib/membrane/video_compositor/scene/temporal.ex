defmodule Membrane.VideoCompositor.Scene.Temporal do
  @moduledoc false

  alias Membrane.VideoCompositor.Scene

  @type indefinite :: loop() | indefinite_list()
  @type indefinite_list :: {finite(), Scene.t() | loop()}

  @type finite :: expiring() | repeat() | finite_list()
  @type finite_list :: [expiring() | repeat()]

  @type loop :: {:loop, finite()}

  @type expiring :: {:expiring, {Scene.t(), Membrane.Time.non_neg_t()}}
  @type repeat :: {:repeat, {finite(), non_neg_integer()}}
end
