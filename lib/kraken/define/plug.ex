defmodule Kraken.Define.Plug do
  alias Kraken.Utils

  def define(definition, pipeline_module, pipeline_helpers \\ []) do
    plug_module =
      "#{pipeline_module}.#{definition["name"]}"
      |> Utils.modulize()
      |> String.to_atom()

    download = Map.get(definition, "download", false)
    upload = Map.get(definition, "upload", false)
    helpers = Utils.helper_modules(definition) ++ pipeline_helpers

    template()
    |> EEx.eval_string(
      plug_module: plug_module,
      download: download,
      upload: upload,
      helpers: helpers
    )
    |> Utils.eval_code()
    |> case do
      {:ok, _code} ->
        {:ok, plug_module}
    end
  end

  defp template() do
    """
      defmodule <%= plug_module %> do
        @download "<%= Base.encode64(:erlang.term_to_binary(download)) %>"
                  |> Base.decode64!()
                  |> :erlang.binary_to_term()

        @upload "<%= Base.encode64(:erlang.term_to_binary(upload)) %>"
                |> Base.decode64!()
                |> :erlang.binary_to_term()

        @helpers "<%= Base.encode64(:erlang.term_to_binary(helpers)) %>"
                 |> Base.decode64!()
                 |> :erlang.binary_to_term()

        def plug(event, _) when is_map(event) do
          %Kraken.Define.Plug.Call{
            event: event,
            download: @download,
            helpers: @helpers
          }
          |> Kraken.Define.Plug.Call.plug()
          |> case do
            {:ok, result} ->
              result
            {:error, error} ->
              raise inspect(error)
          end
        end

        def plug(_event, _opts), do: raise "Event must be a map"

        def unplug(event, prev_event, _) when is_map(event) and is_map(prev_event) do
          %Kraken.Define.Plug.Call{
            event: event,
            prev_event: prev_event,
            upload: @upload,
            helpers: @helpers
          }
          |> Kraken.Define.Plug.Call.unplug()
          |> case do
            {:ok, result} ->
              result
            {:error, error} ->
              raise inspect(error)
          end
        end

        def unplug(_event, _prev_event, _opts), do: raise "Event must be a map"
      end
    """
  end

  defmodule Call do
    @moduledoc false

    defstruct event: nil,
              prev_event: nil,
              download: false,
              upload: false,
              helpers: []

    alias Octopus.Transform

    @spec plug(%__MODULE__{}) :: {:ok, map()} | {:error, any()}
    def plug(%__MODULE__{
          event: event,
          download: download,
          helpers: helpers
        }) do
      case Transform.transform(event, download, helpers) do
        {:ok, event} ->
          {:ok, event}

        {:error, error} ->
          {:error, error}
      end
    end

    @spec unplug(%__MODULE__{}) :: {:ok, map()} | {:error, any()}
    def unplug(%__MODULE__{
          event: event,
          prev_event: prev_event,
          upload: upload,
          helpers: helpers
        }) do
      case Transform.transform(event, upload, helpers) do
        {:ok, args} ->
          event = upload_to_event(prev_event, args, upload)
          {:ok, event}

        {:error, error} ->
          {:error, error}
      end
    end

    defp upload_to_event(event, _args, false), do: event

    defp upload_to_event(event, args, upload) when is_map(upload) do
      Map.merge(event, args)
    end
  end
end
