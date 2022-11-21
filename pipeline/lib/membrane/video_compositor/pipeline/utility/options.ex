defmodule Membrane.VideoCompositor.Pipeline.Utils.Options do
  @moduledoc """
  Options for the testing pipeline.
  """

  @typedoc """
  Specifications of the input video sources
  """
  @type inputs_t :: [InputStream.t()]

  @typedoc """
  Specifications of the sink element or path to the output video file
  """
  @type output_t :: String.t() | Membrane.Sink

  @typedoc """
  Specification of the output video, parameters of the final \"canvas\"
  """
  @type caps_t :: RawVideo.t()

  @typedoc """
  Multiple Frames Compositor
  """
  @type compositor_t :: Membrane.Filter.t()

  @typedoc """
  Decoder for the input buffers. Frames are passed by if `nil` given.
  """
  @type decoder_t :: Membrane.Filter.t() | nil

  @typedoc """
  Encoder for the output buffers. Frames are passed by if `nil` given.
  """
  @type encoder_t :: Membrane.Filter.t() | nil

  @typedoc """
  An additional plugin that sits between the decoder (or source if there is no decoder) and the compositor.
  """
  @type input_filter_t :: Membrane.Filter.t() | nil

  @type t() :: %__MODULE__{
          inputs: inputs_t(),
          output: output_t(),
          caps: caps_t(),
          compositor: compositor_t(),
          decoder: decoder_t(),
          encoder: encoder_t(),
          input_filter: input_filter_t()
        }
  @enforce_keys [:inputs, :output, :caps]
  defstruct [:inputs, :output, :caps, :compositor, :decoder, :encoder, :input_filter]
end
