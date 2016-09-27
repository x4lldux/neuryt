defmodule Neuryt.Event do
  @moduledoc """
  Structure for holding events with metadata.
  """

  @type t :: %Neuryt.Event{event: %{__struct__: atom}, created_at: DateTime.t, id: any,
                    process_id: any, request_id: any}
  @enforce_keys [:event]
  defstruct event: nil, created_at: nil, id: nil, process_id: nil,
    request_id: nil
end
