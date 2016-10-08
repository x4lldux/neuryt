defmodule Neuryt.Command do
  @moduledoc """
  Envelope for holding command with metadata.
  """

  @type id :: Neuryt.UUID.t
  @type t :: %Neuryt.Command{command: %{__struct__: atom},
                             id: id,
                             predecessor_id: id | nil,
                             process_id: id,
                             created_at: DateTime.t,
                             service_data: any}
  @enforce_keys [:command]
  defstruct command: nil,
    id: nil,                    # unique event id
    predecessor_id: nil,        # id of which this event is response to
    process_id: nil,            # unique id of process,  is always just copied
    created_at: nil,            # datetime of creation in UTC
    service_data: nil

  @doc """
  Builds new command envelope.
  """
  @spec new(any, any) :: Neuryt.Command.t
  def new(payload, service_data) do
    %__MODULE__{
      id:             Neuryt.UUID.new,
      command:        payload,
      predecessor_id: nil,
      process_id:     Neuryt.UUID.new,
      service_data:   service_data,
      created_at:     DateTime.utc_now,
    }
  end
  @spec new(any, Neuryt.Event.t, any) :: Neuryt.Command.t
  def new(payload, %Neuryt.Event{} = event, service_data) do
    %__MODULE__{
      id:             Neuryt.UUID.new,
      command:        payload,
      predecessor_id: event.id,
      process_id:     event.process_id,
      service_data:   service_data,
      created_at:     DateTime.utc_now,
    }
  end
end
