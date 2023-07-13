defmodule Mix.Tasks.Kraken.Services do
  use Mix.Task
  alias Kraken.Client

  @shortdoc "Manipulates Kraken services."

  @moduledoc """
  Manipulates Kraken services.
  """

  def run(args) do
    {:ok, _pid} = Client.start_finch()

    case args do
      [] ->
        "/services"
        |> Client.get()
        |> print()

      ["define", payload] ->
        "/services/define"
        |> Client.post(payload)
        |> print()

      ["status", name] ->
        "/services/status/#{name}"
        |> Client.get()
        |> print()

      ["state", name] ->
        "/services/state/#{name}"
        |> Client.get()
        |> print()

      ["definition", name] ->
        "/services/definition/#{name}"
        |> Client.get()
        |> print()

      ["start", name] ->
        "/services/start/#{name}"
        |> Client.post("")
        |> print()

      ["start", name, payload] ->
        "/services/start/#{name}"
        |> Client.post(payload)
        |> print()

      ["stop", name] ->
        "/services/stop/#{name}"
        |> Client.post("")
        |> print()

      ["stop", name, payload] ->
        "/services/stop/#{name}"
        |> Client.post(payload)
        |> print()

      ["delete", name] ->
        "/services/delete/#{name}"
        |> Client.post("")
        |> print()

      ["call", service, function, payload] ->
        "/services/call/#{service}/#{function}"
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
