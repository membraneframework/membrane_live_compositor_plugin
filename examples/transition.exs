alias Membrane.VideoCompositor.Examples.Transition.Pipeline

{:ok, _supervisor, _pid} = Pipeline.start_link(%{})

:timer.sleep(100_000)
