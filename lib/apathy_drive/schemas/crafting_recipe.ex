defmodule ApathyDrive.CraftingRecipe do
  use ApathyDriveWeb, :model
  alias ApathyDrive.{Character, CraftingRecipe, Item, ItemInstance, Material, Room, Skill}

  schema "crafting_recipes" do
    field(:level, :integer)
    field(:material_amount, :integer)
    field(:type, :string)
    field(:armour_type, :string)
    field(:worn_on, :string)
    field(:weapon_type, :string)
    field(:weight, :integer)
    field(:speed, :integer)
    field(:cost_value, :integer)
    field(:cost_currency, :string)

    belongs_to(:material, Material)
    belongs_to(:skill, Skill)
  end

  def for_item(%Item{level: nil}), do: nil

  def for_item(%Item{type: "Armour"} = item) do
    __MODULE__
    |> where([r], r.type == "Armour")
    |> where([r], r.level == ^item.level)
    |> where([r], r.armour_type == ^item.armour_type)
    |> where([r], r.worn_on == ^item.worn_on)
    |> select([r], r)
    |> Repo.one()
  end

  def for_item(%Item{type: "Weapon"} = item) do
    __MODULE__
    |> where([r], r.type == "Weapon")
    |> where([r], r.level == ^item.level)
    |> where([r], r.weapon_type == ^item.weapon_type)
    |> where([r], r.worn_on == ^item.worn_on)
    |> select([r], r)
    |> Repo.one()
  end

  def drop_loot_for_character(%Room{} = room, %Character{level: level} = character) do
    count =
      __MODULE__
      |> where([mi], mi.level == ^level)
      |> select([mi], count(mi.id))
      |> Repo.one()

    item =
      __MODULE__
      |> where([mi], mi.level == ^level)
      |> offset(fragment("floor(random()*?) LIMIT 1", ^count))
      |> select([mi], mi)
      |> Repo.one()
      |> case do
        %CraftingRecipe{type: "Armour"} = mi ->
          count =
            Item
            |> where([i], i.type == ^mi.type)
            |> where([i], i.armour_type == ^mi.armour_type)
            |> where([i], i.worn_on == ^mi.worn_on)
            |> select([i], count(i.id))
            |> Repo.one()

          Item
          |> where([i], i.type == ^mi.type)
          |> where([i], i.armour_type == ^mi.armour_type)
          |> where([i], i.worn_on == ^mi.worn_on)
          |> offset(fragment("floor(random()*?) LIMIT 1", ^count))
          |> select([i], i)
          |> Repo.one()
          |> Map.put(:level, mi.level)

        %CraftingRecipe{type: "Weapon"} = mi ->
          count =
            Item
            |> where([i], i.type == ^mi.type)
            |> where([i], i.weapon_type == ^mi.weapon_type)
            |> where([i], i.worn_on == ^mi.worn_on)
            |> select([i], count(i.id))
            |> Repo.one()

          Item
          |> where([i], i.type == ^mi.type)
          |> where([i], i.weapon_type == ^mi.weapon_type)
          |> where([i], i.worn_on == ^mi.worn_on)
          |> offset(fragment("floor(random()*?) LIMIT 1", ^count))
          |> select([i], i)
          |> Repo.one()
          |> Map.put(:level, mi.level)
      end

    %ItemInstance{
      item_id: item.id,
      room_id: room.id,
      level: item.level,
      character_id: nil,
      dropped_for_character_id: character.id,
      equipped: false,
      hidden: false,
      delete_at: Timex.shift(DateTime.utc_now(), hours: 1)
    }
    |> Repo.insert!()

    room
  end
end
