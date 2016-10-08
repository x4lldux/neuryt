defmodule EventTest do
  use ExUnit.Case
  alias Neuryt.{Event, Command}

  test "creating new event" do
    payload = SomeEvent
    event = Event.new(payload, "example_service_data")

    assert %Event{event: ^payload} = event
    assert event.id != nil
    assert event.predecessor_id == nil
    assert event.process_id != nil
    assert event.service_data == "example_service_data"
    assert %DateTime{} = event.created_at
  end

  test "creating new based on a command" do
    command = Command.new(SomeCommand, "example_service_data0")
    payload = SomeEvent
    event = Event.new(payload, command, "example_service_data")

    assert %Event{event: ^payload} = event
    assert event.id != nil
    assert event.predecessor_id == command.id
    assert event.process_id != nil
    assert event.process_id == command.process_id
    assert event.service_data == "example_service_data"
    assert %DateTime{} = event.created_at
  end
end
