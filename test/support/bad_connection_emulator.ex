defmodule Membrane.VideoCompositor.Test.Support.BadConnectionEmulator do
  @moduledoc """
  An element emulating a bad connection.
  Tt allows to introduce artificial packet loss and simple delays in transmissions.
  """

  use Membrane.Filter

  alias Membrane.RawVideo

  @typedoc """
  Has to be between 0 and 1.
  """
  @type probability_t :: float()

  def_options packet_loss: [
                spec: probability_t(),
                description: """
                Simulated packet loss.
                """,
                default: 0.05
              ],
              delay_interval: [
                spec: {float(), float()},
                description: """
                The delay will be randomized with uniform probability from this interval.
                This value is in seconds.
                """
              ],
              delay_chance: [
                spec: probability_t(),
                description: """
                The chance the delay will happen. This chance will be rolled after checking
                whether the packet will be dropped.
                """,
                default: 0.05
              ]

  def_input_pad :input,
    demand_unit: :buffers,
    demand_mode: :auto,
    caps: RawVideo

  def_output_pad :output,
    demand_unit: :buffers,
    demand_mode: :auto,
    caps: RawVideo

  @impl true
  def handle_init(%{
        packet_loss: packet_loss,
        delay_chance: delay_chance,
        delay_interval: delay_interval
      }) do
    if packet_loss > 1.0 or packet_loss < 0.0 do
      raise "Packet loss has to be between 0 and 1"
    end

    if delay_chance > 1.0 or delay_chance < 0.0 do
      raise "Delay chance has to be between 0 and 1"
    end

    {a, b} = delay_interval

    if a > b do
      raise "End of the delay interval has to be greater than the start"
    end

    state = %{
      packet_loss: packet_loss,
      delay_chance: delay_chance,
      delay_interval: delay_interval
    }

    {:ok, state}
  end

  @impl true
  def handle_caps(_pad, caps, _ctx, state) do
    {{:ok, caps: {:output, caps}}, state}
  end

  @impl true
  def handle_process(_pad, buffer, _ctx, state) do
    if :rand.uniform() <= state.packet_loss do
      {:ok, state}
    else
      if :rand.uniform() <= state.delay_chance do
        Process.sleep(calculate_sleep_time(state.delay_interval))
      end

      {{:ok, buffer: {:output, buffer}}, state}
    end
  end

  defp calculate_sleep_time({smol, big}) do
    diff = big - smol
    time = smol + :rand.uniform() * diff
    floor(time * 1000)
  end

  @impl true
  def handle_end_of_stream(_pad, _ctx, state) do
    {{:ok, end_of_stream: :output}, state}
  end
end
