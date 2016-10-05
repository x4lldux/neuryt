defmodule Neuryt.EventStore do
  @moduledoc """
  A behaviour module for implementing event store responsible for loading and
  saving events.

  Storage to use has to be set in application config via `:event_store` option,
  config/config.exs:

     config :neuryt, event_store: Neuryt.EventStore.Bitcask
  """

  @type reason :: any
  @type stream_id :: any

  @callback save_event(Neuryt.Event.t) :: :ok | {:error, reason}
  @callback save_events([Neuryt.Event.t]) :: :ok | {:error, reason}
  @callback load_all_events() :: {:ok, [Neuryt.Event.t]} | {:error, reason}
  @callback count_all_events() :: {:ok, integer} | {:error, reason}
  @callback load_stream_events(stream_id) :: {:ok, [Neuryt.Event.t]} | {:error, reason}
  @callback count_stream_events(stream_id) :: {:ok, integer} | {:error, reason}
  @callback list_streams() :: {:ok, [stream_id]} | {:error, reason}
end
