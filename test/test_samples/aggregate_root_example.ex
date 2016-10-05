defmodule AggregateRootExample do
  use Neuryt.AggregateRoot, fields: [items: []]

  alias  Neuryt.Event
  alias  AggregateRootExample.Events
  require AggregateRootExample.Events

  def add_item(%AggregateRootExample{} = aggregate, item) do
    case Enum.any?( aggregate.items, & &1 === item) do
      false -> {:ok, [%Event{event: Events.c(ItemAdded, item)}]}
      true  -> {:error, :already_added}
    end
  end

  def apply(%Event{event: event}, %AggregateRootExample{items: items} = aggregate) do
    Events.case event do
      ItemAdded in item -> %AggregateRootExample{aggregate | items: [item | items]}
    end
  end
end
