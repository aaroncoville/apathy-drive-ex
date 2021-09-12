defmodule ApathyDrive.Skills.BladeMastery do
  alias ApathyDrive.{Ability, Character, Mobile, Skill}
  use ApathyDrive.Skill

  def ability(_character) do
    %Ability{
      kind: "mastery",
      targets: "self",
      name: "Blade Mastery",
      attributes: ["strength", "agility"],
      traits: %{}
    }
  end

  def help(character, skill) do
    Mobile.send_scroll(character, "<p class='item'>#{tooltip(character, skill)}</p>")
  end

  def tooltip(character, skill) do
    """
      <span style="color: lime">Blade Mastery</span>
      Increases combat proficiency with all manner of bladed weapons.
      Attribute(s): #{attributes()}
      #{current_skill_level(character)}#{next_skill_level(character, skill)}
    """
  end

  defp current_skill_level(character) do
    level = skill_level(character)

    if level > 0 do
      """
      \nCurrent Skill Level: #{level}
      Proficiency: #{proficiency(level)}
      """
    end
  end

  defp next_skill_level(character, skill) do
    level = skill_level(character) + 1

    if level <= skill.max_level do
      "\nNext Skill Level: #{level}\n#{required_level(character.level)}#{prereq(character, level)}Proficiency: #{proficiency(level)}"
    end
  end

  defp proficiency(level) do
    trunc(1 + 0.67 * level)
    |> Character.combat_proficiency()
  end
end
