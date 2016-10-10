# Neuryt

Semi-opinionated CQRS+ES framework.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `neuryt` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:neuryt, "~> 0.1.0"}]
    end
    ```

  2. Ensure `neuryt` is started before your application:

    ```elixir
    def application do
      [applications: [:neuryt]]
    end
    ```
