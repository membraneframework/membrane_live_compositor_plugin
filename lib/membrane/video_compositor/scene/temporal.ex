defmodule Membrane.VideoCompositor.Scene.Temporal do
  @moduledoc false

  alias Membrane.VideoCompositor.Scene

  @type finite :: expiring() | repeat() | finite_list()
  @type indefinite :: loop() | indefinite_list()

  @type finite_list :: [expiring() | repeat()]
  @type indefinite_list :: {finite(), Scene.t() | loop()}

  @type expiring :: {:expiring, {Scene.t(), Membrane.Time.non_neg_t()}}
  @type loop :: {:loop, finite()}
  @type repeat :: {:repeat, {finite(), non_neg_integer()}}
end
