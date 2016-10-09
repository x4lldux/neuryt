defmodule AggregateRootBehaviourTest do
  use ExUnit.Case
  require AggregateRootExample.Events
  alias  Neuryt.Event

  test "fresh aggregate has id and version" do
    aggregate = AggregateRootExample.new("id")

    assert aggregate.id == "id"
    assert aggregate.version == 0
  end

  test "applies event" do
    aggregate =
      with aggregate <- AggregateRootExample.new("id"),
           {:ok, events} <- AggregateRootExample.add_item(aggregate, "thing"),
             events <- Enum.map(events, fn e -> Event.new(e) end),
      do: AggregateRootExample.update(aggregate, events)

    assert aggregate.id == "id"
    assert aggregate.items == ["thing"]
    assert aggregate.version == 1
  end

  test "load from events" do
    events = [%Event{event: AggregateRootExample.Events.c(ItemAdded, Neuryt.UUID.new, "thing")}]
    aggregate = AggregateRootExample.load("id", events)

    assert aggregate.items == ["thing"]
    assert aggregate.id == "id"
    assert aggregate.version == 1
  end
end
