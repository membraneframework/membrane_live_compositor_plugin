alias Membrane.VideoCompositor.ExamplePipeline

{:ok, _supervisor, _pid} = ExamplePipeline.start_link(%{})

:timer.sleep(100_000)
