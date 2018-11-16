defmodule ApathyDrive.Commands.Forget do
  use ApathyDrive.Command
  alias ApathyDrive.{Ability, Character, CharacterAbility, Match, Repo, Room}

  def keywords, do: ["deactivate"]

  def execute(%Room{} = room, %Character{} = character, []) do
    message = "<p><span class='red'>Syntax: FORGET {ability}</span></p>"
    Mobile.send_scroll(character, message)

    room
  end

  def execute(%Room{} = room, %Character{} = character, args) do
    ability = Enum.join(args, " ")

    character.abilities
    |> Map.values()
    |> Match.one(:name_contains, ability)
    |> case do
      %Ability{} = ability ->
        deactivate_ability(room, character, ability)

      nil ->
        message = "<p><span class='red'>Syntax: FORGET {ability}</span></p>"
        Mobile.send_scroll(character, message)

        room
    end
  end

  defp deactivate_ability(room, character, ability) do
    Room.update_mobile(room, character.ref, fn character ->
      if character_ability =
           Repo.get_by(CharacterAbility, character_id: character.id, ability_id: ability.id) do
        message = "<p>You no longer know how to use #{ability.name}!</p>"

        Mobile.send_scroll(character, message)

        Repo.delete!(character_ability)

        Character.load_abilities(character)
      else
        message = "<p>You cannot forget an ability granted by an equipped item.</p>"

        Mobile.send_scroll(character, message)
        character
      end
    end)
  end
end