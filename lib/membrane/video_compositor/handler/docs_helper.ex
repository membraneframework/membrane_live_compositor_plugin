defmodule Membrane.VideoCompositor.Handler.DocsHelper do
  @moduledoc false

  @doc """
  A function that appends list of fields' descriptions to the moduledoc of a given callback context.
  """
  @spec add_fields_docs(module(), list()) :: :ok
  def add_fields_docs(module, fields) do
    {line, docstring} = Module.get_attribute(module, :moduledoc)

    new_docstring = """
    #{docstring}

    Fields:
    #{"* " <> Enum.join(Enum.sort(fields), "\n* ")}
    """

    Module.put_attribute(module, :moduledoc, {line, new_docstring})
  end
end
