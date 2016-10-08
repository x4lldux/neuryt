defmodule Neuryt.Event do
  @moduledoc """
  Envelope for holding events with metadata.
  """

  @type id :: Neuryt.UUID.t
  @type t :: %Neuryt.Event{event: %{__struct__: atom},
                           id: id,
                           predecessor_id: id | nil,
                           process_id: id,
                           created_at: DateTime.t,
                           service_data: any}
  @enforce_keys [:event]
  defstruct event: nil,
    id: nil,                    # unique event id
    predecessor_id: nil,        # id of which this event is response to
    process_id: nil,            # id of process, is always just copied
    created_at: nil,            # datetime of creation in UTC
    service_data: %{}

  @doc """
  Build new event envelope.
  """
  @spec new(any) :: Neuryt.Event.t
  def new(payload) do
    %__MODULE__{
      id:             Neuryt.UUID.new,
      event:          payload,
      predecessor_id: nil,
      process_id:     Neuryt.UUID.new,
      service_data:   nil,
      created_at:     DateTime.utc_now,
    }
  end
  @spec new(any, service_data: any) :: Neuryt.Event.t
  def new(payload, service_data: service_data) do
    %__MODULE__{
      id:             Neuryt.UUID.new,
      event:          payload,
      predecessor_id: nil,
      process_id:     Neuryt.UUID.new,
      service_data:   service_data,
      created_at:     DateTime.utc_now,
    }
  end
  @spec new(any, Neuryt.Command.t) :: Neuryt.Event.t
  def new(payload, %Neuryt.Command{} = command) do
    %__MODULE__{
      id:             Neuryt.UUID.new,
      event:          payload,
      predecessor_id: command.id,
      process_id:     command.process_id,
      service_data:   command.service_data,
      created_at:     DateTime.utc_now,
    }
  end
  @spec new(any, Neuryt.Command.t, service_data: any) :: Neuryt.Event.t
  def new(payload, %Neuryt.Command{} = command, service_data: service_data) do
    %__MODULE__{
      id:             Neuryt.UUID.new,
      event:          payload,
      predecessor_id: command.id,
      process_id:     command.process_id,
      service_data:   service_data,
      created_at:     DateTime.utc_now,
    }
  end
end
