defmodule JSONAPI.Mixfile do
  use Mix.Project

  def project do
    [
      app: :jsonapi,
      version: "1.4.0",
      package: package(),
      description: "JSON:API library for Plug based applications",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/lucacorti/jsonapi",
      deps: deps(),
      dialyzer: dialyzer(),
      docs: docs()
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_deps: :app_tree
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.20", only: :dev, runtime: false},
      {:jason, "~> 1.0"},
      {:nimble_options, "~> 0.4"},
      {:plug, "~> 1.0"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      groups_for_modules: [
        Plugs: [~r/JSONAPI\.Plug\..*/],
        Document: [~r/JSONAPI\.Document\..*/],
        Ecto: [~r/JSONAPI\.(Normalizer|QueryParser)\..*/]
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Luca Corti"],
      licenses: ["MIT"],
      links: %{
        github: "https://github.com/lucacorti/jsonapi"
      }
    ]
  end
end
