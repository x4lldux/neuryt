defmodule Neuryt.EventBus do
  @moduledoc """
  EventBus used for subscribing and publishing for specific events.
  """

  @doc """
  Publishes an event to all it subscribers.
  """
  @spec publish(Neuryt.Event.t) :: :ok
  def publish(%Neuryt.Event{event: %{__struct__: event_name}} = event) do
    :pg2.create all_events_group
    :pg2.create event_group(event_name)

    [all_events_group, event_group(event_name)]
    |> Enum.flat_map(&:pg2.get_local_members/1)
    |> Enum.uniq
    |> Enum.each(fn x -> send x, event end)

    :ok
  end


  @doc """
  Subscribes processes for events of specific type.
  """
  @spec subscribe(any) :: :ok
  def subscribe(event_name) do
    event_group = event_group(event_name)
    :pg2.create event_group
    if not self in :pg2.get_local_members event_group do
      :pg2.join event_group, self
    end

    :ok
  end

  @doc """
  Unsubscribes from an event.
  """
  @spec unsubscribe(Neuryt.Event.t) :: :ok
  def unsubscribe(event_name) do
    event_group = event_group(event_name)
    if self in :pg2.get_local_members event_group do
      :pg2.leave event_group, self
    end

    :ok
  end

  @doc """
  List all process subscribed to the event.
  """
  @spec list_subscribers(any) :: [pid]
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
  defp all_events_group, do: {__MODULE__, :all_events}
end
