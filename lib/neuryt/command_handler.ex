defmodule Neuryt.CommandHandler do
  @moduledoc """
  Command handler behaviour.
  """

  @type raw_event :: any
  @type event :: Neuryt.Event.t
  @type command :: Neuryt.Command.t
  @type aggregate :: %{}
  @type reason :: any

  @doc """
  Handles command sent to AR and returns list of events that will be published.
  """
  @callback handle(command, aggregate) :: {:ok, [raw_event | event]} | {:error, reason}
end
