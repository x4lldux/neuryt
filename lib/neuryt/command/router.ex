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
        * `:service_data` - which can be used to store user id, HTTP request id
        or other metadata from service layer,

      Returns `{:ok, aggregate_id}` on success.
      On error returns `{:error, reason}`.
      """
      def dispatch(%unquote(command_module){} = command) do
        dispatch command, []
      end
      def dispatch(%unquote(command_module){} = command, opts) do
        opts = opts ++ [ar_idle_timeout: unquote(ar_idle_timeout)]
        Neuryt.Command.Dispatcher.dispatch(command, unquote(command_handler),
          unquote(aggregate), opts)
      end

      @doc """
      Dispatch the given command to the registered handler, subscribe to a list
      of events and blocks until one of those events is published.

      Accepts additional options:
      * `:reaction_to` - used in process managers. An event should be passed,
      when command is sent because of received event - used for preserving IDs,
      * `:service_data` - which can be used to store user id, HTTP request id
      or other metadata from service layer,
      * `:timeout` - how long (in milliseconds) to wait for an event (default is
      5000), can be set to `:infinity`,
      * `auto_unsubscribe` - whether to automatically unsubscribe, once the
      event is receibed (default is true).

      On suscess returns `{:ok, aggregate_id, event}` when event is received, or
      `{:ok, aggregate_id, :timeout}` when timeout was reached.
      On error returns `{:error, reason}`.
      """
      def dispatch_wait_for(%unquote(command_module){} = command, events) do
        dispatch_wait_for command, events, []
      end
      def dispatch_wait_for(%unquote(command_module){} = command, events, opts) do
        opts = opts ++ [
          ar_idle_timeout: unquote(ar_idle_timeout),
          timeout: 5000,
          auto_unsubscribe: true
        ]
        timeout = Keyword.get opts, :timeout

        events
        |> Enum.each(&Neuryt.EventBus.subscribe/1)

        res = case Neuryt.Command.Dispatcher.dispatch(command, unquote(command_handler),
                    unquote(aggregate), opts) do
                {:ok, agg_id} ->
                  receive do
                    %Neuryt.Event{} = event -> {:ok, agg_id, event}
                  after timeout             -> {:ok, agg_id, :timeout}
                  end
                {:error, _reason} = err -> err
              end

        if Keyword.get opts, :auto_unsubscribe do
          events
          |> Enum.each(&Neuryt.EventBus.unsubscribe/1)
        end

        res
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      # return error if an unregistered command is dispatched
      def dispatch(_command) do
        # Logger.error("attempted to dispatch an unregistered command: #{inspect command}")
        {:error, :unregistered_command}
      end
      def dispatch(_command, _opts) do
        # Logger.error("attempted to dispatch an unregistered command: #{inspect command}")
        {:error, :unregistered_command}
      end
      def dispatch_wait_for(_command, _events) do
        # Logger.error("attempted to dispatch an unregistered command: #{inspect command}")
        {:error, :unregistered_command}
      end
      def dispatch_wait_for(_command, _events, _opts) do
        # Logger.error("attempted to dispatch an unregistered command: #{inspect command}")
        {:error, :unregistered_command}
      end
    end
  end
end
