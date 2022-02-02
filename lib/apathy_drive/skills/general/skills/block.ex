defmodule ApathyDrive.Skills.Block do
  alias ApathyDrive.{Ability, Mobile, Skill}
  use ApathyDrive.Skill

  def ability(character) do
    %Ability{
      kind: "passive",
      targets: "self",
      name: "Block",
      attributes: ["strength"],
      traits: %{
        "Block" => skill_level(character)
      }
    }
  end

  def help(character, skill) do
    Mobile.send_scroll(character, "<p class='item'>#{tooltip(character, skill)}</p>")
  end

  def tooltip(_character, _skill) do
    """
      <span style="color: lime">Block</span>
      Blocking lets you deflect enemy attacks with a shield.

      Attribute(s): #{attributes()}
    """
  end
end
