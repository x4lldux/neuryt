defmodule SomeEvents do
  use DiscUnion

  defunion Event1 | Event2 in integer
end

defmodule EventBusTest do
  use ExUnit.Case
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

end
