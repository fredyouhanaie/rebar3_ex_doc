defmodule RebarHexDoc.MixProject do
  use Mix.Project

  def project do
    [
      app: :rebar_hex_doc,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: ExDoc.CLI, name: "ex_doc", path: "priv/ex_doc"],
      docs: [main: "readme", # The main page in the docs
          extras: ["README.md"]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: []
    ]
  end

  defp deps do
    [
      {:ex_doc, "0.26.0"}
    ]
  end


end
