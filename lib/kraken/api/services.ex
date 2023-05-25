defmodule Kraken.Api.Services do
  alias Kraken.Services

  def define(payload) do
    with {:ok, definition} <- Jason.decode(payload),
         {:ok, service_name} <-
           (case definition do
              definition when is_map(definition) ->
                Services.define(definition)

              definitions when is_list(definitions) ->
                define_many(definitions)
            end) do
      {:ok, Jason.encode!(%{"ok" => service_name})}
    else
      {:error, error} ->
        {:error, Jason.encode!(%{"error" => inspect(error)})}
    end
  end

  def status(service_name) do
    status = Services.status(service_name)
    {:ok, Jason.encode!(%{"status" => inspect(status)})}
  end

  def call(service_name, function_name, payload) do
    with {:ok, args} <- Jason.decode(payload),
         {:ok, result} <- Services.call(service_name, function_name, args) do
      {:ok, Jason.encode!(%{"ok" => result})}
    else
      {:error, error} ->
        {:error, Jason.encode!(%{"error" => inspect(error)})}
    end
  end

  def start(service_name), do: start(service_name, "{}")
  def start(service_name, ""), do: start(service_name, "{}")

  def start(service_name, payload) do
    with {:ok, args} <- Jason.decode(payload),
         {:ok, state} <- Services.start(service_name, args) do
      {:ok, Jason.encode!(%{"ok" => state})}
    else
      {:error, error} ->
        {:error, Jason.encode!(%{"error" => inspect(error)})}
    end
  end

  def stop(service_name), do: stop(service_name, "{}")
  def stop(service_name, ""), do: stop(service_name, "{}")

  def stop(service_name, payload) do
    with {:ok, args} <- Jason.decode(payload),
         :ok <- Services.stop(service_name, args) do
      {:ok, Jason.encode!(%{"ok" => "ok"})}
    else
      {:error, error} ->
        {:error, Jason.encode!(%{"error" => inspect(error)})}
    end
  end

  def delete(service_name) do
    case Services.delete(service_name) do
      :ok ->
        {:ok, Jason.encode!(%{"ok" => "ok"})}

      {:error, error} ->
        {:error, Jason.encode!(%{"error" => inspect(error)})}
    end
  end

  defp define_many(definitions) do
    try do
      names =
        definitions
        |> Enum.reduce([], fn definition, acc ->
          case Services.define(definition) do
            {:ok, service_name} ->
              [service_name | acc]

            {:error, error} ->
              throw({:error, error})
          end
        end)
        |> Enum.reverse()

      {:ok, names}
    catch
      {:error, error} ->
        {:error, error}
    end
  end
end
