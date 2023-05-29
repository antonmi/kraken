defmodule Kraken.Api.Pipelines do
  alias Kraken.Pipelines
  alias Kraken.Utils

  def define(payload) do
    with {:ok, definition} <- Jason.decode(payload),
         {:ok, pipeline_name} <- Pipelines.define(definition) do
      {:ok, Jason.encode!(%{"ok" => pipeline_name})}
    else
      {:error, error} ->
        {:error, Jason.encode!(%{"error" => inspect(error)})}
    end
  end

  def status(pipeline_name) do
    status = Pipelines.status(pipeline_name)
    {:ok, Jason.encode!(%{"status" => inspect(status)})}
  end

  def definition(pipeline_name) do
    case Pipelines.definition(pipeline_name) do
      {:ok, definition} ->
        {:ok, Jason.encode!(definition)}

      {:error, error} ->
        {:error, Jason.encode!(%{"error" => inspect(error)})}
    end
  end

  def call(params, payload) do
    pipeline_name = params["name"]

    with {:ok, args} <- Jason.decode(payload),
         result when is_map(result) or is_list(result) <-
           Pipelines.call(pipeline_name, args, params) do
      {:ok, Jason.encode!(Utils.struct_to_map(result))}
    else
      {:error, error} ->
        {:error, Jason.encode!(%{"error" => inspect(error)})}
    end
  end

  def cast(params, payload) do
    pipeline_name = params["name"]

    with {:ok, args} <- Jason.decode(payload),
         result when is_reference(result) or is_list(result) <-
           Pipelines.cast(pipeline_name, args, params) do
      {:ok, Jason.encode!(%{"ok" => result})}
    else
      {:error, error} ->
        {:error, Jason.encode!(%{"error" => inspect(error)})}
    end
  end

  def stream(params, payload) do
    pipeline_name = params["name"]

    with {:ok, args} <- Jason.decode(payload),
         stream when is_function(stream) <-
           Pipelines.stream(pipeline_name, args, params) do
      {:ok, stream}
    else
      {:error, error} ->
        {:error, Jason.encode!(%{"error" => inspect(error)})}
    end
  end

  def start(params, payload) do
    service_name = params["name"]
    payload = if payload == "", do: Jason.encode!(params), else: payload

    with {:ok, args} <- Jason.decode(payload),
         {:ok, module} <- Pipelines.start(service_name, args) do
      {:ok, Jason.encode!(%{"ok" => module})}
    else
      {:error, error} ->
        {:error, Jason.encode!(%{"error" => inspect(error)})}
    end
  end

  def stop(service_name) do
    case Pipelines.stop(service_name) do
      :ok ->
        {:ok, Jason.encode!(%{"ok" => "ok"})}

      {:error, error} ->
        {:error, Jason.encode!(%{"error" => inspect(error)})}
    end
  end

  def delete(service_name) do
    case Pipelines.delete(service_name) do
      :ok ->
        {:ok, Jason.encode!(%{"ok" => "ok"})}

      {:error, error} ->
        {:error, Jason.encode!(%{"error" => inspect(error)})}
    end
  end
end
