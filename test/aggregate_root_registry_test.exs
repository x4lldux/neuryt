defmodule AggregateRootRegistryTest do
  use ExUnit.Case
  require AggregateRootExample.Events
  alias Neuryt.AggregateRoot

  defmodule MemStore do
    @behaviour Neuryt.EventStore
    @agg_id 123

    require AggregateRootExample.Events
    alias AggregateRootExample.Events
    alias Neuryt.Event

    def save_event(_event, _stream_id), do: :ok
    def save_events(_events, _stream_id), do: :ok
    def load_all_events(), do: {:ok, []}
    def count_all_events(), do: {:ok, 0}
    def load_stream_events(@agg_id) do
      [
        Events.c(ItemAdded, :a),
        Events.c(ItemAdded, :b),
        Events.c(ItemRemoved, :b),
      ]
      |> Enum.map(& %Event{event: &1})
    end
    def count_stream_events(stream_id=@agg_id),
      do: {:ok, load_stream_events(stream_id) |> elem(1) |> length}
    def list_streams(), do: {:ok, []}
  end

  @agg_id 123

  setup do
    Application.put_env :neuryt, :event_store, AggregateRootRegistryTest.MemStore

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
    {:ok, pid} = AggregateRoot.Registry.load AggregateRootExample, @agg_id
    assert is_pid(pid) == true
    assert Process.alive?(pid) == true
    assert AggregateRoot.Registry.loaded_aggregates_count == 1

  end

  test "loaded AR autoterminates on idle timeout" do
    {:ok, _pid} = AggregateRoot.Registry.load AggregateRootExample, @agg_id, idle_timeout: 100
    assert AggregateRoot.Registry.loaded_aggregates_count == 1
    Process.sleep 100
    assert AggregateRoot.Registry.loaded_aggregates_count == 0
  end

  test "loaded AR is returned on `load/2`" do
    {:ok, pid} = AggregateRoot.Registry.load AggregateRootExample, @agg_id
    assert {:ok, ^pid} = AggregateRoot.Registry.load AggregateRootExample, @agg_id
  end

  test "creating AR also creates :jobs queue for that AR" do
    assert AggregateRoot.Registry.loaded_aggregates_count == 0
    assert count_ar_queues == 0

    {:ok, _pid} = AggregateRoot.Registry.load AggregateRootExample, @agg_id

    assert AggregateRoot.Registry.loaded_aggregates_count == 1
    assert count_ar_queues == 1
  end

  test "loading AR, loads events stream from event store and hydrates the state" do
    {:ok, pid} = AggregateRoot.Registry.load AggregateRootExample, @agg_id
    assert GenServer.call(pid, :get_aggregate_state) ==
      %AggregateRootExample{items: [:a], id: @agg_id, version: 3}
  end


  defp count_ar_queues do
    :jobs.info(:queues)
    |> Enum.filter(fn x ->
      match? {:queue, [{:name, {:ar_queue, _}} | _]}, x
    end)
    |> length
  end
end
