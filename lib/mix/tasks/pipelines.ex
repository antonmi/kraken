defmodule Mix.Tasks.Kraken.Pipelines do
  use Mix.Task
  alias Kraken.Client

  @shortdoc "Manipulates Kraken pipelines."

  @moduledoc """
  Manipulates Kraken pipelines.
  """

  def run(args) do
    {:ok, _pid} = Client.start_finch()

    case args do
      [] ->
        "/pipelines"
        |> Client.get()
        |> print()

      ["define", payload] ->
        "/pipelines/define"
        |> Client.post(payload)
        |> print()

      ["status", name] ->
        "/pipelines/status/#{name}"
        |> Client.get()
        |> print()

      ["definition", name] ->
        "/pipelines/definition/#{name}"
        |> Client.get()
        |> print()

      ["start", name] ->
        "/pipelines/start/#{name}"
        |> Client.post("")
        |> print()

      ["stop", name] ->
        "/pipelines/stop/#{name}"
        |> Client.post("")
        |> print()

      ["delete", name] ->
        "/pipelines/delete/#{name}"
        |> Client.post("")
        |> print()

      ["call", name, payload] ->
        "/pipelines/call/#{name}"
        |> Client.post(payload)
        |> print()

      ["cast", name, payload] ->
        "/pipelines/cast/#{name}"
        |> Client.post(payload)
        |> print()

      ["stream", name, payload] ->
        "/pipelines/stream/#{name}"
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
