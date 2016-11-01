defmodule EventBusTest do
  use ExUnit.Case, async: false
  require SomeEvents

  alias Neuryt.{Event, EventBus}

  test "can subscribe for a specific event" do
    EventBus.subscribe SomeEvents
    assert [self] == EventBus.list_subscribers(SomeEvents)
  end

  test "process can subscribe only once" do
    EventBus.subscribe SomeEvents
    EventBus.subscribe SomeEvents

    assert [self] == EventBus.list_subscribers(SomeEvents)
  end

  test "can publish events to subscribed processes" do
    home = self
    receiver_fun = fn ->
      EventBus.subscribe SomeEvents
      send home, :ready
      assert_receive %Event{event: SomeEvents.c(Event1, 123)}, 1000
      send home, :done
    end

    spawn_link receiver_fun
    assert_receive :ready
    spawn_link receiver_fun
    assert_receive :ready

    EventBus.publish %Event{event: SomeEvents.c(Event1, 123)}

    assert_receive :done
    assert_receive :done
  end

  test "can unsubscribe from a specific event" do
    EventBus.subscribe SomeEvents
    assert [self] == EventBus.list_subscribers(SomeEvents)
    EventBus.unsubscribe SomeEvents
    assert [] == EventBus.list_subscribers(SomeEvents)
  end


  test "can sunbscrinbe to special `all events` stream" do
    EventBus.subscribe_to_all_events
    assert [self] == EventBus.list_subscribers_to_all_events
  end

  test "when publishing an event it also is published to special `all events` stream" do
    home = self
    receiver_fun = fn ->
      EventBus.subscribe_to_all_events
      send home, :ready
      assert_receive %Event{event: SomeEvents.c(Event1, 123)}, 1000
      send home, :done
    end

    spawn_link receiver_fun
    assert_receive :ready
    spawn_link receiver_fun
    assert_receive :ready

    EventBus.publish %Event{event: SomeEvents.c(Event1, 123)}

    assert_receive :done
    assert_receive :done
  end

  test "can unsubscribe from special `all events` stream" do
    EventBus.subscribe_to_all_events
    assert [self] == EventBus.list_subscribers_to_all_events
    EventBus.unsubscribe_from_all_events
    assert [] == EventBus.list_subscribers_to_all_events
  end

  test "can subscribe to events from a specific aggregate" do
    EventBus.subscribe {SomeEvents, 123}
    assert [self] == EventBus.list_subscribers({SomeEvents, 123})
  end

  test "subscribers of events for a specific aggregate, receive only that" do
    EventBus.subscribe {SomeEvents, 123}
    assert [self] == EventBus.list_subscribers({SomeEvents, 123})

    EventBus.publish %Event{event: SomeEvents.c(Event1, 123)}
    EventBus.publish %Event{event: SomeEvents.c(Event1, 456)}
    assert_receive %Event{event: SomeEvents.c(Event1, 123)}, 1000
    refute_receive %Event{event: SomeEvents.c(Event1, 456)}
  end

  test "unsubscribing from a specific event removes it's group when no other process is subscribed" do
    # little ugly becyause implementations leaked to test, but I don't see any
    # other way to test this. We need this feature to cleanup unused groups and
    # not leak memory
    agg_id = Neuryt.UUID.new
    refute Enum.member? :pg2.which_groups, {Neuryt.EventBus, :event, SomeEvents, agg_id}
    EventBus.subscribe {SomeEvents, agg_id}
    assert Enum.member? :pg2.which_groups, {Neuryt.EventBus, :event, SomeEvents, agg_id}
    EventBus.unsubscribe {SomeEvents, agg_id}
    refute Enum.member? :pg2.which_groups, {Neuryt.EventBus, :event, SomeEvents, agg_id}
  end
end
