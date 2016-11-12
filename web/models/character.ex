defmodule ApathyDrive.Character do
  use Ecto.Schema
  use ApathyDrive.Web, :model
  alias ApathyDrive.{Ability, Character, CharacterItem, Item, ItemAbility, Mobile, Room, RoomServer, Spell, SpellAbility, Text, TimerManager}

  require Logger
  import Comeonin.Bcrypt

  schema "characters" do
    field :name,            :string
    field :gender,          :string
    field :email,           :string
    field :password,        :string
    field :external_id,     :string
    field :experience,      :integer, default: 0
    field :level,           :integer, default: 1
    field :timers,          :map, virtual: true, default: %{}
    field :admin,           :boolean
    field :flags,           :map, default: %{}
    field :gold,            :integer, default: 150
    field :monitor_ref,     :any, virtual: true
    field :ref,             :any, virtual: true
    field :socket,          :any, virtual: true
    field :effects,         :map, virtual: true, default: %{}
    field :last_effect_key, :integer, virtual: true, default: 0
    field :hp,              :float, virtual: true, default: 1.0
    field :mana,            :float, virtual: true, default: 1.0
    field :spells,          :map, virtual: true, default: %{}
    field :inventory,       :any, virtual: true, default: []
    field :equipment,       :any, virtual: true, default: []
    field :spell_shift,     :float, virtual: true
    field :attack_target,   :any, virtual: true

    belongs_to :room, Room
    belongs_to :class, ApathyDrive.Class
    belongs_to :race, ApathyDrive.Race

    has_many :characters_items, ApathyDrive.CharacterItem

    timestamps
  end

  @doc """
  Creates a changeset based on the `model` and `params`.

  If `params` are nil, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(character, params \\ %{}) do
    character
    |> cast(params, ~w(name race_id class_id gender), ~w())
    |> validate_inclusion(:class_id, ApathyDrive.Class.ids)
    |> validate_inclusion(:race_id, ApathyDrive.Race.ids)
    |> validate_inclusion(:gender, ["male", "female"])
    |> validate_format(:name, ~r/^[a-zA-Z]+$/)
    |> unique_constraint(:name, name: :characters_lower_name_index, on: Repo)
    |> validate_length(:name, min: 1, max: 12)
  end

  def sign_up_changeset(character, params \\ %{}) do
    character
    |> cast(params, ~w(email password), [])
    |> validate_format(:email, ~r/@/)
    |> validate_length(:email, min: 3, max: 100)
    |> validate_length(:password, min: 6)
    |> unique_constraint(:email, name: :characters_lower_email_index, on: Repo)
    |> validate_confirmation(:password)
  end

  def preload_spells(%Character{} = character) do
    character = character |> ApathyDrive.Repo.preload(class: [classes_spells: [spell: [spells_abilities: :ability]]])
    spells =
      Enum.reduce(character.class.classes_spells, %{}, fn
        %{level: level, spell: %Spell{spells_abilities: spells_abilities} = spell}, spells ->
          spell =
            put_in(spell.abilities, Enum.reduce(spells_abilities, %{}, fn %SpellAbility{ability: ability} = spell_ability, abilities ->
              Map.put(abilities, ability.name, spell_ability.value)
            end))
            |> Map.put(:level, level)
          Map.put(spells, spell.command, spell)
      end)
    Map.put(character, :spells, spells)
  end

  def preload_items(%Character{} = character) do
    character =
      character
      |> ApathyDrive.Repo.preload([characters_items: [item: [items_abilities: :ability]]], [force: true])
      |> Map.put(:inventory, [])
      |> Map.put(:equipment, [])

    Enum.reduce(character.characters_items, character, fn
      %{equipped: equipped, item: %Item{items_abilities: items_abilities} = item} = character_item, updated_character ->
        item =
          put_in(item.abilities, Enum.reduce(items_abilities, %{}, fn %ItemAbility{ability: ability} = item_ability, abilities ->
            Map.put(abilities, ability.name, item_ability.value)
          end))
          |> Map.put(:strength, character_item.strength)
          |> Map.put(:intellect, character_item.intellect)
          |> Map.put(:willpower, character_item.willpower)
          |> Map.put(:agility, character_item.agility)
          |> Map.put(:health, character_item.health)
          |> Map.put(:charm, character_item.charm)
        if equipped do
          update_in(updated_character.equipment, &([item | &1]))
        else
          update_in(updated_character.inventory, &([item | &1]))
        end
    end)
  end

  def weapon(%Character{} = character) do
    character.equipment
    |> Enum.map(&(&1.item))
    |> Enum.find(&(&1.worn_on in ["Weapon Hand", "Two Handed"]))
  end

  def sign_in(email, password) do
    player = Repo.get_by(Character, email: email)
    sign_in?(player, password) && player
  end

  def sign_in?(%Character{password: stored_hash}, password) do
    checkpw(password, stored_hash)
  end

  def sign_in?(nil, _password) do
    dummy_checkpw
  end

  def find_or_create_by_external_id(external_id) do
    case Repo.one from s in Character, where: s.external_id == ^external_id do
      %Character{} = character ->
        character
      nil ->
        %Character{room_id: Room.start_room_id, external_id: external_id}
        |> Repo.insert!
    end
  end

  def add_experience(%Character{level: level} = character, exp) do
    character =
      character
      |> Map.put(:experience, character.experience + exp)
      |> ApathyDrive.Level.advance

    if character.level > level do
      Mobile.send_scroll character, "<p>You ascend to level #{character.level}!"
    end

    if character.level < level do
      Mobile.send_scroll character, "<p>You fall to level #{character.level}!"
    end
    character
  end

  def prompt(%Character{level: level, hp: hp_percent, mana: mana_percent} = character) do
    max_hp = Mobile.max_hp_at_level(character, level)
    max_mana = Mobile.max_mana_at_level(character, level)
    hp = trunc(max_hp * hp_percent)
    mana = trunc(max_mana * mana_percent)

    cond do
      hp_percent > 0.5 ->
        "[HP=#{hp}/MA=#{mana}]:"
      hp_percent > 0.20 ->
        "[HP=<span class='dark-red'>#{hp}</span>/MA=#{mana}]:"
      true ->
        "[HP=<span class='red'>#{hp}</span>/MA=#{mana}]:"
    end
  end

  def hp_at_level(%Character{} = character, level) do
    max_hp = Mobile.max_hp_at_level(character, level)

    trunc(max_hp * character.hp)
  end

  def mana_at_level(%Character{} = character, level) do
    max_mana = Mobile.max_mana_at_level(character, level)

    trunc(max_mana * character.mana)
  end

  def score_data(%Character{} = character) do
    effects =
      character.effects
      |> Map.values
      |> Enum.filter(&(Map.has_key?(&1, "StatusMessage")))
      |> Enum.map(&(&1["StatusMessage"]))

    %{
      name: character.name,
      class: character.class.name,
      race: character.race.name,
      level: character.level,
      experience: character.experience,
      perception: Mobile.perception_at_level(character, character.level),
      accuracy: Mobile.accuracy_at_level(character, character.level),
      spellcasting: Mobile.spellcasting_at_level(character, character.level),
      crits: Mobile.crits_at_level(character, character.level),
      dodge: Mobile.dodge_at_level(character, character.level),
      stealth: Mobile.stealth_at_level(character, character.level),
      tracking: Mobile.tracking_at_level(character, character.level),
      physical_damage: Mobile.physical_damage_at_level(character, character.level),
      physical_resistance: Mobile.physical_resistance_at_level(character, character.level),
      magical_damage: Mobile.magical_damage_at_level(character, character.level),
      magical_resistance: Mobile.magical_resistance_at_level(character, character.level),
      hp: hp_at_level(character, character.level),
      max_hp: Mobile.max_hp_at_level(character, character.level),
      mana: mana_at_level(character, character.level),
      max_mana: Mobile.max_mana_at_level(character, character.level),
      strength: Mobile.attribute_at_level(character, :strength, character.level),
      agility: Mobile.attribute_at_level(character, :agility, character.level),
      intellect: Mobile.attribute_at_level(character, :intellect, character.level),
      willpower: Mobile.attribute_at_level(character, :willpower, character.level),
      health: Mobile.attribute_at_level(character, :health, character.level),
      charm: Mobile.attribute_at_level(character, :charm, character.level),
      effects: effects
    }
  end

  def add_item(%Character{} = character, %Item{rarity: "common"} = item, level, :purchased) do
    %CharacterItem{
      character_id: character.id,
      item_id: item.id,
      level: level,
      strength: 3,
      agility: 3,
      intellect: 3,
      willpower: 3,
      health: 3,
      charm: 3
    }
    |> Repo.insert!

    Character.preload_items(character)
  end
  def add_item(%Character{} = character, %Item{rarity: "common"} = item, level, :looted) do
    %CharacterItem{
      character_id: character.id,
      item_id: item.id,
      level: level,
      strength: Enum.random(2..4),
      agility: Enum.random(2..4),
      intellect: Enum.random(2..4),
      willpower: Enum.random(2..4),
      health: Enum.random(2..4),
      charm: Enum.random(2..4)
    }
    |> Repo.insert!
    |> Character.preload_items
  end
  def add_item(%Character{} = character, %Item{rarity: "uncommon"} = item, level, :purchased) do
    %CharacterItem{
      character_id: character.id,
      item_id: item.id,
      level: level,
      strength: 6,
      agility: 6,
      intellect: 6,
      willpower: 6,
      health: 6,
      charm: 6
    }
    |> Repo.insert!
    |> Character.preload_items
  end
  def add_item(%Character{} = character, %Item{rarity: "uncommon"} = item, level, :looted) do
    %CharacterItem{
      character_id: character.id,
      item_id: item.id,
      level: level,
      strength: Enum.random(5..7),
      agility: Enum.random(5..7),
      intellect: Enum.random(5..7),
      willpower: Enum.random(5..7),
      health: Enum.random(5..7),
      charm: Enum.random(5..7)
    }
    |> Repo.insert!
    |> Character.preload_items
  end
  def add_item(%Character{} = character, %Item{rarity: "rare"} = item, level, :purchased) do
    %CharacterItem{
      character_id: character.id,
      item_id: item.id,
      level: level,
      strength: 9,
      agility: 9,
      intellect: 9,
      willpower: 9,
      health: 9,
      charm: 9
    }
    |> Repo.insert!
    |> Character.preload_items
  end
  def add_item(%Character{} = character, %Item{rarity: "rare"} = item, level, :looted) do
    %CharacterItem{
      character_id: character.id,
      item_id: item.id,
      level: level,
      strength: Enum.random(8..10),
      agility: Enum.random(8..10),
      intellect: Enum.random(8..10),
      willpower: Enum.random(8..10),
      health: Enum.random(8..10),
      charm: Enum.random(8..10)
    }
    |> Repo.insert!
    |> Character.preload_items
  end
  def add_item(%Character{} = character, %Item{rarity: "epic"} = item, level, :purchased) do
    %CharacterItem{
      character_id: character.id,
      item_id: item.id,
      level: level,
      strength: 15,
      agility: 15,
      intellect: 15,
      willpower: 15,
      health: 15,
      charm: 15
    }
    |> Repo.insert!
    |> Character.preload_items
  end
  def add_item(%Character{} = character, %Item{rarity: "epic"} = item, level, :looted) do
    %CharacterItem{
      character_id: character.id,
      item_id: item.id,
      level: level,
      strength: Enum.random(11..19),
      agility: Enum.random(11..19),
      intellect: Enum.random(11..19),
      willpower: Enum.random(11..19),
      health: Enum.random(11..19),
      charm: Enum.random(11..19)
    }
    |> Repo.insert!
    |> Character.preload_items
  end
  def add_item(%Character{} = character, %Item{rarity: "legendary"} = item, level, :purchased) do
    %CharacterItem{
      character_id: character.id,
      item_id: item.id,
      level: level,
      strength: 24,
      agility: 24,
      intellect: 24,
      willpower: 24,
      health: 24,
      charm: 24
    }
    |> Repo.insert!
    |> Character.preload_items
  end
  def add_item(%Character{} = character, %Item{rarity: "legendary"} = item, level, :looted) do
    %CharacterItem{
      character_id: character.id,
      item_id: item.id,
      level: level,
      strength: Enum.random(20..28),
      agility: Enum.random(20..28),
      intellect: Enum.random(20..28),
      willpower: Enum.random(20..28),
      health: Enum.random(20..28),
      charm: Enum.random(20..28)
    }
    |> Repo.insert!
    |> Character.preload_items
  end

  defimpl ApathyDrive.Mobile, for: Character do

    def ability_value(character, ability) do
      # TODO: add race and class ability values
      equipment_bonus =
        character.equipment
        |> Enum.reduce(0, fn
             %{abilities: %{^ability => value}}, total ->
               total + value
            _, total ->
              total
           end)
      effect_bonus = Systems.Effect.effect_bonus(character, ability)
      equipment_bonus + effect_bonus
    end

    def accuracy_at_level(character, level) do
      int = attribute_at_level(character, :agility, level)
      modifier = ability_value(character, "Accuracy")
      trunc(int * (1 + (modifier / 100)))
    end

    def attribute_at_level(%Character{} = character, attribute, level) do
      from_race = Map.get(character.race, attribute)

      from_equipment =
        character.equipment
        |> Enum.reduce(0, fn %{} = character_item, total ->
             total + Map.get(character_item, attribute)
           end)

      base = from_race + from_equipment

      trunc(base + ((base / 10) * (level - 1)))
    end

    def attack_interval(character) do
      trunc(round_length_in_ms(character) / attacks_per_round(character))
    end

    def attack_spell(character) do
      case Character.weapon(character) do
        nil ->
          %Spell{
            kind: "attack",
            mana: 0,
            user_message: "You punch {{target}} for {{amount}} damage!",
            target_message: "{{user}} punches you for {{amount}} damage!",
            spectator_message: "{{user}} punches {{target}} for {{amount}} damage!",
            ignores_round_cooldown?: true,
            abilities: %{
              "PhysicalDamage" => 100 / attacks_per_round(character),
              "Dodgeable" => true,
              "DodgeUserMessage" => "You throw a punch at {{target}}, but they dodge!",
              "DodgeTargetMessage" => "{{user}} throws a punch at you, but you dodge!",
              "DodgeSpectatorMessage" => "{{user}} throws a punch at {{target}}, but they dodge!"
            }
          }
        %Item{name: name, hit_verbs: hit_verbs, miss_verbs: [singular_miss, plural_miss]} ->
          [singular_hit, plural_hit] = Enum.random(hit_verbs)
          %Spell{
            kind: "attack",
            mana: 0,
            user_message: "You #{singular_hit} {{target}} with your #{name} for {{amount}} damage!",
            target_message: "{{user}} #{plural_hit} you with their #{name} for {{amount}} damage!",
            spectator_message: "{{user}} #{plural_hit} {{target}} with their #{name} for {{amount}} damage!",
            ignores_round_cooldown?: true,
            abilities: %{
              "PhysicalDamage" => 100 / attacks_per_round(character),
              "Dodgeable" => true,
              "DodgeUserMessage" => "You #{singular_miss} {{target}} with your #{name}, but they dodge!",
              "DodgeTargetMessage" => "{{user}} #{plural_miss} you with their #{name}, but you dodge!",
              "DodgeSpectatorMessage" => "{{user}} #{plural_miss} {{target}} with their #{name}, but they dodge!"
            }
          }
      end
    end

    def attacks_per_round(character) do
      case Character.weapon(character) do
        nil ->
          4
        %Item{worn_on: "Weapon Hand", grade: "Basic"} ->
          4
        %Item{worn_on: "Two Handed", grade: "Basic"} ->
          3
        %Item{worn_on: "Weapon Hand", grade: "Bladed"} ->
          3
        %Item{worn_on: "Two Handed", grade: "Bladed"} ->
          2
        %Item{worn_on: "Weapon Hand", grade: "Blunt"} ->
          2
        %Item{worn_on: "Two Handed", grade: "Blunt"} ->
          1
      end
    end

    def caster_level(%Character{level: caster_level}, %{} = _target), do: caster_level

    def confused(%Character{effects: effects} = character, %Room{} = room) do
      effects
      |> Map.values
      |> Enum.find(fn(effect) ->
           Map.has_key?(effect, "confused") && (effect["confused"] >= :rand.uniform(100))
         end)
      |> confused(character, room)
    end
    def confused(nil, %Character{}, %Room{}), do: false
    def confused(%{"confusion_message" => %{"user" => user_message} = message}, %Character{} = character, %Room{} = room) do
      Mobile.send_scroll(character, user_message)
      if message["spectator"], do: Room.send_scroll(room, "#{Text.interpolate(message["spectator"], %{"user" => character})}", [character])
      true
    end
    def confused(%{}, %Character{} = character, %Room{} = room) do
      send_scroll(character, "<p><span class='cyan'>You fumble in confusion!</span></p>")
      Room.send_scroll(room, "<p><span class='cyan'>#{Text.interpolate("{{user}} fumbles in confusion!</span></p>", %{"user" => character})}</span></p>", [character])
      true
    end

    def crits_at_level(character, level) do
      int = attribute_at_level(character, :intellect, level)
      modifier = ability_value(character, "Crits")
      trunc(int * (1 + (modifier / 100)))
    end

    def die(character, room) do
      character =
        character
        |> Mobile.send_scroll("<p><span class='red'>You have died.</span></p>")
        |> Map.put(:hp, 1.0)
        |> Map.put(:mana, 1.0)
        |> Map.put(:effects, %{})
        |> Map.put(:timers, %{})
        |> Mobile.update_prompt

      Room.start_room_id
      |> RoomServer.find
      |> RoomServer.mobile_entered(character)

      put_in(room.mobiles, Map.delete(room.mobiles, character.ref))
      |> Room.send_scroll("<p><span class='red'>#{character.name} has died.</span></p>")
    end

    def dodge_at_level(character, level) do
      agi = attribute_at_level(character, :agility, level)
      modifier = ability_value(character, "Dodge")
      trunc(agi * (1 + (modifier / 100)))
    end

    def enough_mana_for_spell?(character, %Spell{} =  spell) do
      mana = Character.mana_at_level(character, character.level)
      cost = Spell.mana_cost_at_level(spell, character.level)

      mana >= cost
    end

    def enter_message(%Character{name: name}) do
      "<p><span class='yellow'>#{name}</span><span class='dark-green'> walks in from {{direction}}.</span></p>"
    end

    def exit_message(%Character{name: name}) do
      "<p><span class='yellow'>#{name}</span><span class='dark-green'> walks off {{direction}}.</span></p>"
    end

    def has_ability?(%Character{} = character, ability_name) do
      # TODO: check abilities from race, class, and spell effects
      false
    end

    def held(%{effects: effects} = mobile) do
      effects
      |> Map.values
      |> Enum.find(fn(effect) ->
           Map.has_key?(effect, "held")
         end)
      |> held(mobile)
    end
    def held(nil, %{}), do: false
    def held(%{"effect_message" => message}, %{} = mobile) do
      send_scroll(mobile, "<p>#{message}</p>")
      true
    end

    def hp_description(%Character{hp: hp}) when hp >= 1.0, do: "unwounded"
    def hp_description(%Character{hp: hp}) when hp >= 0.9, do: "slightly wounded"
    def hp_description(%Character{hp: hp}) when hp >= 0.6, do: "moderately wounded"
    def hp_description(%Character{hp: hp}) when hp >= 0.4, do: "heavily wounded"
    def hp_description(%Character{hp: hp}) when hp >= 0.2, do: "severely wounded"
    def hp_description(%Character{hp: hp}) when hp >= 0.1, do: "critically wounded"
    def hp_description(%Character{hp: hp}), do: "very critically wounded"

    def look_name(%Character{name: name}) do
      "<span class='dark-cyan'>#{name}</span>"
    end

    def magical_damage_at_level(character, level) do
      damage = attribute_at_level(character, :intellect, level)
      modifier = ability_value(character, "ModifyDamage") + ability_value(character, "ModifyMagicalDamage")
      trunc(damage * (1 + (modifier / 100)))
    end

    def magical_resistance_at_level(character, level) do
      resist = attribute_at_level(character, :willpower, level)
      modifier = ability_value(character, "MagicalResist")
      trunc(resist * (modifier / 100))
    end

    def max_hp_at_level(mobile, level) do
      trunc(5 * attribute_at_level(mobile, :health, level))
    end

    def max_mana_at_level(mobile, level) do
      trunc(5 * attribute_at_level(mobile, :intellect, level))
    end

    def party_refs(character, _room) do
      [character.refs]
    end

    def perception_at_level(character, level) do
      int = attribute_at_level(character, :intellect, level)
      modifier = ability_value(character, "Perception")
      trunc(int * (1 + (modifier / 100)))
    end

    def physical_damage_at_level(character, level) do
      damage = attribute_at_level(character, :strength, level)
      modifier = ability_value(character, "ModifyDamage") + ability_value(character, "ModifyPhysicalDamage")
      trunc(damage * (1 + (modifier / 100)))
    end

    def physical_resistance_at_level(character, level) do
      resist = attribute_at_level(character, :strength, level)
      modifier = ability_value(character, "AC")
      trunc(resist * (modifier / 100))
    end

    def regenerate_hp_and_mana(%Character{hp: hp, mana: mana} = character, room) do
      max_hp = max_hp_at_level(character, character.level)
      max_mana = max_mana_at_level(character, character.level)

      base_regen_per_round = attribute_at_level(character, :willpower, character.level) / 5

      hp_regen_percentage_per_round = base_regen_per_round * (1 + ability_value(character, "HPRegen")) / max_hp
      mana_regen_percentage_per_round = base_regen_per_round * (1 + ability_value(character, "ManaRegen")) / max_mana

      character
      |> shift_hp(hp_regen_percentage_per_round, room)
      |> Map.put(:mana, min(mana + mana_regen_percentage_per_round, 1.0))
      |> TimerManager.send_after({:regen, round_length_in_ms(character), {:regen, character.ref}})
      |> update_prompt()
    end

    def round_length_in_ms(character) do
      base = 4000 - attribute_at_level(character, :agility, character.level)

      speed_mods =
        character.effects
        |> Map.values
        |> Enum.filter(&(Map.has_key?(&1, "Speed")))
        |> Enum.map(&(Map.get(&1, "Speed")))

      count = length(speed_mods)

      if count > 0 do
        trunc(base * (Enum.sum(speed_mods) / count / 100))
      else
        base
      end
    end

    def send_scroll(%Character{socket: socket} = character, html) do
      send(socket, {:scroll, html})
      character
    end

    def set_room_id(%Character{socket: socket, monitor_ref: monitor_ref} = character, room_id) do
      Process.demonitor(monitor_ref)

      send(character.socket, {:update_room, room_id})

      character
      |> Map.put(:room_id, room_id)
      |> Map.put(:monitor_ref, Process.monitor(socket))
      |> Repo.save!
    end

    def shift_hp(character, percentage, room) do
      hp_description = hp_description(character)
      character = update_in(character.hp, &(min(1.0, &1 + percentage)))
      updated_hp_description = hp_description(character)

      if hp_description != updated_hp_description do
        Room.send_scroll(room, "<p>#{look_name(character)} is #{updated_hp_description}.</p>", [character])
      end

      character
    end

    def silenced(%Character{effects: effects} = character, %Room{} = room) do
      effects
      |> Map.values
      |> Enum.find(fn(effect) ->
           Map.has_key?(effect, "Silence")
         end)
      |> silenced(character, room)
    end
    def silenced(nil, %Character{}, %Room{}), do: false
    def silenced(%{}, %Character{} = character, %Room{} = room) do
      Mobile.send_scroll(character, "<p><span class='cyan'>You are silenced!</span></p>")
      true
    end

    def spellcasting_at_level(character, level) do
      will = attribute_at_level(character, :willpower, level)
      modifier = ability_value(character, "Spellcasting")
      trunc(will * (1 + (modifier / 100)))
    end

    def spells_at_level(%Character{spells: spells}, level) do
      spells
      |> Map.values
      |> Enum.filter(& &1.level <= level)
      |> Enum.sort_by(& &1.level)
    end

    def stealth_at_level(character, level) do
      agi = attribute_at_level(character, :agility, level)
      modifier = ability_value(character, "Stealth")
      trunc(agi * (modifier / 100))
    end

    def subtract_mana(character, spell) do
      cost = Spell.mana_cost_at_level(spell, character.level)
      percentage = cost / Mobile.max_mana_at_level(character, character.level)
      update_in(character.mana, &(max(0, &1 - percentage)))
    end

    def target_level(%Character{level: _caster_level}, %Character{level: target_level}), do: target_level
    def target_level(%Character{level: caster_level}, %{level: _target_level}), do: caster_level

    def tracking_at_level(character, level) do
      perception = perception_at_level(character, level)
      modifier = ability_value(character, "Tracking")
      trunc(perception * (modifier / 100))
    end

    def update_prompt(%Character{socket: socket} = character) do
      send(socket, {:update_prompt, Character.prompt(character)})
      character
    end
  end

end
