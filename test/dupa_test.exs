alias DupaPipeline

{:ok, _supervisor, _pid} = DupaPipeline.start_link(%{})

:timer.sleep(100_000)
