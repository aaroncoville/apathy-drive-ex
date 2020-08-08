defmodule ApathyDrive.Commands.Status do
  use ApathyDrive.Command
  alias ApathyDrive.{Character, Mobile}

  def keywords, do: ["st", "stat", "status"]

  def execute(%Room{} = room, %Character{} = character, []) do
    status(character)

    room
  end

  def status(character) do
    hp = Character.hp_at_level(character, character.level)
    max_hp = Mobile.max_hp_at_level(character, character.level)

    mp = Character.mana_at_level(character, character.level)
    max_mp = Mobile.max_mana_at_level(character, character.level)

    powerstone =
      Enum.reduce(character.inventory, 0, fn item, powerstone ->
        if "create powerstone" in item.enchantments do
          item.max_uses + powerstone
        else
          powerstone
        end
      end)

    max_mp = max_mp + powerstone

    max_level =
      case character.classes do
        [] ->
          1

        classes ->
          classes
          |> Enum.map(& &1.level)
          |> Enum.max()
      end

    classes = character.classes

    target_count = length(classes)

    {exp, time_to_level} =
      if Enum.any?(classes) do
        classes
        |> Enum.map(fn character_class ->
          exp_to_level =
            ApathyDrive.Commands.Train.required_experience(
              character,
              character_class.class_id,
              character_class.level + 1
            )

          class_drain_rate = Character.drain_rate(character_class.level)
          max_drain_rate = Character.drain_rate(max_level)

          drain_rate = min(class_drain_rate, max_drain_rate / target_count)

          {max(0, exp_to_level), max(0, trunc(exp_to_level / drain_rate))}
        end)
        |> Enum.min_by(fn {_exp_to_level, time_to_level} -> time_to_level end, fn -> {0, 0} end)
      else
        {0, 0}
      end

    ttl = ApathyDrive.Enchantment.formatted_time_left(time_to_level)

    Mobile.send_scroll(
      character,
      "<p><span class='cyan'>hp:</span> <span class='white'>#{hp}/#{max_hp}</span> " <>
        "<span class='cyan'>mana:</span> <span class='white'>#{mp}/#{max_mp}</span> " <>
        "<span class='cyan'>experience:</span> <span class='white'>#{trunc(exp)} (#{ttl})</span> " <>
        "<span class='cyan'>mind:</span> #{mind(character)}"
    )
  end

  def mind(character) do
    max_buffer = character.max_exp_buffer
    buffer = character.exp_buffer

    percent = buffer / max_buffer

    cond do
      percent < 0.05 ->
        "<span class='white'>clear</span>"

      percent < 0.25 ->
        "<span class='white'>almost clear</span>"

      percent < 0.5 ->
        "<span class='white'>slightly fuzzy</span>"

      percent < 0.75 ->
        "<span class='white'>clouded</span>"

      percent < 0.90 ->
        "<span class='white'>very fuzzy</span>"

      :else ->
        "<span class='magenta'>full of facts</span>"
    end
  end
end
