defmodule UUIDTest do
  use ExUnit.Case
  alias Neuryt.UUID

  @x_num 0xDEADBEEFDEADC0DEDEADBEEFDEADC0DE
  @x_bin <<0xDE, 0xAD, 0xBE, 0xEF, 0xDE, 0xAD, 0xC0, 0xDE, 0xDE, 0xAD, 0xBE, 0xEF, 0xDE, 0xAD, 0xC0, 0xDE>>
  @x_base64 "3q2-796twN7erb7v3q3A3g"
  @x_base64_padding "#{@x_base64}=="
  @x_string_default "deadbeef-dead-c0de-dead-beefdeadc0de"
  @x_string_hex "deadbeefdeadc0dedeadbeefdeadc0de"
  @x_string_urn "urn:uuid:#{@x_string_default}"

  test "new/0 generates unique integer" do # naive test
    range =  0..9999
    ids = for _ <- range, do: UUID.new
    assert length(ids |> Enum.uniq) == length(range |> Enum.to_list)
  end

  test "to_binary/1 converts interger id to binary representation" do
    assert UUID.to_binary(@x_num) == @x_bin
  end

  test "from_binary/1 converts binary id to integer representation" do
    assert UUID.from_binary(@x_bin) == {:ok, @x_num}
    # assert UUID.from_binary("asdf") == {:error, :badarg}
  end

  test "to_base64/1 converts id to url friendly base64 format" do
    assert UUID.to_base64(@x_num) == @x_base64
    assert UUID.to_base64(@x_bin) == @x_base64
  end

  test "to_string/2 converts id to string in supported format" do
    assert UUID.to_string(@x_num) == @x_string_default
    assert UUID.to_string(@x_bin) == @x_string_default

    assert UUID.to_string(@x_num, :default) == @x_string_default
    assert UUID.to_string(@x_bin, :default) == @x_string_default
    assert UUID.to_string(@x_num, :hex) == @x_string_hex
    assert UUID.to_string(@x_bin, :hex) == @x_string_hex
    assert UUID.to_string(@x_num, :urn) == @x_string_urn
    assert UUID.to_string(@x_bin, :urn) == @x_string_urn
  end

  test "from_string/1 converts string format to integer representtion" do
    assert UUID.from_string(@x_string_default) == {:ok, @x_num}
    assert UUID.from_string(@x_string_hex) == {:ok, @x_num}
    assert UUID.from_string(@x_string_urn) == {:ok, @x_num}
    assert UUID.from_string(@x_bin) == {:error, :badarg}
    assert UUID.from_string("asdf") == {:error, :badarg}
  end

  test "from_base64/1 converts base64 format to integer representation" do
    assert UUID.from_base64(@x_base64) == {:ok, @x_num}
    assert UUID.from_base64(@x_base64_padding) == {:ok, @x_num}
    assert UUID.from_base64("asdf") == {:error, :badarg}
  end
end
