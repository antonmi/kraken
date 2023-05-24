defmodule Kraken.Define.DecomposerAndRecomposerTest do
  use ExUnit.Case
  import Kraken.TestHelpers
  alias Kraken.Define.{Decomposer, Recomposer}
  alias Kraken.Define.Pipeline

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
      "events" => [%{"string" => "Hello"}]
    }

    {:ok, result} = Octopus.call("decompose-recompose", "recompose", args)
    assert result == %{"event" => nil, "stored" => [%{"string" => "Hello"}, %{"string" => "!"}]}

    args = %{
      "event" => %{"string" => "!!!"},
      "events" => [%{"string" => "Hello"}, %{"string" => "World"}]
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
      decomposer_module = Kraken.Pipelines.PipelineWithDecomposer.Decomposer
      {:ok, ^decomposer_module} = Decomposer.define(@decomposer, decomposer_module)

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
      recomposer_module = Kraken.Pipelines.PipelineWithRecomposer.Recomposer
      {:ok, ^recomposer_module} = Recomposer.define(@recomposer, recomposer_module)

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

  describe "with helpers both in pipeline and in de-recomposer" do
    @pipeline_with_de_and_recomposer_and_helpers %{
      "name" => "PipelineWithDeAndRecomposerAndHelpers",
      "helpers" => ["Helpers.GetHelper"],
      "components" => [
        %{
          "type" => "decomposer",
          "name" => "decomposer",
          "download" => %{
            "string" => "fetch(args, 'input')"
          },
          "service" => %{
            "name" => "decompose-recompose",
            "function" => "decompose"
          },
          "decompose" => %{
            "events" => "args['new-events']",
            "event" => "get(args, 'current-event')"
          },
          "helpers" => ["Helpers.FetchHelper"]
        },
        %{
          "type" => "stage",
          "name" => "convert-string-back-to-input",
          "upload" => %{
            "input" => "args['string']"
          }
        },
        %{
          "type" => "recomposer",
          "name" => "recomposer",
          "download" => %{
            "string" => "fetch(args, 'input')"
          },
          "service" => %{
            "name" => "decompose-recompose",
            "function" => "recompose"
          },
          "recompose" => %{
            "event" => "get(args, 'event')",
            "events" => "args['stored']"
          },
          "helpers" => ["Helpers.FetchHelper"]
        }
      ]
    }

    test "define and call PipelineWithDeAndRecomposer" do
      Pipeline.define(@pipeline_with_de_and_recomposer_and_helpers)
      apply(Kraken.Pipelines.PipelineWithDeAndRecomposerAndHelpers, :start, [])

      assert is_nil(
               apply(Kraken.Pipelines.PipelineWithDeAndRecomposerAndHelpers, :call, [
                 %{"input" => "aaa bbb"}
               ])
             )

      result =
        apply(Kraken.Pipelines.PipelineWithDeAndRecomposerAndHelpers, :call, [%{"input" => "ccc"}])

      assert result == %{"string" => "aaa bbb ! ccc"}
    end
  end
end
