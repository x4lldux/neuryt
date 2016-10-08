defmodule Neuryt.UUID do
  @moduledoc """
  Module for generating and converting universally unique IDs.

  Base representation is numeric (bignum), but can also be 128bit binary.
  """

  @type integer_id :: non_neg_integer
  @type binary_id ::  <<_::128>>
  @type t :: integer_id

  @doc """
  Generates new UUID in numeric representation.
  """
  @spec new() :: integer_id
  def new do
    UUID.uuid4
    |> UUID.string_to_binary!
    |> :binary.decode_unsigned
  end

  @doc """
  Converts to binary representation.
  """
  @spec to_binary(integer_id) :: binary_id
  def to_binary(uuid) when is_integer(uuid) do
    uuid |> :binary.encode_unsigned
  end

  @doc """
  Converts UUID from binary representation to numeric.
  """
  @spec from_binary(binary_id) :: {:ok, integer_id} | {:error, :badarg}
  def from_binary(uuid) when is_binary(uuid) and byte_size(uuid) == 16 do
    try do
      {:ok, uuid |> :binary.decode_unsigned}
    rescue
      ArgumentError -> {:error, :badarg}
    end
  end
  def from_binary(_), do: {:error, :badarg}

  @doc """
  Converts UUID to string format.

  One of three formats can be specified optionally: `:default`, `:hex`, `:urn`.
  """
  @spec to_string(integer_id | binary_id, :default | :hex | :urn) :: String.t
  def to_string(uuid, format \\ :default)
  def to_string(uuid, format) when is_integer(uuid) do
    uuid
    |> to_binary
    |> to_string(format)
  end
  def to_string(uuid, format) when is_binary(uuid) and byte_size(uuid)==16 do
    uuid
    |> UUID.binary_to_string!(format)
  end

  @doc """
  Converts from string format to UUID in integer representation.
  """
  @spec from_string(String.t) :: {:ok, integer_id} | {:error, :badarg}
  def from_string(uuid) when is_binary(uuid) do
    try do
      uuid
      |> UUID.string_to_binary!
      |> from_binary
    rescue
      ArgumentError -> {:error, :badarg}
    end
  end
  def from_string(_), do: {:error, :badarg}

  @doc """
  Converts to URL friendly base64 format (without padding).
  """
  @spec to_base64(integer_id | binary_id) :: String.t
  def to_base64(uuid) when is_integer(uuid) do
    uuid
    |> to_binary
    |> to_base64
  end
  def to_base64(uuid) when is_binary(uuid) and byte_size(uuid)==16 do
    uuid |> Base.url_encode64(padding: false)
  end

  @doc """
  Converts from URL friendly base64 format to UUID in numeric representation.
  """
  @spec from_base64(String.t) :: {:ok, integer_id} | {:error, :badarg}
  def from_base64(uuid) do
    with {:ok, bin_id}  <- Base.url_decode64(uuid, ignore: :whitespace,
              padding: false),
         {:ok, id} <- from_binary(bin_id)
      do
        {:ok, id}
      else
        :error -> {:error, :badarg}
        {:error, _} -> {:error, :badarg}
    end
  end
end
