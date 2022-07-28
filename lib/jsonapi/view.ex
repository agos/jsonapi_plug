defmodule JSONAPI.View do
  @moduledoc """
  A View is simply a module that defines certain callbacks to configure proper
  rendering of your JSONAPI documents.

      defmodule MyApp.PostsView do
        alias MyApp.{CommentsView, UsersView}

        use JSONAPI.View,
          type: "post",
          attributes: [:id, :text, :body]
          relationships: [
            author: [view: UsersView],
            comments: [many: true, view: CommentsView]
          ]
      end

      defmodule MyApp.UsersView do
        use JSONAPI.View,
          type: "user",
          attributes: [:id, :username]
      end

      defmodule MyApp.CommentView do
        alias MyApp.UsersView

        use JSONAPI.View,
          type: "comment,
          attributes: [:id, :text]
          relationships: [user: [view: UsersView]]
      end

      defmodule MyApp.DogView do
        use JSONAPI.View, type: "dog"
      end

  You can now call `UsersView.render(user, conn)` or `View.render(UsersView, user, conn)`
  to render a valid JSON:API document from your data. If you use phoenix, you can use:

    conn
    |> put_view(UsersView)
    |> render("show.json", %{data: data, conn: conn, meta: meta, options: options})

  in your controller code to render the document in the same way.

  ## Fields

  By default, the resulting JSON document consists of attributes, defined in the `attributes/0`
  function. You can define custom attributes or override attributes by defining a
  2-arity function inside the view that takes `resource` and `conn` as arguments and has
  the same name as the field it will be producing:

      defmodule MyApp.UserView do
        use JSONAPI.View,
          type: "user",
          attributes: [:id, :username, :fullname]

        def fullname(resource, conn), do: "\#{resouce.first_name} \#{resource.last_name}"
      end

  ## Relationships

  The relationships callback expects that a keyword list is returned
  configuring the information you will need. If you have the following Ecto
  Model setup

      defmodule User do
        schema "users" do
          field :username
          has_many :posts
          belongs_to :image
        end
      end

  and the includes setup from above. If your Post has loaded the author and the
  query asks for it then it will be loaded.

  So for example:
  `GET /posts?include=post.author` if the author record is loaded on the Post, and you are using
  the `JSONAPI.Plug.Request` it will be included in the `included` section of the JSONAPI document.

  When rendering resource links, the default behaviour is to is to derive values for `host`, `port`
  and `scheme` from the connection. You can override them via your application configuration.
  """

  alias JSONAPI.{API, Document, Document.ErrorObject, Resource, Resource}
  alias Plug.Conn

  @type t :: module()
  @type options :: keyword()
  @type data :: Resource.t() | [Resource.t()]
  @type attribute_options :: [
          name: Resource.field(),
          serialize: boolean() | (Resource.t(), Conn.t() -> term()),
          deserialize: boolean() | (Resource.t(), Conn.t() -> term())
        ]
  @type relationship_options :: [many: boolean(), name: Resource.field(), view: t()]
  @type attribute :: Resource.field() | {Resource.field(), attribute_options()}
  @type relationship :: {Resource.field(), relationship_options()}
  @type field :: attribute() | relationship()

  @callback id(Resource.t()) :: Resource.id()
  @callback id_attribute :: Resource.field()
  @callback attributes :: [attribute()]
  @callback links(Resource.t(), Conn.t() | nil) :: Document.links()
  @callback meta(Resource.t(), Conn.t() | nil) :: Document.meta()
  @callback path :: String.t() | nil
  @callback relationships :: [relationship()]
  @callback type :: Resource.type()

  defmacro __using__(options \\ []) do
    {attributes, options} = Keyword.pop(options, :attributes, [])
    {id_attribute, options} = Keyword.pop(options, :id_attribute, :id)
    {path, options} = Keyword.pop(options, :path)
    {relationships, options} = Keyword.pop(options, :relationships, [])
    {type, _options} = Keyword.pop(options, :type)

    unless type do
      raise "You must pass the :type option to JSONAPI.View"
    end

    quote do
      @behaviour JSONAPI.View

      @impl JSONAPI.View
      def id(resource) do
        case Map.fetch(resource, unquote(id_attribute)) do
          {:ok, id} -> to_string(id)
          :error -> raise "Resources must have an id defined"
        end
      end

      @impl JSONAPI.View
      def id_attribute, do: unquote(id_attribute)

      @impl JSONAPI.View
      def attributes, do: unquote(attributes)

      @impl JSONAPI.View
      def links(_resource, _conn), do: %{}

      @impl JSONAPI.View
      def meta(_resource, _conn), do: %{}

      @impl JSONAPI.View
      def path, do: unquote(path)

      @impl JSONAPI.View
      def relationships, do: unquote(relationships)

      @impl JSONAPI.View
      def type, do: unquote(type)

      defoverridable JSONAPI.View

      def render(action, assigns)
          when action in ["create.json", "index.json", "show.json", "update.json"] do
        JSONAPI.View.render(
          __MODULE__,
          Map.get(assigns, :data),
          Map.get(assigns, :conn),
          Map.get(assigns, :meta),
          Map.get(assigns, :options)
        )
      end

      def render(action, _assigns) do
        raise "invalid action #{action}, use one of create.json, index.json, show.json, update.json"
      end
    end
  end

  @spec field_name(field()) :: Resource.field()
  def field_name(field) when is_atom(field), do: field
  def field_name({name, nil}), do: name
  def field_name({name, options}) when is_list(options), do: name

  def field_name(field),
    do: raise("invalid field definition: #{inspect(field)}")

  @spec field_option(field(), atom(), term()) :: term()
  def field_option(name, _option, default) when is_atom(name), do: default

  def field_option({_name, nil}, _option, default), do: default

  def field_option({_name, options}, option, default) when is_list(options),
    do: Keyword.get(options, option, default)

  def field_option(field, _option, _default),
    do: raise("invalid field definition: #{inspect(field)}")

  @spec for_related_type(t(), Resource.type()) :: t() | nil
  def for_related_type(view, type) do
    Enum.find_value(view.relationships(), fn {_relationship, options} ->
      relationship_view = Keyword.fetch!(options, :view)

      if relationship_view.type() == type do
        relationship_view
      else
        nil
      end
    end)
  end

  @spec render(t(), data() | nil, Conn.t() | nil, Document.meta() | nil, options()) ::
          Document.t()
  def render(view, data \\ nil, conn \\ nil, meta \\ nil, options \\ []),
    do: Document.serialize(%Document{data: data, meta: meta}, view, conn, options)

  @spec send_error(Conn.t(), Conn.status(), [ErrorObject.t()]) :: Conn.t()
  def send_error(conn, status, errors) do
    conn
    |> Conn.update_resp_header("content-type", JSONAPI.mime_type(), & &1)
    |> Conn.send_resp(
      status,
      Jason.encode!(%Document{
        errors:
          Enum.map(errors, fn %ErrorObject{} = error ->
            code = Conn.Status.code(status)
            %ErrorObject{error | status: to_string(code), title: Conn.Status.reason_phrase(code)}
          end)
      })
    )
    |> Conn.halt()
  end

  @spec url_for_relationship(t(), Resource.t(), Conn.t() | nil, Resource.type()) :: String.t()
  def url_for_relationship(view, resource, conn, relationship_type) do
    Enum.join([url_for(view, resource, conn), "relationships", relationship_type], "/")
  end

  @spec url_for(t(), data() | nil, Conn.t() | nil) :: String.t()
  def url_for(view, resource, conn) when is_nil(resource) or is_list(resource) do
    conn
    |> render_uri([view.path() || view.type()])
    |> to_string()
  end

  def url_for(view, resource, conn) do
    conn
    |> render_uri([view.path() || view.type(), view.id(resource)])
    |> to_string()
  end

  defp render_uri(%Conn{} = conn, path) do
    %URI{
      scheme: scheme(conn),
      host: host(conn),
      path: Enum.join([namespace(conn) | path], "/"),
      port: port(conn)
    }
  end

  defp render_uri(_conn, path), do: %URI{path: "/" <> Enum.join(path, "/")}

  defp scheme(%Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}, scheme: scheme}),
    do: to_string(API.get_config(jsonapi.api, :scheme, scheme))

  defp scheme(_conn), do: nil

  defp host(%Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}, host: host}),
    do: API.get_config(jsonapi.api, :host, host)

  defp host(_conn), do: nil

  defp namespace(%Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}}) do
    case API.get_config(jsonapi.api, :namespace) do
      nil -> ""
      namespace -> "/" <> namespace
    end
  end

  defp namespace(_conn), do: ""

  defp port(%Conn{private: %{jsonapi: %JSONAPI{} = jsonapi}, port: port} = conn) do
    case API.get_config(jsonapi.api, :port, port) do
      nil -> nil
      port -> if port == URI.default_port(scheme(conn)), do: nil, else: port
    end
  end

  defp port(_conn), do: nil
end
