defmodule ApathyDrive.Skills.CureBlindness do
  alias ApathyDrive.{Ability, Character, Mobile, Skill}
  use ApathyDrive.Skill

  def prereq(), do: ApathyDrive.Skills.MinorHealing

  def ability(%Character{} = character) do
    level = skill_level(character)

    %Ability{
      kind: "util",
      command: "site",
      targets: "self or single",
      energy: 600,
      name: "cure blindness",
      attributes: ["willpower"],
      mana: mana(level),
      auto: !!get_in(character, [:skills, "site", :auto]),
      spell?: true,
      user_message: "You cast cure blindness on {{target}}!",
      target_message: "{{user}} casts cure blindness upon you!",
      spectator_message: "{{user}} casts cure blindness on {{target}}!",
      traits: %{
        "DispelMagic" => 107
      }
    }
  end

  def help(character, skill) do
    Mobile.send_scroll(character, "<p class='item'>#{tooltip(character, skill)}</p>")
  end

  def tooltip(character, _skill) do
    """
      <span style="color: lime">#{name()}</span>
      This spell restores sight to those who have been blinded.
      Attribute(s): #{attributes()}
      #{current_skill_level(character)}
    """
  end

  defp current_skill_level(character) do
    level = skill_level(character)

    if level > 0 do
      """
      \nCurrent Skill Level: #{level}
      Cures Blindness
      Mana Cost: #{mana(level)}
      """
    end
  end

  defp mana(_level), do: 12
end
