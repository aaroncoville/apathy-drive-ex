defmodule ApathyDrive.LimbSet do
  use ApathyDriveWeb, :model
  alias ApathyDrive.{LimbSet, LimbSetLimb}

  schema "limb_sets" do
    field(:name, :string)

    has_many(:limb_set_limbs, LimbSetLimb)
  end

  @required_fields ~w(name)a

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(%LimbSet{} = race, attrs \\ %{}) do
    race
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> cast_assoc(:limb_sets)
  end

  def load_limbs(limb_set_id) do
    LimbSetLimb
    |> where(limb_set_id: ^limb_set_id)
    |> preload(:limb)
    |> Repo.all()
    |> Enum.reduce(%{}, fn limb, limbs ->
      limb_name =
        [limb.location, limb.limb.type]
        |> Enum.reject(&is_nil/1)
        |> Enum.join(" ")

      limb = %{
        health: 1.0
      }

      Map.put(limbs, limb_name, limb)
    end)
  end
end
