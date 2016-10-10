defmodule EventTest do
  use ExUnit.Case
  alias Neuryt.{Event, Command}

  test "creating new event" do
    payload = SomeEvent
    event = Event.new(payload)

    assert %Event{event: ^payload} = event
    assert event.id != nil
    assert event.predecessor_id == nil
    assert event.process_id != nil
    assert event.service_data == nil
    assert %DateTime{} = event.created_at

    event = Event.new(payload, service_data: "example_service_data")
    assert event.service_data == "example_service_data"
  end

  test "creating new based on a command" do
    command = Command.new(SomeCommand, service_data: "example_service_data0")
    payload = SomeEvent
    event = Event.new(payload, command, service_data: "example_service_data1")

    assert %Event{event: ^payload} = event
    assert event.id != nil
    assert event.predecessor_id == nil
    assert event.process_id != nil
    assert event.process_id == command.process_id
    assert event.service_data == "example_service_data1"
    assert %DateTime{} = event.created_at
  end

  test "creating new event based on a command which was reaction on an event preserves process_id and last event's predecessor_id" do
    payload = SomeEvent
    event0 = Event.new(payload, service_data: "example_service_data0")
    command = Command.new(SomeCommand, event0, service_data: "example_service_data1")
    assert command.process_id == event0.process_id

    event = Event.new(payload, command, service_data: "example_service_data2")

    assert %Event{event: ^payload} = event
    assert event.id != nil
    assert event.predecessor_id == event0.id
    assert event.process_id != nil
    assert event.process_id == event0.process_id
    assert event.service_data == "example_service_data2"
    assert %DateTime{} = event.created_at
  end
end
