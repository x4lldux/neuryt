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

  # dispatch the given command to the corresponding aggregate root
  @doc """
  Defines a route for commands to a command handler specified in `:to` option,
  for aggregate root specified in `:for_ar`.
  If `:for_ar` is omitted then module from `:to` will be used.
  """
  defmacro route(command_module, opts) do
    command_handler = Keyword.get(opts, :to)
    aggregate = Keyword.get(opts, :for_ar, command_handler)
    ar_idle_timeout = Keyword.get(opts, :ar_idle_timeout)

    quote do
      if Enum.member?(@registered_commands, unquote(command_module)) do
        raise "duplicate command registration for: #{unquote(command_module)}"
      end

      @registered_commands [unquote(command_module) | @registered_commands]

      @doc """
      Dispatch the given command to the registered handler.

      Accepts additional options:
        * `:reaction_to` - used in process managers. An event should be passed,
        when command is sent because of received event - used for preserving IDs,
        * `:service_data` - which can be used to store user id, HTTP
        request id or other metadata from service layer,

      Returns `:ok` on success.
      """
      def dispatch(%unquote(command_module){} = command) do
        Neuryt.Command.Dispatcher.dispatch(command, unquote(command_handler),
          unquote(aggregate), [ar_idle_timeout: unquote(ar_idle_timeout)])
      end
      def dispatch(%unquote(command_module){} = command, opts) do
        Neuryt.Command.Dispatcher.dispatch(command, unquote(command_handler),
          unquote(aggregate), opts ++ [ar_idle_timeout: unquote(ar_idle_timeout)])
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
