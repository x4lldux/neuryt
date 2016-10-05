defmodule AggregateRootRegistryTest do
  use ExUnit.Case
  require AggregateRootExample.Events
  alias Neuryt.Event
  alias Neuryt.AggregateRoot

  setup do
    on_exit fn ->
      try do
        GenServer.stop AggregateRootExample
      catch _, _ -> :ok
      end
      # IO.puts "on_exit #{:jobs.delete_queue {:ar_queue, AggregateRootExample}}"
      :jobs.delete_queue {:ar_queue, AggregateRootExample}
    end
  end

  test "creates new AR when none is present" do
    assert AggregateRoot.Registry.loaded_aggregates_count == 0
    {:ok, pid} = AggregateRoot.Registry.load AggregateRootExample
    assert is_pid(pid) == true
    assert Process.alive?(pid) == true
    assert AggregateRoot.Registry.loaded_aggregates_count == 1

  end

  test "loaded AR autoterminates on idle timeout" do
    {:ok, pid} = AggregateRoot.Registry.load AggregateRootExample, idle_timeout: 100
    assert AggregateRoot.Registry.loaded_aggregates_count == 1
    Process.sleep 100
    assert AggregateRoot.Registry.loaded_aggregates_count == 0
  end

  test "loaded AR is returned on `load/2`" do
    {:ok, pid} = AggregateRoot.Registry.load AggregateRootExample
    assert {:ok, ^pid} = AggregateRoot.Registry.load AggregateRootExample
  end

  test "creating AR also creates :jobs queue for that AR" do
    assert AggregateRoot.Registry.loaded_aggregates_count == 0
    assert count_ar_queues == 0

    {:ok, pid} = AggregateRoot.Registry.load AggregateRootExample

    assert AggregateRoot.Registry.loaded_aggregates_count == 1
    assert count_ar_queues == 1
  end

  test "loading AR, loads events stream from event store and hydrates the state"


  defp count_ar_queues do
    :jobs.info(:queues)
    |> Enum.filter(fn x ->
      match? {:queue, [{:name, {:ar_queue, _}} | _]}, x
    end)
    |> length
  end
end
