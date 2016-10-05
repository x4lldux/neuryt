defmodule Neuryt.AggregateRoot do
  defmacro __using__(fields: fields) do
    quote do
      import Kernel, except: [apply: 2]
      @behaviour Neuryt.AggregateRoot

      @type t :: %__MODULE__{}
      defstruct [id: nil, version: 0] ++ unquote(fields)

      def new(id) do
        %__MODULE__{id: id}
      end

      def load(id, events) when is_list(events) do
        aggregate = Enum.reduce(events, %__MODULE__{id: id}, &__MODULE__.apply/2)
        %__MODULE__{aggregate | version: length(events)}
      end

      def update(%__MODULE__{id: id, version: version} = aggregate, events) when is_list(events) do
        aggregate = Enum.reduce(events, aggregate, &__MODULE__.apply/2)
        %__MODULE__{ aggregate | version: version + length(events) }
      end
    end
  end

  @type event :: any
  @type command :: any
  @type aggregate :: %{}

  @doc """
  Handles command sent to AR and returns list of events that will be published.
  """
  @callback handle(command, aggregate) :: [event]

  @doc """
  Applies event to aggregate root's state returning new AR state.
  """
  @callback apply(event, aggregate) :: aggregate
end
