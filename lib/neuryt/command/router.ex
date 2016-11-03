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

      def do_dispatch_wait_for(%unquote(command_module){} = command, events,
        receiver_fun, acceptor_fun, opts) do
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
                  receiver_fun.(receiver_fun, acceptor_fun, agg_id, timeout)
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

  def build_receiver_fun(events) do
    # will have spec:
    # recv_fun(do_recv, acceptor_fun, agg_id, timeout)

    recv_clause_body = quote do
      end_time = :erlang.system_time
      if acceptor_fun.(event) do
        {:ok, agg_id, event}
      else
        timeout = case timeout do
                    :infinity ->
                      :infinity
                    timeout ->
                      timeout - round((end_time - start_time)/1_000_000)
                  end
        do_recv.(do_recv, acceptor_fun, agg_id, timeout)
      end
    end

    event_clauses = Enum.flat_map(events, fn
      mod = {:__aliases__, _, _} ->
        quote do
          event = %Neuryt.Event{event: %unquote(mod){}} ->
            unquote(recv_clause_body)
        end
      {mod = {:__aliases__, _, _}, agg_id} ->
        quote do
          event = %Neuryt.Event{event: %unquote(mod){case: c}} when elem(c, 1) == agg_id ->
            unquote(recv_clause_body)
        end
    end)

    timeout_clause = quote do
      timeout -> {:ok, agg_id, :timeout}
    end

    quote do
      fn do_recv, acceptor_fun, agg_id, timeout ->
        start_time = :erlang.system_time
        receive do: unquote(event_clauses),
             after: unquote(timeout_clause)
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @doc """
      Dispatch the given command to the registered handler, subscribe to a list
      of events and blocks until one of those events is published. This is very
      useful when dealing with commands that trigger interactions with process
      managers.

      The `events` parameter needs to be a list of events union or a tuple of an
      events union and aggregate id, if you want to receive events only from a
      specific aggregate: `{event, aggregate_id}`.

      The `acceptor_fun` will be called when an event, of a matching events
      union, is received, to check if you are interested in this event. Neuryt,
      heavily depends on DiscUnion to create discriminated unions for events and
      commands. You specify a list od union of events to await for and later,
      when an event from one of those unions is published, acceptor function
      will be called with that event. Acceptor function should return true or
      false if this is one of interesting events. Using disseminated unions, and
      its dedicated `case` macro, forces programmer to always cover all possible
      events - and when a new event will be added, DiscUnion will automatically
      notify report where this new event is not covered.

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

      # Example:
      ```
      ExampleRouter.dispatch_wait_for(Order.Commands.c(AddItem, agg_id, item),
        [{Order.Events, agg_id}], fn event ->
          Order.Events.case event do
            ItemAdded         in agg_id, item -> true
            ItemAddRollbacked in agg_id, item -> true
            ItemRemoved       in agg_id, item -> false
            ItemsCleared      in agg_id       -> false
          end
        end)
      ```

      It will dispatch a command `AddItem` and wait for events defined in
      `Order.Events` form a specific aggregate. When one of them will arrive,
      acceptor function will be called to determine if it's one of those events
      you are interesed. Only `ItemAdded` and `ItemAddRollbacked` will cause
      `dispatch_wait_for` to return (or a timeout).

      """
      defmacro dispatch_wait_for(command, events, # acceptor_fun \\ &Neuryt.Command.Router.accept_all_events/1, opts \\ [])
          acceptor_fun \\ fn _ -> true end, opts \\ []) # UGLY DOCS HACK
      defmacro dispatch_wait_for(command, events, acceptor_fun, opts) do
        # UGLY DOCS HACK: since this is a macro, default value must be quoted
        # but this looks ugly in docs! this function checks if `acceptor_fun` is
        # a function, during compile time, and replaces it with default quoted
        # version that is the same as in docs.
        acceptor_fun = case is_function(acceptor_fun) do
                         true -> quote do: fn _ -> true end
                         false -> acceptor_fun
                       end
        receiver_fun = Neuryt.Command.Router.build_receiver_fun events
        mod = __MODULE__

        quote do
          unquote(mod).do_dispatch_wait_for(unquote(command), unquote(events),
            unquote(receiver_fun), unquote(acceptor_fun), unquote(opts))
        end
      end

      # return error if an unregistered command is dispatched
      def dispatch(_command) do
        # Logger.error("attempted to dispatch an unregistered command: #{inspect command}")
        {:error, :unregistered_command}
      end
      def dispatch(_command, _opts) do
        # Logger.error("attempted to dispatch an unregistered command: #{inspect command}")
        {:error, :unregistered_command}
      end
      def do_dispatch_wait_for(_, _, _, _, _) do
        # Logger.error("attempted to dispatch an unregistered command: #{inspect command}")
        {:error, :unregistered_command}
      end
    end
  end
end
