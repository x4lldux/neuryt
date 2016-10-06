defmodule AggregateRootExample do
  use Neuryt.AggregateRoot, fields: [items: []]
  require AggregateRootExample.Events

  alias  Neuryt.Event
  alias  AggregateRootExample.Events

  def add_item(%AggregateRootExample{} = aggregate, item) do
    case Enum.any?( aggregate.items, & &1 === item) do
      false -> {:ok, [%Event{event: Events.c(ItemAdded, aggregate.id, item)}]}
      true  -> {:error, :already_added}
    end
  end

  def apply(%Event{event: event}, %AggregateRootExample{items: items} = aggregate) do
    Events.case event do
      ItemAdded in _agg_id, item ->
        %AggregateRootExample{aggregate | items: [item | items]}
      ItemRemoved in _agg_id, item ->
        %AggregateRootExample{aggregate | items: (items -- [item])}
      ItemsCleared in _agg_id ->
        %AggregateRootExample{aggregate | items: []}
    end
  end
end
