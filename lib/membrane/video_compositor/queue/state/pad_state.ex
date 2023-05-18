defmodule Membrane.VideoCompositor.Queue.State.PadState do
  @moduledoc """
  Responsible for keeping single pad queue state.

  We assume that the queue receives pts ordered frames on each pad,
  therefore events in events_queue should be pts ordered.
  """

  alias Membrane.{RawVideo, Time}

  @enforce_keys [:timestamp_offset, :events_queue]
  defstruct @enforce_keys

  @type frame_event :: {:frame, pts :: Time.non_neg_t(), frame_data :: binary()}
  @type pad_added_event :: {:pad_added, pad_options :: map()}
  @type end_of_stream_event :: :end_of_stream
  @type stream_format_event :: {:stream_format, RawVideo.t()}

  @type pad_event ::
          frame_event() | pad_added_event() | end_of_stream_event() | stream_format_event()

  @type t :: %__MODULE__{
          timestamp_offset: Time.non_neg_t(),
          events_queue: list(pad_event())
        }

  @spec new(map()) :: t()
  def new(pad_options = %{timestamp_offset: timestamp_offset}) do
    %__MODULE__{
      timestamp_offset: timestamp_offset,
      events_queue: [{:pad_added, pad_options}]
    }
  end

  @spec event_type(pad_event()) :: :frame | :pad_added | :end_of_stream | :stream_format
  def event_type(event) do
    case event do
      {:frame, _pts, _frame_data} -> :frame
      {:pad_added, _pad_options} -> :pad_added
      :end_of_stream -> :end_of_stream
      {:stream_format, _pad_stream_format} -> :stream_format
    end
  end
end
