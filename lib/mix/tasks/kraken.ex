defmodule Mix.Tasks.Kraken do
  use Mix.Task
  alias Kraken.Client

  @shortdoc "Kraken call, cast and stream."

  @moduledoc """
  Manipulates Kraken services.
  """

  def run(args) do
    {:ok, _pid} = Client.start_finch()

    case args do
      ["call", payload] ->
        "/call"
        |> Client.post(payload)
        |> print()

      ["cast", payload] ->
        "/cast"
        |> Client.post(payload)
        |> print()

      ["stream", payload] ->
        "/stream/"
        |> Client.stream(payload, &print/1)

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

defmodule Mix.Tasks.Kraken.Call do
  use Mix.Task

  @shortdoc "Kraken call"

  def run(payload) do
    Mix.Tasks.Kraken.run(["call", payload])
  end
end

defmodule Mix.Tasks.Kraken.Cast do
  use Mix.Task

  @shortdoc "Kraken cast"

  def run(payload) do
    Mix.Tasks.Kraken.run(["call", payload])
  end
end

defmodule Mix.Tasks.Kraken.Stream do
  use Mix.Task

  @shortdoc "Kraken stream"

  def run(payload) do
    Mix.Tasks.Kraken.run(["stream", payload])
  end
end
