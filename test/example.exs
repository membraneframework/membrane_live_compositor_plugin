alias Membrane.VideoCompositor.Pipeline

{:ok, _supervisor, _pid} = Pipeline.start_link(%{})

:timer.sleep(100_000)
