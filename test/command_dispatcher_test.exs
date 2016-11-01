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
      item3: :rand.uniform,
    }
  end

  test "command handling can result in :ok",
    %{agg_id: agg_id, item: item} do

    assert {:ok, ^agg_id} = CommandRouterExample.dispatch Commands.c(AddItem, agg_id, item)
  end

  test "command handling can result in {:error, reason}",
    %{agg_id: agg_id, item: item} do

    assert {:ok, ^agg_id} =
      CommandRouterExample.dispatch Commands.c(AddItem, agg_id, item)
    assert {:error, Errors.c(ItemAllreadyPresent)} =
      CommandRouterExample.dispatch Commands.c(AddItem, agg_id, item)
  end

  test "handled command changes AR sate",
    %{agg_id: agg_id, item: item, item2: item2} do

    assert {:ok, ^agg_id} =
      CommandRouterExample.dispatch Commands.c(AddItem, agg_id, item)
    ar_pid = AggregateRoot.Registry.get_aggregate_root_pid(
      AggregateRootExample, agg_id)

    assert %AggregateRootExample{items: [^item]} =
      AggregateRoot.Server.get_aggregate_state(ar_pid)
    assert {:ok, ^agg_id} = CommandRouterExample.dispatch Commands.c(AddItem, agg_id, item2)
    assert %AggregateRootExample{items: [^item2, ^item]} =
      AggregateRoot.Server.get_aggregate_state(ar_pid)
  end

  test "handled command publishes events", %{agg_id: agg_id, item: item, item2: item2} do
    EventBus.subscribe Events
    assert {:ok, ^agg_id} =
      CommandRouterExample.dispatch Commands.c(AddItem, agg_id, item)
    assert_receive %Event{event: Events.c(ItemAdded, ^agg_id, ^item)}

    assert {:ok, ^agg_id} =
      CommandRouterExample.dispatch Commands.c(AddItem, agg_id, item2),
      service_data: "service data"
    assert_receive %Event{event: Events.c(ItemAdded, ^agg_id, ^item2),
                          service_data: "service data"}
  end

  test "dispatching command in reaction an event saves it's `process_id` and set's it's id as `predecessor_id`",
    %{agg_id: agg_id, item: item} do
    EventBus.subscribe Events
    starting_event = Event.new Events.c(ItemsCleared, agg_id)

    assert {:ok, ^agg_id} =
      CommandRouterExample.dispatch Commands.c(AddItem, agg_id, item),
      reaction_to: starting_event
    event =  assert_receive %Event{event: Events.c(ItemAdded, ^agg_id, ^item)}
    assert event.predecessor_id ==  starting_event.id
    assert event.process_id ==  starting_event.process_id
  end

  test "handled command saves events to event store",
    %{agg_id: agg_id, item: item, item2: item2} do
    assert {:ok, ^agg_id} =
      CommandRouterExample.dispatch Commands.c(AddItem, agg_id, item)

    assert {:ok, [ %Event{event: Events.c(ItemAdded, ^agg_id, ^item)} ]} =
      MemStoreExample.load_stream_events(agg_id)

    assert {:ok, ^agg_id} = CommandRouterExample.dispatch Commands.c(AddItem, agg_id, item2),
      service_data: "service data"

    assert {:ok, [ %Event{event: Events.c(ItemAdded, ^agg_id, ^item2),
                          service_data: "service data"},
                   %Event{event: Events.c(ItemAdded, ^agg_id, ^item)}]} =
      MemStoreExample.load_all_events()
  end

  test "`dispatch_wait_for` dispatches command and blocks until event is received and returns it",
    %{agg_id: agg_id, item: item} do

    assert {:ok, ^agg_id, %Event{event: Events.c(ItemAdded, ^agg_id, ^item)}} =
      CommandRouterExample.dispatch_wait_for(
        Commands.c(AddItem, agg_id, item),
        [Events])

    delay = 100
    start_time = :erlang.system_time / 1_000_000
    assert {:ok, ^agg_id, %Event{event: Events.c(ItemsProcessed, ^agg_id, delay)}} =
      CommandRouterExample.dispatch_wait_for(
        Commands.c(ProcessItems, agg_id, delay),
        [Events])
    end_time = :erlang.system_time / 1_000_000
    assert (end_time - start_time) >= delay # hacky but should work
    assert (end_time - start_time) <= delay + 0.1*delay # some error margin
  end

  test "`dispatch_wait_for` handles subscribing and unsubscribing",
    %{agg_id: agg_id, item: item, item2: item2, item3: item3} do
    alias Neuryt.EventBus

    assert {:ok, ^agg_id, %Event{event: Events.c(ItemAdded, ^agg_id, ^item)}} =
      CommandRouterExample.dispatch_wait_for(Commands.c(AddItem, agg_id, item),
        [Events], auto_unsubscribe: false)
    assert Enum.member? EventBus.list_subscribers(Events), self
    EventBus.unsubscribe Events

    assert {:ok, ^agg_id, %Event{event: Events.c(ItemAdded, ^agg_id, ^item2)}} =
      CommandRouterExample.dispatch_wait_for(Commands.c(AddItem, agg_id, item2),
        [Events], auto_unsubscribe: true)
    refute Enum.member? EventBus.list_subscribers(Events), self

    assert {:ok, ^agg_id, %Event{event: Events.c(ItemAdded, ^agg_id, ^item3)}} =
      CommandRouterExample.dispatch_wait_for(Commands.c(AddItem, agg_id, item3),
        [Events])
    refute Enum.member? EventBus.list_subscribers(Events), self
  end

  test "`dispatch_wait_for` {:ok, agg_id, :timeout} timeout when no message is received within given timeout",
      %{agg_id: agg_id, item: item} do

    assert {:ok, ^agg_id, :timeout} = CommandRouterExample.dispatch_wait_for(
      Commands.c(AddItem, agg_id, item), [Events], timeout: 0)
  end
end
