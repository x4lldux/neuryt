defmodule CommandRouterTest do
  use ExUnit.Case

  defmodule UnregisteredCommands do
    use DiscUnion
    defunion Foo in integer
  end

  defmodule CommandRouterExample do
    use Neuryt.Command.Router

    route AggregateRootExample.Commands, to: AggregateRootExample
    # route UnregisteredCommands, to: NonExistentAggregate
  end

  @agg_id Neuryt.UUID.new


  # test "should dispatch command to registered handler" do
  #   :ok = CommandRouterTest.CommandRouterExample.dispatch(
  #     AggregateRootExample.Commands.c!(AddItem, @agg_id, "thing"))
  # end

  test "should fail to dispatch unregistered command" do
    {:error, :unregistered_command} =
      CommandRouterTest.CommandRouterExample.dispatch UnregisteredCommands.c!(Foo, @agg_id)
  end

  test "should prevent duplicate registrations for commands" do
    assert_raise RuntimeError,
      "duplicate command registration for: Elixir.AggregateRootExample.Commands",
    fn ->
      Code.eval_string """
        defmodule DuplicateRouter do
          use Neuryt.Command.Router
          alias CommandRouterTest.CommandRouterExample
          alias CommandRouterTest.UnregistredCommands

          route AggregateRootExample.Commands, to: AggregateRootExample
          route AggregateRootExample.Commands, to: AggregateRootExample
        end
      """
    end
  end
end
