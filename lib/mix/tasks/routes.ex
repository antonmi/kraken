defmodule Mix.Tasks.Kraken.Routes do
  use Mix.Task
  alias Kraken.Client

  @shortdoc "Manipulates Kraken routes."

  @moduledoc """
  Manipulates Kraken routes.
  """

  def run(args) do
    {:ok, _pid} = Client.start_finch()

    case args do
      [] ->
        "/routes"
        |> Client.get()
        |> print()

      ["define", payload] ->
        "/routes/define"
        |> Client.post(payload)
        |> print()

      args ->
        IO.puts("Unknown command: #{Enum.join(args, " ")}")
    end
  end

  defp print(json) do
    json
    |> Jason.Formatter.pretty_print()
    |> IO.puts()
  end
end
