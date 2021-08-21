defmodule JSONAPI.Deserializer do
  @moduledoc """
  This plug flattens incoming params for ease of use when casting to changesets.
  As a result, you are able to pattern match specific attributes in your controller
  actions.

  Note that this Plug will only deserialize your payload when the request's content
  type is for a JSON:API request (i.e. "application/vnd.api+json"). All other
  content types will be ignored.

  ## Example

  For example these params:
      %{
        "data" => %{
          "id" => "1",
          "type" => "user",
          "attributes" => %{
            "foo-bar" => true
          },
          "relationships" => %{
            "baz" => %{"data" => %{"id" => "2", "type" => "baz"}}
          }
        }
      }

  are transformed to:

      %{
        "id" => "1",
        "type" => "user"
        "foo-bar" => true,
        "baz-id" => "2"
      }

  ## Usage

  Just include in your plug stack _after_ a json parser:
      plug Plug.Parsers, parsers: [:json], json_decoder: Jason
      plug JSONAPI.Deserializer

  or a part of your Controller plug pipeline
      plug JSONAPI.Deserializer

  In addition, if you want to underscore your parameters
      plug JSONAPI.Deserializer
      plug JSONAPI.UnderscoreParameters
  """

  alias JSONAPI.Document
  alias Plug.Conn

  @spec init(Keyword.t()) :: Keyword.t()
  def init(opts), do: opts

  @spec call(Conn.t(), Keyword.t()) :: Conn.t()
  def call(%Conn{} = conn, _opts) do
    conn =
      if JSONAPI.mime_type() in Conn.get_req_header(conn, "content-type") do
        %Conn{conn | params: process(conn.params)}
      else
        conn
      end

    case Document.deserialize(conn) do
      {:ok, document} ->
        Conn.assign(conn, :jsonapi_data, document)

      {:error, _reason} ->
        conn
    end
  end

  def call(conn, _opts), do: conn

  @spec process(map()) :: map()
  def process(%{"data" => nil}), do: nil

  def process(%{"data" => _} = incoming) do
    incoming
    |> flatten_incoming()
    |> process_included()
    |> process_relationships()
    |> process_attributes()
  end

  def process(incoming), do: incoming

  defp flatten_incoming(%{"data" => data}) when is_list(data),
    do: data

  defp flatten_incoming(%{"data" => data} = incoming) when is_map(data) do
    incoming
    |> Map.merge(data)
    |> Map.drop(["data"])
  end

  defp process_attributes(%{"attributes" => nil} = data) do
    Map.drop(data, ["attributes"])
  end

  defp process_attributes(%{"attributes" => attributes} = data) do
    data
    |> Map.merge(attributes)
    |> Map.drop(["attributes"])
  end

  defp process_attributes(data), do: data

  defp process_relationships(%{"relationships" => nil} = data),
    do: Map.drop(data, ["relationships"])

  defp process_relationships(%{"relationships" => relationships} = data) do
    relationships
    |> Enum.reduce(%{}, &transform_relationship/2)
    |> Map.merge(data)
    |> Map.drop(["relationships"])
  end

  defp process_relationships(data), do: data

  defp transform_relationship({relationship, %{"data" => nil}}, acc),
    do: Map.put(acc, JSONAPI.transform_fields("#{relationship}-id"), nil)

  defp transform_relationship({relationship, %{"data" => %{"id" => id}}}, acc),
    do: Map.put(acc, JSONAPI.transform_fields("#{relationship}-id"), id)

  defp transform_relationship({_relationship, %{"data" => data}}, acc) when is_list(data) do
    Enum.reduce(data, acc, fn %{"id" => id, "type" => type}, inner_acc ->
      {_val, new_map} =
        Map.get_and_update(
          inner_acc,
          JSONAPI.transform_fields("#{type}-id"),
          &update_list_relationship(&1, id)
        )

      new_map
    end)
  end

  defp update_list_relationship(value, id) when is_list(value), do: {value, [id | value]}
  defp update_list_relationship(value, id) when is_binary(value), do: {value, [value, id]}
  defp update_list_relationship(_value, id), do: {nil, id}

  defp process_included(%{"included" => nil} = incoming),
    do: Map.drop(incoming, ["included"])

  defp process_included(%{"included" => included} = incoming) do
    included
    |> Enum.reduce(incoming, fn %{"data" => %{"type" => type}} = params, acc ->
      flattened = process(params)

      if Map.has_key?(acc, type) do
        Map.update(acc, type, flattened, &[flattened | &1])
      else
        Map.put(acc, type, [flattened])
      end
    end)
    |> Map.drop(["included"])
  end

  defp process_included(incoming), do: incoming
end
