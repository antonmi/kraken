defmodule Kraken.Define.DecomposerAndRecomposerTest do
  use ExUnit.Case

  alias Kraken.Test.Definitions
  alias Kraken.Define.{Decomposer, Recomposer}
  alias Kraken.Define.Pipeline

  def define_and_start_service(name) do
    {:ok, ^name} =
      "services/#{name}.json"
      |> Definitions.read_and_decode()
      |> Octopus.define()

    {:ok, _code} = Octopus.start(name)
  end

  setup do
    define_and_start_service("decompose-recompose")

    on_exit(fn ->
      Octopus.stop("decompose-recompose")
      Octopus.delete("decompose-recompose")
    end)
  end

  test "decompose-recompose service, decompose function" do
    {:ok, result} = Octopus.call("decompose-recompose", "decompose", %{"string" => "Hello World"})
    assert result["current-event"] == %{"string" => "!"}
    assert result["new-events"] == [%{"string" => "Hello"}, %{"string" => "World"}]
  end

  test "decompose-recompose service, recompose function" do
    args = %{
      "event" => %{"string" => "!"},
      "stored" => [%{"string" => "Hello"}]
    }

    {:ok, result} = Octopus.call("decompose-recompose", "recompose", args)
    assert result == %{"event" => nil, "stored" => [%{"string" => "Hello"}, %{"string" => "!"}]}

    args = %{
      "event" => %{"string" => "!!!"},
      "stored" => [%{"string" => "Hello"}, %{"string" => "World"}]
    }

    {:ok, result} = Octopus.call("decompose-recompose", "recompose", args)

    assert result == %{"event" => %{"string" => "Hello World !!!"}, "stored" => []}
  end

  describe "decomposer component" do
    @decomposer %{
      "type" => "decomposer",
      "name" => "decomposer",
      "download" => %{
        "string" => "args['input']"
      },
      "service" => %{
        "name" => "decompose-recompose",
        "function" => "decompose"
      },
      "decompose" => %{
        "events" => "args['new-events']",
        "event" => "args['current-event']"
      }
    }

    test "define and call decomposer" do
      {:ok, decomposer_module} =
        Decomposer.define(@decomposer, Kraken.Pipelines.PipelineWithDecomposer)

      assert decomposer_module == Kraken.Pipelines.PipelineWithDecomposer.Decomposer

      {events, event} = apply(decomposer_module, :call, [%{"input" => "Hello world"}, %{}])
      assert events == [%{"string" => "Hello"}, %{"string" => "world"}]
      assert event == %{"string" => "!"}
    end

    @pipeline_with_decomposer %{
      "name" => "PipelineWithDecomposer",
      "components" => [@decomposer]
    }

    test "define and call PipelineWithDecomposer" do
      Pipeline.define(@pipeline_with_decomposer)
      apply(Kraken.Pipelines.PipelineWithDecomposer, :start, [])

      events =
        apply(Kraken.Pipelines.PipelineWithDecomposer, :call, [%{"input" => "Hello world"}])

      assert events == [%{"string" => "world"}, %{"string" => "Hello"}, %{"string" => "!"}]
    end
  end

  describe "recomposer component" do
    @recomposer %{
      "type" => "recomposer",
      "name" => "recomposer",
      "download" => %{
        "string" => "args['input']"
      },
      "service" => %{
        "name" => "decompose-recompose",
        "function" => "recompose"
      },
      "recompose" => %{
        "event" => "args['event']",
        "events" => "args['stored']"
      }
    }

    test "define and call decomposer" do
      {:ok, recomposer_module} =
        Recomposer.define(@recomposer, Kraken.Pipelines.PipelineWithRecomposer)

      assert recomposer_module == Kraken.Pipelines.PipelineWithRecomposer.Recomposer

      result =
        apply(recomposer_module, :call, [%{"input" => "!!!"}, [%{"string" => "Hello"}], %{}])

      assert result == {nil, [%{"string" => "Hello"}, %{"string" => "!!!"}]}

      result =
        apply(recomposer_module, :call, [
          %{"input" => "!!!"},
          [%{"string" => "Hello"}, %{"string" => "World"}],
          %{}
        ])

      assert result == {%{"string" => "Hello World !!!"}, []}
    end

    @pipeline_with_recomposer %{
      "name" => "PipelineWithRecomposer",
      "components" => [@recomposer]
    }

    test "define and call PipelineWithRecomposer" do
      Pipeline.define(@pipeline_with_recomposer)
      apply(Kraken.Pipelines.PipelineWithRecomposer, :start, [])

      assert is_nil(
               apply(Kraken.Pipelines.PipelineWithRecomposer, :call, [%{"input" => "Hello"}])
             )

      result = apply(Kraken.Pipelines.PipelineWithRecomposer, :call, [%{"input" => "World!!!"}])
      assert result == %{"string" => "Hello World!!!"}
    end
  end

  describe "pipeline with decomposer and recomposer" do
    @pipeline_with_de_and_recomposer %{
      "name" => "PipelineWithDeAndRecomposer",
      "components" => [
        @decomposer,
        %{
          "type" => "stage",
          "name" => "convert-string-back-to-input",
          "upload" => %{
            "input" => "args['string']"
          }
        },
        @recomposer
      ]
    }

    test "define and call PipelineWithDeAndRecomposer" do
      Pipeline.define(@pipeline_with_de_and_recomposer)
      apply(Kraken.Pipelines.PipelineWithDeAndRecomposer, :start, [])

      assert is_nil(
               apply(Kraken.Pipelines.PipelineWithDeAndRecomposer, :call, [
                 %{"input" => "aaa bbb"}
               ])
             )

      result = apply(Kraken.Pipelines.PipelineWithDeAndRecomposer, :call, [%{"input" => "ccc"}])
      assert result == %{"string" => "aaa bbb ! ccc"}
    end
  end
end
