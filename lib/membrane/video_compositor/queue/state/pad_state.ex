defmodule Membrane.VideoCompositor.Queue.State.PadState do
  @moduledoc false
  # Responsible for keeping single pad queue state.

  # We assume that the queue receives pts ordered frames on each pad,
  # therefore events in events_queue should be pts ordered.

  alias Membrane.VideoCompositor
  alias Membrane.{RawVideo, Time}

  @enforce_keys [:timestamp_offset, :events_queue, :metadata]
  defstruct @enforce_keys

  @type frame_event :: {:frame, pts :: Time.non_neg_t(), frame_data :: binary()}
  @type end_of_stream_event :: :end_of_stream
  @type stream_format_event :: {:stream_format, RawVideo.t()}

  @type pad_event :: stream_format_event() | frame_event() | end_of_stream_event()

  @type t :: %__MODULE__{
          timestamp_offset: Time.non_neg_t(),
          events_queue: list(pad_event()),
          metadata: VideoCompositor.input_pad_metadata()
        }

  @spec new(VideoCompositor.input_pad_options()) :: t()
  def new(pad_options) do
    %__MODULE__{
      timestamp_offset: pad_options.timestamp_offset,
      events_queue: [],
      metadata: pad_options.metadata
    }
  end

  @spec event_type(pad_event()) :: :stream_format | :frame | :end_of_stream
  def event_type(event) do
    case event do
      {:stream_format, _pad_stream_format} -> :stream_format
      {:frame, _pts, _frame_data} -> :frame
      :end_of_stream -> :end_of_stream
    end
  end
end
