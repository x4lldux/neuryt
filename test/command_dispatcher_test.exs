defmodule CommandDispatcherTest do
  use ExUnit.Case

  require AggregateRootExample.Commands
  require AggregateRootExample.Events
  require AggregateRootExample.Errors
  alias AggregateRootExample.{Errors, Commands, Events}
  alias Neuryt.{AggregateRoot, Event, EventBus, UUID}

  setup do
    Application.put_env :neuryt, :event_store, MemStoreExample
    MemStoreExample.start_link

    %{
      agg_id: UUID.new,
      item: :rand.uniform,
      item2: :rand.uniform,
    }
  end

  test "command handling can result in :ok",
    %{agg_id: agg_id, item: item} do

    assert :ok = CommandRouterExample.dispatch Commands.c(AddItem, agg_id, item)
  end

  test "command handling can result in {:error, reason}",
    %{agg_id: agg_id, item: item} do

    assert :ok =
      CommandRouterExample.dispatch Commands.c(AddItem, agg_id, item)
    assert {:error, Errors.c(ItemAllreadyPresent)} =
      CommandRouterExample.dispatch Commands.c(AddItem, agg_id, item)
  end

  test "handled command changes AR sate",
    %{agg_id: agg_id, item: item, item2: item2} do

    assert :ok =
      CommandRouterExample.dispatch Commands.c(AddItem, agg_id, item)
    ar_pid = AggregateRoot.Registry.get_aggregate_root_pid(
      AggregateRootExample, agg_id)

    assert %AggregateRootExample{items: [^item]} =
      AggregateRoot.Server.get_aggregate_state(ar_pid)
    assert :ok = CommandRouterExample.dispatch Commands.c(AddItem, agg_id, item2)
    assert %AggregateRootExample{items: [^item2, ^item]} =
      AggregateRoot.Server.get_aggregate_state(ar_pid)
  end

  test "handled command publishes events", %{agg_id: agg_id, item: item} do
    EventBus.subscribe Events
    assert :ok =
      CommandRouterExample.dispatch Commands.c(AddItem, agg_id, item)
    assert_receive %Event{event: Events.c(ItemAdded, ^agg_id, ^item)}
  end

  test "handled command saves events to event store",
    %{agg_id: agg_id, item: item, item2: item2} do
    assert :ok =
      CommandRouterExample.dispatch Commands.c(AddItem, agg_id, item)

    assert {:ok, [ %Event{event: Events.c(ItemAdded, ^agg_id, ^item)} ]}
    = MemStoreExample.load_stream_events(agg_id)

    assert :ok = CommandRouterExample.dispatch Commands.c(AddItem, agg_id, item2)

    assert {:ok, [ %Event{event: Events.c(ItemAdded, ^agg_id, ^item2)},
                   %Event{event: Events.c(ItemAdded, ^agg_id, ^item)}]}
    = MemStoreExample.load_all_events()
  end
end
