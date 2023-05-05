defmodule Kraken.Define.Stage do
  alias Kraken.Utils

  def define(definition, pipeline_module) do
    stage_module =
      "#{pipeline_module}.#{definition["name"]}"
      |> Utils.modulize()
      |> String.to_atom()
    download = Map.get(definition, "download", false)
    upload = Map.get(definition, "upload", false)
    service_name = get_in(definition, ["service", "name"]) || raise "Missing service name!"
    service_function = get_in(definition, ["service", "function"]) || raise "Missing service function!"

    template()
    |> EEx.eval_string(
      stage_module: stage_module,
      service_name: service_name,
      service_function: service_function,
      download: download,
      upload: upload,
      helpers: [] # TODO helper_modules(definition.helpers)
    )
    |> Utils.eval_code()
    |> case do
      {:ok, _code} ->
         {:ok, stage_module}
    end
  end

  defp template() do
    """
      defmodule <%= stage_module %> do
        @download "<%= Base.encode64(:erlang.term_to_binary(download)) %>"
                  |> Base.decode64!()
                  |> :erlang.binary_to_term()

        @upload "<%= Base.encode64(:erlang.term_to_binary(upload)) %>"
                |> Base.decode64!()
                |> :erlang.binary_to_term()

        @helpers "<%= Base.encode64(:erlang.term_to_binary(helpers)) %>"
                 |> Base.decode64!()
                 |> :erlang.binary_to_term()

        def call(event, _opts) when is_map(event) do
          %Kraken.Define.Stage.Call{
            event: event,
            service_name: "<%= service_name %>",
            service_function: "<%= service_function %>",
            download: @download,
            upload: @upload,
            helpers: @helpers
          }
          |> Kraken.Define.Stage.Call.call()
          |> case do
            {:ok, result} ->
              result
            {:error, error} ->
              raise inspect(error)
          end
        end

        def call(_event, _opts) do
          raise "Event must be a map"
        end
      end
    """
  end

  defmodule Call do
    @moduledoc false

    defstruct event: nil,
              service_name: nil,
              service_function: nil,
              download: false,
              upload: false,
              helpers: []

    alias Octopus.Transform

    @spec call(%__MODULE__{}) :: {:ok, map()} | {:error, any()}
    def call(%__MODULE__{
      event: event,
      service_name: service_name,
      service_function: service_function,
      download: download,
      upload: upload,
      helpers: helpers
    }) do
      with {:ok, args} <-
             Transform.transform(event, download, helpers),
           {:ok, args} <-
             Octopus.call(service_name, service_function, args),
           {:ok, event} <-
             Transform.transform(args, upload, helpers)
        do
        {:ok, event}
      else
        {:error, error} -> {:error, error}
      end
    end
  end
end