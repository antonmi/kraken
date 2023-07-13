defmodule Kraken.Client do
  alias Kraken.Configs

  @name Kraken.Client.Finch

  @spec start_finch() :: {:ok, pid()} | {:error, :already_started}
  def start_finch() do
    Application.ensure_started(:telemetry)
    Finch.start_link(name: @name)
  end

  @spec get(String.t()) :: String.t() | no_return()
  def get(path) do
    uri = %URI{
      scheme: "http",
      host: Configs.host(),
      port: Configs.port(),
      path: path
    }

    headers = [{"Content-Type", "application/json"}]

    :get
    |> Finch.build(uri, headers)
    |> Finch.request(@name)
    |> case do
      {:ok, response} ->
        response.body

      {:error, error} ->
        raise error
    end
  end

  @spec post(String.t(), String.t()) :: String.t() | no_return()
  def post(path, payload) do
    uri = %URI{
      scheme: "http",
      host: Configs.host(),
      port: Configs.port(),
      path: path
    }

    headers = [{"Content-Type", "application/json"}]

    :post
    |> Finch.build(uri, headers, payload)
    |> Finch.request(@name)
    |> case do
      {:ok, response} ->
        response.body

      {:error, error} ->
        raise error
    end
  end

  @spec stream(String.t(), String.t(), (String.t() -> :ok)) :: String.t() | no_return()
  def stream(path, payload, function) do
    uri = %URI{
      scheme: "http",
      host: Configs.host(),
      port: Configs.port(),
      path: path
    }

    headers = [{"Content-Type", "application/json"}]

    :post
    |> Finch.build(uri, headers, payload)
    |> Finch.stream(@name, :ok, fn response, _acc ->
      case response do
        {:status, 200} ->
          :ok

        {:headers, _headers} ->
          :ok

        {:data, data} ->
          function.(data)
          :ok
      end
    end)
  end
end
