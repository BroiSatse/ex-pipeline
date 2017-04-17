defmodule PipelineTest do
  use ExUnit.Case

  describe "simple pipeline" do
    defmodule Adding do
      def add_two(input) do
        input + 2
      end
    end

    defmodule SimplePipeline do
      use Pipeline
      pipe Adding, :add_two
      pipe :multiply_by_two

      def multiply_by_two(number) do
        {:ok, number * 2}
      end
    end

    test "performs all operations" do
      assert SimplePipeline.pipe_through(2) == {:ok, 8}
    end
  end

  describe "Failing pipeline" do
    defmodule AgentPipeline do
      use Pipeline

      pipe :add, [1]
      pipe :add, [2]
      pipe :fail
      pipe :add, [4]

      def add(agent, number) do
        Agent.update(agent, &(&1 + number))
        {:ok, agent}
      end

      def fail(_agent) do
        {:error, :kaboom!}
      end
    end

    test "It only performs actions until broken pipe" do
      {:ok, agent} = Agent.start fn -> 0 end
      assert AgentPipeline.pipe_through(agent) == {:error, :kaboom!}
      assert Agent.get(agent, &(&1)) == 3
    end
  end

  describe "Connected pipelines" do
    defmodule IntCast do
      use Pipeline

      pipe String, :to_integer
    end

    defmodule MyPipeline do
      use Pipeline
      pipeline IntCast
      pipe __MODULE__, :add, [1]

      def add(input, number) do
        input + number
      end
    end

    test "it executes connected pipelines" do
      assert MyPipeline.pipe_through("2") == {:ok, 3}
      assert MyPipeline.pipe_through("Hello") == {:error, "argument error"}
    end
  end
end
