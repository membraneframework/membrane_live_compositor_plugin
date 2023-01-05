defmodule Membrane.VideoCompositor.Scene.Video do
  @moduledoc """
  Properties and transformations of the video.
  """
  alias Membrane.VideoCompositor.Position
  alias Membrane.VideoCompositor.Scene.ComponentsManager, as: Manager
  alias Membrane.VideoCompositor.Scene.Element
  alias Membrane.VideoCompositor.Scene.Video

  @type error_t :: any()
  @type state_t :: %{required(atom) => any()}

  @type t :: %__MODULE__{
          components: Element.components_t(),
          state: state_t()
        }
  defstruct components: %{}, state: %{position: %Position{x: 0, y: 0}}

  @spec init(Element.components_t(), state_t()) :: t()
  def init(components, state \\ %{}) do
    %__MODULE__{
      components: components,
      state: state
    }
  end

  @spec update(t, Manager.t(), context :: any) :: t
  def update(video, manager, context) do
    {state, components} = Manager.update(video.state, video.components, manager, context)
    %Video{video | state: state, components: components}
  end
end
