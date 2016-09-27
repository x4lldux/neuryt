defmodule Neuryt.EventBus do
  @moduledoc """
  EventBus used for subscribing and publishing for specific events.
  """

  @doc """
  Subscribes process for events of specific type.
  """
  @spec subscribe(any) :: :ok
  def subscribe(event_name) do
    event_group = {:event, event_name}
    :pg2.create event_group
    if not self in :pg2.get_local_members event_group do
      :pg2.join event_group, self
    end

    :ok
  end

  def unsubscribe(event_name) do
    event_group = {:event, event_name}
    if self in :pg2.get_local_members event_group do
      :pg2.leave event_group, self
    end
    :ok
  end

  @doc """
  Publishes an event to all it subscribers.
  """

  @spec publish(Neuryt.Event.t) :: :ok
  def publish(%Neuryt.Event{event: %{__struct__: event_name}}=event) do
    {:event, event_name}
    |> :pg2.get_local_members
    |> Enum.each(fn x -> send x, event end)

    :ok
  end

  @doc """
  List all process subscribed to the event.
  """
  @spec list_subscribers(any) :: [pid]
  def list_subscribers(event_name) do
    :pg2.get_local_members {:event, event_name}
  end
end
