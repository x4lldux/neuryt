defmodule Neuryt.EventBus do
  @moduledoc """
  EventBus used for subscribing and publishing for specific events.
  """

  @doc """
  Publishes an event to all it subscribers.
  """
  @spec publish(Neuryt.Event.t) :: :ok
  def publish(%Neuryt.Event{event: %{__struct__: event_name, case: _}} = event) do
    :pg2.create all_events_group
    :pg2.create event_group(event_name)

    agg_id = get_stream_id event.event
    case Enum.member?(:pg2.which_groups, event_group(event_name, agg_id)) do
      true  -> [all_events_group, event_group(event_name),
                 event_group(event_name, agg_id)]
      false -> [all_events_group, event_group(event_name)]
    end
    |> Enum.flat_map(&:pg2.get_local_members/1)
    |> Enum.uniq
    |> Enum.each(fn x -> send x, event end)

    :ok
  end

  @doc """
  Subscribes processes for events of specific type.
  You can pass a tuple `{event_type, agg_id}` which will subscribe process only
  to events of that type for a specific aggregate.
  """
  @spec subscribe({atom, Neuryt.UUID.t}) :: :ok
  def subscribe({event_name, agg_id}) when is_atom(event_name) do
    event_name
    |> event_group(agg_id)
    |> do_subscribe
    :ok
  end
  @spec subscribe(atom) :: :ok
  def subscribe(event_name) when is_atom(event_name) do
    event_name
    |> event_group
    |> do_subscribe
    :ok
  end

  defp do_subscribe(event_group) do
    :pg2.create event_group
    if not self in :pg2.get_local_members event_group do
      :pg2.join event_group, self
    end
  end

  @doc """
  Unsubscribes from an event.
  You can pass a tuple `{event_type, agg_id}` which will unsubscribe process
  only from events of that type for a specific aggregate.
  """
  @spec unsubscribe(Neuryt.Event.t) :: :ok
  def unsubscribe({event_name, agg_id}) do
    event_group = event_group(event_name, agg_id)
    do_unsubscribe event_group

    case :pg2.get_local_members event_group do
      [] -> :pg2.delete event_group
      _ -> :ok
    end

    :ok
  end
  def unsubscribe(event_name) do
    event_name
    |> event_group
    |> do_unsubscribe
    :ok
  end

  defp do_unsubscribe(event_group) do
    if self in :pg2.get_local_members event_group do
      :pg2.leave event_group, self
    end
  end

  @doc """
  List all process subscribed to the event.
  """
  @spec list_subscribers(any) :: [pid]
  def list_subscribers({event_name, agg_id}) do
    :pg2.get_local_members event_group(event_name, agg_id)
  end
  def list_subscribers(event_name) do
    :pg2.get_local_members event_group(event_name)
  end

  @doc """
  Subscribes to all events that go through event bus.
  """
  @spec subscribe_to_all_events() :: :ok
  def subscribe_to_all_events do
    :pg2.create all_events_group
    if not self in :pg2.get_local_members all_events_group do
      :pg2.join all_events_group, self
    end

    :ok
  end

  @doc """
  List all processes subscribed to the special `all events` stream.
  """
  @spec list_subscribers_to_all_events :: [pid]
  def list_subscribers_to_all_events do
    :pg2.create all_events_group
    :pg2.get_local_members all_events_group
  end

  @doc """
  Unsubscribes from special `all events` stream.
  """
  @spec unsubscribe_from_all_events :: :ok
  def unsubscribe_from_all_events do
    if self in :pg2.get_local_members all_events_group do
      :pg2.leave all_events_group, self
    end

    :ok
  end

  defp event_group(event_name), do: {__MODULE__, :event, event_name}
  defp event_group(event_name, agg_id), do: {__MODULE__, :event, event_name, agg_id}
  defp all_events_group, do: {__MODULE__, :all_events}

  defp get_stream_id(%{case: thing}) when is_tuple(thing) do
    # get the first argument from the command, by convention, this should
    # always be aggregate id
    elem thing, 1
  end
end
