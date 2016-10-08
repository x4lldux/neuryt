defmodule CommandTest do
  use ExUnit.Case
  alias Neuryt.{Event, Command}

  test "creating new command" do
    payload = SomeCommand
    command = Command.new(payload, "example_service_data")

    assert %Command{command: ^payload} = command
    assert command.id != nil
    assert command.predecessor_id == nil
    assert command.process_id != nil
    assert command.service_data == "example_service_data"
    assert %DateTime{} = command.created_at
  end

  test "creating new based on an event" do
    event = Event.new(SomeEvent, "example_service_data0")
    payload = SomeEvent
    command = Command.new(payload, event, "example_service_data1")

    assert %Command{command: ^payload} = command
    assert command.id != nil
    assert command.predecessor_id == event.id
    assert command.process_id != nil
    assert command.process_id == event.process_id
    assert command.service_data == "example_service_data1"
    assert %DateTime{} = command.created_at
  end
end
