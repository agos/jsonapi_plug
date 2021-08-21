defmodule JSONAPI.Resource do
  @moduledoc """
  JSONAPI Resource

  `JSONAPI.Resource` relies on the `JSONAPI.Resource.Identifiable` and `JSONAPI.Resource.Serializable`
  protocols to provide Resource related functionality.
  """

  alias JSONAPI.Resource.{Identifiable, Loadable, NotLoaded, Serializable}
  alias JSONAPI.{Document, Resource, View}

  @typedoc "Resource"
  @type t :: struct()

  @typedoc "Resource ID"
  @type id :: String.t()

  @typedoc "Resource field"
  @type field :: atom()

  @typedoc "Resource Type"
  @type type :: String.t()

  @doc """
  Resource id

  Returns the JSON:API Resource ID
  """
  @spec id(Resource.t()) :: Resource.id()
  def id(resource) do
    case Map.fetch(resource, Identifiable.id_attribute(resource)) do
      {:ok, id} -> to_string(id)
      :error -> raise "Resources must have and id_attribute defined"
    end
  end

  @doc """
  Resource type

  Returns the JSON:API Resource Type
  """
  @spec type(t()) :: id()
  def type(resource), do: to_string(Identifiable.type(resource))

  @doc """
  Resource type

  Returns the JSON:API Resource Attributes
  """
  @spec attributes(t()) :: [field()]
  def attributes(resource), do: Serializable.attributes(resource)

  @spec deserialize(t(), Document.payload(), [t()]) :: t()
  def deserialize(resource, %{"id" => id} = data, included) do
    resource
    |> struct(Keyword.put([], Identifiable.id_attribute(resource), id))
    |> deserialize_attributes(data)
    |> deserialize_relationships(data, included)
  end

  defp deserialize_attributes(resource, %{"attributes" => attributes}) do
    struct(resource, JSONAPI.transform_fields(attributes))
  end

  defp deserialize_attributes(resource, _data), do: resource

  defp deserialize_relationships(resource, %{"relationships" => relationships}, included)
       when is_list(relationships) do
    struct(resource, Enum.map(relationships, &deserialize_relationship(&1, included)))
  end

  defp deserialize_relationships(resource, _data, _included), do: resource

  defp deserialize_relationship({relationship, data}, included) when is_list(data) do
    {JSONAPI.transform_fields(relationship),
     Enum.map(data, &deserialize_relationship(&1, included))}
  end

  defp deserialize_relationship(
         {relationship, %{"data" => %{"id" => id, "type" => type}}},
         included
       ) do
    resource =
      case Enum.find(included, fn resource ->
             id == Resource.id(resource) && type == Resource.type(resource)
           end) do
        nil -> %NotLoaded{id: id, type: type}
        resource -> resource
      end

    {JSONAPI.transform_fields(relationship), resource}
  end

  @doc """
  Resource type

  Returns the JSON:API Resource One-to-One relationships
  """
  @spec has_one(t()) :: [{field(), View.t()}]
  def has_one(resource),
    do: Serializable.has_one(resource)

  @doc """
  Resource type

  Returns the JSON:API Resource One-to-Many relationships
  """
  @spec has_many(t()) :: [{field(), View.t()}]
  def has_many(resource),
    do: Serializable.has_many(resource)

  @doc """
  Resource loaded

  Returns a boolean indicating wether the given Resource is loaded
  """
  @spec loaded?(t()) :: boolean()
  def loaded?(resource), do: Loadable.loaded?(resource)
end
