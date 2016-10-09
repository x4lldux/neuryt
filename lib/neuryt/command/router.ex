defmodule Neuryt.Command.Router do
  @moduledoc """

  """
  defmacro __using__(_) do
    quote do
      require Logger
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      @registered_commands []
    end
  end

  # dispatch the given command to the corresponding  aggregate root
  defmacro route(command_module, to: aggregate) do
    quote do
      if Enum.member?(@registered_commands, unquote(command_module)) do
        raise "duplicate command registration for: #{unquote(command_module)}"
      end

      @registered_commands [unquote(command_module) | @registered_commands]

      @doc """
      Dispatch the given command to the registered handler

      Returns `:ok` on success.
      """
      def dispatch(%unquote(command_module){} = command) do
        Neuryt.Command.Dispatcher.dispatch(command, unquote(aggregate))
      end
      def dispatch(%unquote(command_module){} = command, service_data: service_data) do
        Neuryt.Command.Dispatcher.dispatch(command, unquote(aggregate), service_data)
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      # return error if an unregistered command is dispatched
      def dispatch(command) do
        # Logger.error("attempted to dispatch an unregistered command: #{inspect command}")
        {:error, :unregistered_command}
      end
      def dispatch(command, service_data: _service_data) do
        # Logger.error("attempted to dispatch an unregistered command: #{inspect command}")
        {:error, :unregistered_command}
      end
    end
  end
end
