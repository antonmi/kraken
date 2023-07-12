defmodule Kraken.ProjectStart do
  alias Kraken.{Pipelines, Routes, Services}

  @default_config [
    kraken_folder: "lib/kraken",
    define_services: true,
    start_services: true,
    define_pipelines: true,
    start_pipelines: true,
    define_routes: true
  ]

  def run() do
    case Application.get_env(:kraken, :project_start) do
      nil ->
        :ok

      false ->
        :ok

      [] ->
        :ok

      true ->
        do_run(@default_config)
        :ok

      configs when is_list(configs) ->
        do_run(configs)
        :ok
    end
  end

  defp do_run(configs) do
    define_and_start_services(
      Keyword.get(configs, :kraken_folder, false),
      Keyword.get(configs, :define_services, false),
      Keyword.get(configs, :start_services, false)
    )

    define_and_start_pipelines(
      Keyword.get(configs, :kraken_folder, false),
      Keyword.get(configs, :define_pipelines, false),
      Keyword.get(configs, :start_pipelines, false)
    )

    define_routes(
      Keyword.get(configs, :kraken_folder, false),
      Keyword.get(configs, :define_routes, false)
    )
  end

  defp define_and_start_services(folder, true, start?) do
    (Path.relative_to_cwd(folder) <> "/services/*.json")
    |> Path.wildcard()
    |> Enum.map(fn file ->
      with {:ok, name} <- Services.define(File.read!(file)),
           true <- start?,
           {:ok, _state} <- Services.start(name) do
        :ok
      else
        false -> :ok
        {:error, error} -> raise error
      end
    end)
  end

  defp define_and_start_services(_folder, false, _start?), do: :ok

  defp define_and_start_pipelines(folder, true, start?) do
    (Path.relative_to_cwd(folder) <> "/pipelines/*.json")
    |> Path.wildcard()
    |> Enum.map(fn file ->
      with {:ok, name} <- Pipelines.define(File.read!(file)),
           true <- start?,
           {:ok, _state} <- Pipelines.start(name) do
        :ok
      else
        false -> :ok
        {:error, error} -> raise error
      end
    end)
  end

  defp define_and_start_pipelines(_folder, false, _start?), do: :ok

  defp define_routes(folder, true) do
    file = Path.relative_to_cwd(folder) <> "/routes.json"

    with {:ok, content} <- File.read(file),
         {:ok, Kraken.RoutingTable} <- Routes.define(content) do
      :ok
    else
      {:error, :enoent} ->
        {:error, :enoent}

      {:error, error} ->
        raise error
    end
  end

  defp define_routes(_folder, false), do: :ok
end
