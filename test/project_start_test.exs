defmodule Kraken.ProjectStartTest do
  use ExUnit.Case

  alias Kraken.ProjectStart
  alias Kraken.{Pipelines, Routes, Services}

  @config [
    kraken_folder: "test/project_start",
    define_services: true,
    start_services: true,
    define_pipelines: true,
    start_pipelines: true,
    define_routes: true
  ]

  setup do
    project_start_before = Application.get_env(:kraken, :project_start)

    on_exit(fn ->
      Application.put_env(:kraken, :project_start, project_start_before)
    end)
  end

  describe "when start is configured" do
    setup do
      Application.put_env(:kraken, :project_start, @config)

      on_exit(fn ->
        Services.delete("greeter")
        Pipelines.delete("hello")
        Routes.delete()
      end)
    end

    def project_start do
      :ok = ProjectStart.run()
    end

    test "hello pipeline" do
      project_start()
      result = Kraken.call(%{"type" => "hello", "name" => "Anton"})
      assert result == %{"message" => "Hello, Anton", "name" => "Anton", "type" => "hello"}
    end
  end

  describe "when no start options" do
    setup do: Routes.delete()

    test "do nothing with nil" do
      Application.put_env(:kraken, :project_start, nil)
      project_start()
      assert {:error, :no_routes} = Kraken.call(%{"type" => "hello", "name" => "Anton"})
    end

    test "do nothing with false" do
      Application.put_env(:kraken, :project_start, false)
      project_start()
      assert {:error, :no_routes} = Kraken.call(%{"type" => "hello", "name" => "Anton"})
    end

    test "do nothing with []" do
      Application.put_env(:kraken, :project_start, [])
      project_start()
      assert {:error, :no_routes} = Kraken.call(%{"type" => "hello", "name" => "Anton"})
    end
  end
end
