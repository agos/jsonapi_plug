defmodule JSONAPI.QueryParser.Ecto.Filter do
  @moduledoc """
  JSON:API 'filter' query parameter normalizer implementation for Ecto

  Defaults to returning the value of 'filter' as is, raises otherwise.
  """

  alias JSONAPI.QueryParser

  @behaviour QueryParser

  @impl QueryParser
  def parse(%JSONAPI{filter: filter}, nil), do: filter
  def parse(_jsonapi, filter), do: filter
end
