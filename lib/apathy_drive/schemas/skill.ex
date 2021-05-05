defmodule ApathyDrive.Skill do
  use ApathyDriveWeb, :model
  alias ApathyDrive.{CharacterSkill, Match}

  schema "skills" do
    field(:name, :string)
    field(:description, :string)
    field(:exp_multiplier, :float)
    field(:universal, :boolean, default: false)

    field(:attributes, :any, virtual: true, default: [])

    has_many(:characters_skills, CharacterSkill)
    has_many(:characters, through: [:characters_skills, :character])
  end

  def create_changeset(name) do
    %__MODULE__{}
    |> cast(%{name: name}, ~w(name))
    |> validate_required(:name)
    |> validate_format(:name, ~r/^[a-zA-Z\d ,\-']+$/)
    |> validate_length(:name, min: 1, max: 20)
    |> unique_constraint(:name)
  end

  def match_by_name(name, all \\ false) do
    skills =
      __MODULE__
      |> where([skill], not is_nil(skill.name) and skill.name != "")
      |> distinct(true)
      |> select([area], [:id, :name])
      |> ApathyDrive.Repo.all()

    if all do
      Match.all(skills, :keyword_starts_with, name)
    else
      Match.one(skills, :keyword_starts_with, name)
    end
  end
end
