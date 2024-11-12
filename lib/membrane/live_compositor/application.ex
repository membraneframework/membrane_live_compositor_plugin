defmodule Membrane.LiveCompositor.Application do
  @moduledoc false
  use Application

  @impl Application
  def start(_type, _args) do
    Supervisor.start_link(
      [
        {DynamicSupervisor, name: Membrane.LiveCompositor.ServerSupervisor}
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end
end
