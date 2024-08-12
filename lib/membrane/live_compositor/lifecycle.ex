defmodule Membrane.LiveCompositor.Lifecycle do
  @moduledoc """
  Lifecycle of the input and output streams.

  ### Input pad

  - `t:input_registered/0`
  - `t:input_delivered/0`
  - `t:input_playing/0`
  - `t:input_eos/0`

  ### Output pad

  - `t:output_registered/0`

  ### Notifications

  `t:notification/0` defines notifications that will be sent to the parent process at the specific
  moments of the stream lifecycle.
  """

  alias Membrane.LiveCompositor.Context
  alias Membrane.Pad

  @typedoc """
  The output pad was linked and the TCP connection was established between pipeline and
  the compositor instance.
  """
  @type output_registered :: :output_registered

  @typedoc """
  The input pad was linked and the TCP connection was established between pipeline and
  the compositor instance.
  """
  @type input_registered :: :input_registered

  @typedoc """
  The compositor instance received the input. The first frames/samples of that input are
  ready to be used.

  For example, if you want to ensure that some inputs are ready before you send the
  `:start_composing` notification, you can wait for `t:input_delivered/0` for specific inputs.
  Note that you need to set `composing_strategy:` to something other than `:real_time_auto_init`
  if you want to send `:start_composing` message yourself.
  """
  @type input_delivered :: :input_delivered

  @typedoc """
  The compositor instance received the input, and the first frames/samples of that input are used
  for rendering. This notification can only be sent if compositor was already started either via
  `composing_strategy: :real_time_auto_init` or with `:start_composing` message.

  This notification is usually sent at the same time as `t:input_delivered/0` except for 2 cases:
  - First frames/samples of the input were delivered before composing was started.
  - If input has the `offset` field defined.
  """
  @type input_playing :: :input_playing

  @typedoc """
  Input finished processing. After this notification you can unregister without drooping any
  frames/samples
  """
  @type input_eos :: :input_eos

  @type event ::
          input_registered()
          | input_delivered()
          | input_playing()
          | input_eos()
          | output_registered()

  @type notification :: {
          event(),
          Pad.ref(),
          Context.t()
        }
end
