defmodule AggregateRootRegistryTest do
  use ExUnit.Case
  require AggregateRootExample.Events
  alias Neuryt.AggregateRoot

  defmodule MemStore do
    @behaviour Neuryt.EventStore

    require AggregateRootExample.Events
    alias AggregateRootExample.Events
    alias Neuryt.Event

    def save_event(_event, _stream_id), do: :ok
    def save_events(_events, _stream_id), do: :ok
    def load_all_events(), do: {:ok, []}
    def count_all_events(), do: {:ok, 0}
    def load_stream_events(stream_id) do
      {:ok, [
        Events.c(ItemAdded, stream_id, :a),
        Events.c(ItemAdded, stream_id, :b),
        Events.c(ItemRemoved, stream_id, :b),
      ]
      |> Enum.map(& %Event{event: &1})}
    end
    def count_stream_events(stream_id),
      do: {:ok, load_stream_events(stream_id) |> elem(1) |> length}
    def list_streams(), do: {:ok, []}
  end

  @agg_id 123
  @agg_id2 567

  setup do
    Application.put_env :neuryt, :event_store, AggregateRootRegistryTest.MemStore

    on_exit fn ->
      clean_up_after AggregateRootExample, @agg_id
      clean_up_after AggregateRootExample, @agg_id2
    end
  end

  test "creates new AR when none is present" do
    assert AggregateRoot.Registry.loaded_aggregates_count == 0
    {:ok, _ref, pid} = AggregateRoot.Registry.open AggregateRootExample, @agg_id
    assert is_pid(pid) == true
    assert Process.alive?(pid) == true
    assert AggregateRoot.Registry.loaded_aggregates_count == 1
  end

  test "loaded AR autoterminates on idle timeout" do
    {:ok, ref, _pid} = AggregateRoot.Registry.open AggregateRootExample, @agg_id, idle_timeout: 50
    assert AggregateRoot.Registry.loaded_aggregates_count == 1
    AggregateRoot.Registry.release ref
    Process.sleep 60
    assert AggregateRoot.Registry.loaded_aggregates_count == 0
  end

  test "loaded AR is returned on `open/2`" do
    {:ok, ref, pid} = AggregateRoot.Registry.open AggregateRootExample, @agg_id
    AggregateRoot.Registry.release ref
    assert {:ok, _ref, ^pid} = AggregateRoot.Registry.open AggregateRootExample, @agg_id
  end

  test "creating AR also creates :jobs queue for that AR" do
    assert AggregateRoot.Registry.loaded_aggregates_count == 0
    assert count_ar_queues == 0

    {:ok, _ref, _pid} = AggregateRoot.Registry.open AggregateRootExample, @agg_id

    assert AggregateRoot.Registry.loaded_aggregates_count == 1
    assert count_ar_queues == 1
  end

  test "loading AR, loads events stream from event store and hydrates the state" do
    {:ok, _ref, pid} = AggregateRoot.Registry.open AggregateRootExample, @agg_id
    assert GenServer.call(pid, :get_aggregate_state) ==
      %AggregateRootExample{items: [:a], id: @agg_id, version: 3}
  end

  test "only one client can have access to AR at a time, rest of clients are blocked until lock is released" do
    {:ok, ref, pid} = AggregateRoot.Registry.open AggregateRootExample, @agg_id

    master = self
    spawn fn ->
      {:ok, _ref, pid} = AggregateRoot.Registry.open AggregateRootExample, @agg_id
      send master, {:got_ar, pid}
    end
    res = receive do
      {:got_ar, _} -> flunk "AR loading didn't block"
    after 100 ->
        :ok
    end
    assert :ok = res

    AggregateRoot.Registry.release ref   # release the lock
    assert_receive {:got_ar, ^pid}, 300
  end

  test "lock is automatically released when client dies" do
    master = self
    pid1 = spawn fn ->
      {:ok, _ref, _pid} = AggregateRoot.Registry.open AggregateRootExample, @agg_id
      send master, {:got_ar1, self}
      receive do
        _ -> send master, {:dying, self}
      end
    end
    assert_receive {:got_ar1, ^pid1}

    pid2 = spawn fn ->
      {:ok, _ref, _pid} = AggregateRoot.Registry.open AggregateRootExample, @agg_id
      send master, {:got_ar2, self}
    end

    send pid1, :time_to_die
    assert_receive {:dying, ^pid1}
    refute Process.alive?(pid1)
    assert_receive {:got_ar2, ^pid2}
    Process.exit pid1, :kill
    Process.exit pid2, :kill
  end

  test "lock is automatically released when client is killed" do
    master = self
    pid1 = spawn fn ->
      {:ok, _ref, _pid} = AggregateRoot.Registry.open AggregateRootExample, @agg_id
      send master, {:got_ar1, self}
      receive do
        _ -> send master, {:dying, self}
      end
    end
    assert_receive {:got_ar1, ^pid1}

    pid2 = spawn fn ->
      {:ok, _ref, _pid} = AggregateRoot.Registry.open AggregateRootExample, @agg_id
      send master, {:got_ar2, self}
    end

    Process.exit pid1, :kill
    refute Process.alive?(pid1)
    assert_receive {:got_ar2, ^pid2}
  end

  test "different AR can be opened at the same time" do
    {:ok, _ref1, pid1} = AggregateRoot.Registry.open AggregateRootExample, @agg_id
    {:ok, _ref2, pid2} = AggregateRoot.Registry.open AggregateRootExample, @agg_id2
    assert Process.alive?(pid1)
    assert Process.alive?(pid2)
    assert pid1 != pid2
  end

  defp clean_up_after(aggregate, agg_id) do
    try do
      GenServer.stop AggregateRoot.Server.get_pid(aggregate, agg_id)
    catch _, _ -> :ok
    end
    :jobs.delete_queue {:ar_queue, aggregate, agg_id}
  end

  defp count_ar_queues do
    :jobs.info(:queues)
    |> Enum.filter(fn x ->
      match? {:queue, [{:name, {:ar_queue, _, _}} | _]}, x
    end)
    |> length
  end
end
