defmodule Neuryt.Mixfile do
  use Mix.Project

  def project do
    [app: :neuryt,
     version: "0.1.0",
     elixir: "~> 1.3",
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :disc_union, :jobs, :gproc],
     mod: {Neuryt, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:disc_union, github: "x4lldux/disc_union"},
      {:gproc, "~> 0.6.1"},
      {:jobs, github: "uwiger/jobs"},
      {:uuid, "~> 1.1"},

      {:credo, "~> 0.4", only: [:dev, :test]},
      {:dialyxir, "~> 0.3.5", only: [:test, :dev]},
      {:excoveralls, "~> 0.5", only: :test},
    ]
  end
end
