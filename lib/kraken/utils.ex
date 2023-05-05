defmodule Kraken.Utils do
  alias Octopus.Utils

  defdelegate modulize(string), to: Utils

  def eval_code(code) do
    quoted = Code.string_to_quoted!(code)
    {_value, _binding} = Code.eval_quoted(quoted)
    {:ok, code}
  end
end
