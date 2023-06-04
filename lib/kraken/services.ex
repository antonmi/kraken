defmodule Kraken.Services do
  defdelegate define(definition), to: Octopus

  defdelegate delete(service_name), to: Octopus

  defdelegate status(service_name), to: Octopus

  defdelegate definition(service_name), to: Octopus

  defdelegate services(), to: Octopus

  defdelegate state(service_name), to: Octopus

  defdelegate start(service_name, args), to: Octopus
  def start(service_name), do: start(service_name, %{})

  defdelegate stop(service_name, args), to: Octopus
  def stop(service_name), do: stop(service_name, %{})

  defdelegate call(service_name, function_name, args), to: Octopus
end
