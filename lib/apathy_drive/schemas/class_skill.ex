defmodule ApathyDrive.ClassSkill do
  use ApathyDriveWeb, :model
  alias ApathyDrive.{Class, Skill}

  schema "classes_skills" do
    belongs_to(:class, Class)
    belongs_to(:skill, Skill)
  end

  def load_skills(class_id) do
    __MODULE__
    |> where([mt], mt.class_id == ^class_id)
    |> preload(:skill)
    |> Repo.all()
    |> Enum.reduce([], fn %{skill: skill}, skills ->
      [%{skill_id: skill.id, name: skill.name} | skills]
    end)
  end
end
