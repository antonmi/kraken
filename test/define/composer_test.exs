defmodule Kraken.Define.ComposerTest do
  use ExUnit.Case
  import Kraken.TestHelpers
  alias Kraken.Define.Composer
  alias Kraken.Define.Pipeline

  setup do
    define_and_start_service("telegram")

    on_exit(fn ->
      Octopus.delete("telegram")
    end)
  end

  test "telegram service" do
    {:ok, result} = Octopus.call("telegram", "test", %{"x" => 1, "y" => 2})
    assert result == %{"numbers" => [%{"n" => 1}, %{"n" => 2}], "store" => 3}

    {:ok, result} = Octopus.call("telegram", "decompose", %{"string" => "Hello World"})
    assert result == %{"events" => [%{"string" => "Hello"}, %{"string" => "World"}]}

    {:ok, result} =
      Octopus.call("telegram", "recompose", %{"string" => "John", "memo" => "Hello"})

    assert result == %{"events" => ["Hello John"], "memo" => ""}

    {:ok, result} =
      Octopus.call("telegram", "recompose", %{"string" => "!!!", "memo" => "Hello John"})

    assert result == %{"events" => ["Hello John"], "memo" => "!!!"}

    {:ok, result} = Octopus.call("telegram", "recompose", %{"string" => "man", "memo" => "Hello"})
    assert result == %{"events" => [], "memo" => "Hello man"}
  end

  describe "composer component" do
    @test_composer %{
      "type" => "composer",
      "name" => "test",
      "memo" => 1,
      "prepare" => %{
        "x" => "memo",
        "y" => "args['input']"
      },
      "service" => %{
        "name" => "telegram",
        "function" => "test"
      },
      "compose" => %{
        "events" => "args['numbers']",
        "memo" => "args['store']"
      }
    }

    test "define and call decomposer" do
      module = Kraken.Pipelines.PipelineWithTestComposer.Composer
      {:ok, ^module} = Composer.define(@test_composer, module)

      result = apply(module, :call, [%{"input" => 2}, 1, %{}])
      assert result == {[%{"n" => 1}, %{"n" => 2}], 3}
    end

    @pipeline_with_test_composer %{
      "name" => "PipelineWithTestComposer",
      "components" => [@test_composer]
    }

    test "define and call PipelineWithTestComposer" do
      Pipeline.define(@pipeline_with_test_composer)
      apply(Kraken.Pipelines.PipelineWithTestComposer, :start, [])

      events =
        apply(Kraken.Pipelines.PipelineWithTestComposer, :call, [%{"input" => 2}])

      assert events == [%{"n" => 1}, %{"n" => 2}]

      events =
        apply(Kraken.Pipelines.PipelineWithTestComposer, :call, [%{"input" => 2}])

      assert events == [%{"n" => 3}, %{"n" => 2}]
    end
  end

  describe "decomposer" do
    @decomposer %{
      "type" => "composer",
      "name" => "decomposer",
      "service" => %{
        "name" => "telegram",
        "function" => "decompose"
      },
      "compose" => %{
        "events" => "args['events']"
      }
    }

    @pipeline_with_decomposer %{
      "name" => "PipelineWithDecomposer",
      "components" => [@decomposer]
    }

    test "define and call PipelineWithTestComposer" do
      Pipeline.define(@pipeline_with_decomposer)
      apply(Kraken.Pipelines.PipelineWithDecomposer, :start, [])

      events =
        apply(Kraken.Pipelines.PipelineWithDecomposer, :call, [%{"string" => "Hello World"}])

      assert events == [%{"string" => "Hello"}, %{"string" => "World"}]
    end
  end

  describe "recomposer" do
    @recomposer %{
      "type" => "composer",
      "name" => "recomposer",
      "memo" => "",
      "service" => %{
        "name" => "telegram",
        "function" => "recompose"
      },
      "prepare" => %{
        "string" => "args['string']",
        "memo" => "memo"
      },
      "compose" => %{
        "events" => "args['events']",
        "memo" => "args['memo']"
      }
    }

    @pipeline_with_recomposer %{
      "name" => "PipelineWithRecomposer",
      "components" => [@recomposer]
    }

    test "define and call PipelineWithTestComposer" do
      Pipeline.define(@pipeline_with_recomposer)
      apply(Kraken.Pipelines.PipelineWithRecomposer, :start, [])

      result = apply(Kraken.Pipelines.PipelineWithRecomposer, :call, [%{"string" => "Hello"}])
      assert is_nil(result)

      result = apply(Kraken.Pipelines.PipelineWithRecomposer, :call, [%{"string" => "John"}])
      assert result == "Hello John"

      result = apply(Kraken.Pipelines.PipelineWithRecomposer, :call, [%{"string" => "and"}])
      assert is_nil(result)

      result = apply(Kraken.Pipelines.PipelineWithRecomposer, :call, [%{"string" => "others"}])
      assert result == "and others"
    end
  end

  describe "telegram problem" do
    @telegram_pipeline %{
      "name" => "TelegramPipeline",
      "components" => [@decomposer, @recomposer]
    }

    test "it works" do
      Pipeline.define(@telegram_pipeline)
      apply(Kraken.Pipelines.TelegramPipeline, :start, [])

      result =
        apply(Kraken.Pipelines.TelegramPipeline, :call, [%{"string" => "Hello John and others"}])

      assert result == ["Hello John", "and others"]
    end
  end
end
