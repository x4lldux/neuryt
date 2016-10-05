defmodule ExampleAggregateRoot.Events do
  use DiscUnion

  @type item :: any
  defunion ItemAdded in item
end

defmodule ExampleAggregateRoot do
  use Neuryt.AggregateRoot, fields: [items: []]

  alias  ExampleAggregateRoot.Events
  require ExampleAggregateRoot.Events

  def add_item(%ExampleAggregateRoot{} = aggregate, item) do
    case Enum.any?( aggregate.items, & &1 === item) do
      false -> {:ok, [Events.c(ItemAdded, item)]}
      true  -> {:error, :already_added}
    end
  end

  def apply(event, %ExampleAggregateRoot{items: items} = aggregate) do
    Events.case event do
      ItemAdded in item -> %ExampleAggregateRoot{aggregate | items: [item | items]}
    end
  end
end

defmodule AggregateRootBehaviourTest do
  use ExUnit.Case
  require ExampleAggregateRoot.Events

  test "fresh aggregate has id and version" do
    aggregate = ExampleAggregateRoot.new("id")

    assert aggregate.id == "id"
    assert aggregate.version == 0
  end

  test "applies event" do
    aggregate = with aggregate <- ExampleAggregateRoot.new("id"),
                     {:ok, events} <- ExampleAggregateRoot.add_item(aggregate, "thing"),
      do: ExampleAggregateRoot.update(aggregate, events)

    assert aggregate.id == "id"
    assert aggregate.items == ["thing"]
    assert aggregate.version == 1
  end

  test "load from events" do
    events = [ExampleAggregateRoot.Events.c(ItemAdded, "thing")]
    aggregate = ExampleAggregateRoot.load("id", events)

    assert aggregate.items == ["thing"]
    assert aggregate.id == "id"
    assert aggregate.version == 1
  end
end
