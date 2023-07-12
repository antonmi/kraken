defmodule Mix.Tasks.Kraken.Init do
  use Mix.Task
  import Mix.Generator

  @shortdoc "Creates basic folders structure and examples"

  @moduledoc """
  Creates necessary files.
  """

  @lib_folders [
    "lib/kraken",
    "lib/kraken/clients",
    "lib/kraken/helpers",
    "lib/kraken/lambdas",
    "lib/kraken/pipelines",
    "lib/kraken/services"
  ]

  @lib_files [
    {"clients/kv_store.eex", "lib/kraken/clients/kv_store.ex"},
    {"helpers/yes_no_branch.eex", "lib/kraken/helpers/yes_no_branch.ex"},
    {"lambdas/greeter.eex", "lib/kraken/lambdas/greeter.ex"},
    {"pipelines/hello.json.eex", "lib/kraken/pipelines/hello.json"},
    {"services/greeter.json.eex", "lib/kraken/services/greeter.json"},
    {"services/kv-store.json.eex", "lib/kraken/services/kv-store.json"}
  ]

  @test_folders [
    "test/kraken/clients",
    "test/kraken/pipelines",
    "test/kraken/services"
  ]

  @test_files [
    {"clients/kv_store_test.eex", "test/kraken/clients/kv_store_test.exs"},
    {"pipelines/hello_test.eex", "test/kraken/pipelines/hello_test.exs"},
    {"services/greeter_test.eex", "test/kraken/services/greeter_test.exs"},
    {"services/kv_store_test.eex", "test/kraken/services/kv_store_test.exs"}
  ]

  def run(_args) do
    main_module =
      "#{Mix.Project.get!()}"
      |> String.split(".")
      |> Enum.at(1)

    populate_lib(main_module)
    populate_test(main_module)
  end

  defp populate_lib(main_module) do
    create_folder(@lib_folders)
    path = Path.expand("..", __ENV__.file) <> "/init/kraken"
    copy_files(@lib_files, path, main_module)
    File.cp!("#{path}/routes.json", "lib/kraken/routes.json")
  end

  defp populate_test(main_module) do
    create_folder(@test_folders)
    path = Path.expand("..", __ENV__.file) <> "/init/test"
    copy_files(@test_files, path, main_module)
  end

  defp copy_files(files, path, main_module) do
    Enum.map(files, fn {from, to} ->
      content = EEx.eval_file("#{path}/#{from}", main_module: main_module)
      File.write!(to, content)
    end)
  end

  defp create_folder(folders) do
    Enum.map(folders, &create_directory/1)
  end
end
