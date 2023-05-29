defmodule Kraken.Utils do
  @moduledoc "Utility functions"

  defdelegate modulize(string), to: Octopus.Utils
  defdelegate module_exist?(module), to: Octopus.Utils
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

  def random_string(bytes \\ 5) do
    bytes
    |> :crypto.strong_rand_bytes()
    |> Base.encode32()
    |> String.downcase()
  end

  def struct_to_map(struct) when is_struct(struct) do
    :maps.map(&convert_key_value/2, Map.from_struct(struct))
  end

  def struct_to_map(list) when is_list(list), do: Enum.map(list, &struct_to_map/1)
  def struct_to_map(data), do: data

  defp convert_key_value(_key, value), do: struct_to_map(value)
end
