defmodule Kraken.Utils do
  @moduledoc "Utility functions"

  defdelegate modulize(string), to: Octopus.Utils
  defdelegate eval_string(string, args), to: Octopus.Eval

  def eval_code(code) do
    quoted = Code.string_to_quoted!(code)
    {_value, _binding} = Code.eval_quoted(quoted)
    {:ok, code}
  end

  def helper_modules(definition) when is_map(definition) do
    definition
    |> Map.get("helpers", [])
    |> Enum.map(&:"Elixir.#{&1}")
  end
end
