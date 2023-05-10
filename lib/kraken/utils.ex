defmodule Kraken.Utils do
  @moduledoc "Utitilit functions"

  defdelegate modulize(string), to: Octopus.Utils
  defdelegate eval_string(string, args), to: Octopus.Eval

  def eval_code(code) do
    quoted = Code.string_to_quoted!(code)
    {_value, _binding} = Code.eval_quoted(quoted)
    {:ok, code}
  end
end
