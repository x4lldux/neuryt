defmodule SomeEvents do
  use DiscUnion

  defunion Event1 | Event2 in integer
end

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
      assert_receive %Event{event: SomeEvents.c Event1}, 1000
      send home, :done
    end

    spawn_link receiver_fun
    assert_receive :ready
    spawn_link receiver_fun
    assert_receive :ready

    EventBus.publish %Event{event: SomeEvents.c Event1}

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
      assert_receive %Event{event: SomeEvents.c Event1}, 1000
      send home, :done
    end

    spawn_link receiver_fun
    assert_receive :ready
    spawn_link receiver_fun
    assert_receive :ready

    EventBus.publish %Event{event: SomeEvents.c Event1}

    assert_receive :done
    assert_receive :done
  end

  test "can unsubscribe from special `all events` stream" do
    EventBus.subscribe_to_all_events
    assert [self] == EventBus.list_subscribers_to_all_events
    EventBus.unsubscribe_from_all_events
    assert [] == EventBus.list_subscribers_to_all_events
  end
end
