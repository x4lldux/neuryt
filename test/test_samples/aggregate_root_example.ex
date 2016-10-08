defmodule AggregateRootExample do
  use Neuryt.AggregateRoot, fields: [items: []]
  require AggregateRootExample.Errors
  require AggregateRootExample.Events
  require AggregateRootExample.Commands

  alias Neuryt.{Event, Command}
  alias AggregateRootExample.Errors
  alias AggregateRootExample.Events
  alias AggregateRootExample.Commands

  def add_item(%AggregateRootExample{} = aggregate, item) do
    case Enum.any?( aggregate.items, & &1 === item) do
      false -> ok [Events.c(ItemAdded, aggregate.id, item) |> Event.new]
      true  -> error :already_added
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

  def handle(%Command{command: command}, %AggregateRootExample{} = aggregate) do
    Commands.case command do
      AddItem in agg_id, item ->
        if Enum.any?(aggregate.items, & &1 === item) do
          error Errors.c ItemAllreadyPresent
        else
          ok [Events.c(ItemAdded, agg_id, item) |> Event.new(command)]
        end

      RemoveItem in agg_id, item ->
        if Enum.any?(aggregate.items, & &1 === item) do
          ok [Events.c(ItemRemoved, agg_id, item) |> Event.new(command)]
        else
          error Errors.c NoSuchItem
        end

      ClearItems in agg_id ->
        ok [Events.c(ItemsCleared, agg_id) |> Event.new(command)]
    end
  end

  defp ok(x), do: {:ok, x}
  defp error(x), do: {:error, x}

end
