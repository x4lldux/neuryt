defmodule Neuryt.AggregateRoot do
  defmacro __using__(fields: fields) do
    quote do
      import Kernel, except: [apply: 2]

      defstruct [id: nil, version: 0] ++ unquote(fields)

      def new(id) do
        %__MODULE__{id: id}
      end

      def load(id, events) when is_list(events) do
        aggregate = Enum.reduce(events, %__MODULE__{id: id}, &__MODULE__.apply(&2, &1))
        %__MODULE__{aggregate | version: length(events)}
      end

      def update(%__MODULE__{id: id, version: version} = aggregate, events) when is_list(events) do
        aggregate = Enum.reduce(events, aggregate, &__MODULE__.apply(&2, &1))
        %__MODULE__{ aggregate | version: version + length(events) }
      end
    end
  end
end
