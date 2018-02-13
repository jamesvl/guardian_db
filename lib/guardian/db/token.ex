defmodule Guardian.DB.Token do
  @moduledoc """
  A very simple model for storing tokens generated by guardian.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [where: 3]

  alias Guardian.DB.Token

  @primary_key {:jti, :string, autogenerate: false}
  @allowed_fields ~w(jti typ aud iss sub exp jwt claims)a

  schema "virtual: token" do
    field(:typ, :string)
    field(:aud, :string)
    field(:iss, :string)
    field(:sub, :string)
    field(:exp, :integer)
    field(:jwt, :string)
    field(:claims, :map)

    timestamps()
  end

  @doc """
  Find one token by matching jti and aud
  """
  def find_by_claims(claims) do
    jti = Map.get(claims, "jti")
    aud = Map.get(claims, "aud")

    query =
      query_schema()
      |> where([token], token.jti == ^jti and token.aud == ^aud)
      |> Map.put(:prefix, prefix())

    Guardian.DB.repo().one(query)
  end

  @doc """
  Create a new new token based on the JWT and decoded claims
  """
  def create(claims, jwt) do
    prepared_claims =
      claims
      |> Map.put("jwt", jwt)
      |> Map.put("claims", claims)

    %Token{}
    |> Ecto.put_meta(source: schema_name())
    |> Ecto.put_meta(prefix: prefix())
    |> cast(prepared_claims, @allowed_fields)
    |> Guardian.DB.repo().insert()
  end

  @doc """
  Purge any tokens that are expired. This should be done periodically to keep your DB table clean of clutter
  """
  def purge_expired_tokens do
    timestamp = Guardian.timestamp()

    query_schema()
    |> where([token], token.exp < ^timestamp)
    |> Guardian.DB.repo().delete_all(prefix: prefix())
  end

  @doc false
  def query_schema do
    {schema_name(), Token}
  end

  @doc false
  def schema_name do
    :guardian
    |> Application.fetch_env!(Guardian.DB)
    |> Keyword.get(:schema_name, "guardian_tokens")
  end

  @doc false
  def prefix do
    :guardian
    |> Application.fetch_env!(Guardian.DB)
    |> Keyword.get(:prefix, nil)
  end
end
