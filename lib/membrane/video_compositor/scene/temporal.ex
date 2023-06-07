defmodule Membrane.VideoCompositor.Scene.Temporal do
  @moduledoc """
  This module contains types of Temporal Scene API.


  ## Examples

  ### Active Speaker
  examples:
  offline'owy przypadek: policz kto kiedy jest aktywnym speakerem,

  ###
  rotacja widzów jako w live, pętla
  """

  alias Membrane.VideoCompositor.Scene

  @type t() :: expiring() | repeat() | sequence()

  @type sequence :: [expiring() | repeat() | Scene.t()]

  @type expiring :: {:expiring, {Scene.t(), Membrane.Time.non_neg_t()}}
  @type repeat :: {:repeat, {sequence(), pos_integer() | :infinity}}
end
