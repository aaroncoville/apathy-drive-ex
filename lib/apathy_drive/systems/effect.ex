defmodule Systems.Effect do
  use Timex
  alias ApathyDrive.{Item, Mobile, Room, RoomServer, Text, TimerManager, Trait}

  def add(%{effects: _effects, last_effect_key: key} = entity, effect) do
    add_effect(entity, key + 1, effect)
  end

  def add(%{effects: _effects, last_effect_key: key} = entity, effect, duration) do
    key = key + 1

    entity =
      case entity do
        %{ref: ref} ->
          TimerManager.send_after(entity, {{:effect, key}, duration, {:remove_effect, ref, key}})

        %{instance_id: instance_id} ->
          TimerManager.send_after(
            entity,
            {{:effect, key}, duration, {:remove_effect, instance_id, key}}
          )

        %{} ->
          TimerManager.send_after(entity, {{:effect, key}, duration, {:remove_effect, key}})
      end

    effect =
      if effect && effect["timers"] do
        Map.put(effect, "timers", [{:effect, key} | effect["timers"]])
      else
        Map.put(effect, "timers", [{:effect, key}])
      end

    add_effect(entity, key, effect)
  end

  def add_effect(
        %{effects: effects, last_effect_key: last_effect} = entity,
        key,
        %{"stack_key" => stack_key, "stack_count" => stack_count} = effect
      ) do
    case stack_count(entity, stack_key) do
      count when count < stack_count ->
        effects = Map.put(effects, key, effect)

        entity
        |> Map.put(:effects, effects)
        |> Map.put(:last_effect_key, last_effect + 1)
        |> Map.put(:bust_cache, true)

      _count ->
        if effect["toggle"] do
          entity
          |> remove_all_stacks(effect["stack_key"])
        else
          entity
          |> remove_oldest_stack(effect["stack_key"])
          |> add_effect(key, effect)
        end
    end
  end

  def add_effect(%{effects: effects, last_effect_key: last_effect} = entity, key, effect)
      when map_size(effect) > 0 do
    if Map.has_key?(effect, "application_message") do
      Mobile.send_scroll(
        entity,
        "<p><span class='dark-yellow'>#{effect["application_message"]}</span></p>"
      )
    end

    if Map.has_key?(effect, "member") do
      ApathyDrive.PubSub.subscribe(effect["member"])
    end

    effects = Map.put(effects, key, effect)

    entity
    |> Map.put(:effects, effects)
    |> Map.put(:last_effect_key, last_effect + 1)
    |> Map.put(:bust_cache, true)
  end

  def add_effect(%{} = entity, _key, _effect), do: entity

  def remove_oldest_stack(%{effects: effects} = entity, stack_key) do
    oldest =
      entity
      |> stack(stack_key)
      |> Enum.reject(&effects[&1]["Enchantment"])
      |> Enum.sort()
      |> List.first()

    if stack_key == :cast_timer do
      Mobile.send_scroll(
        entity,
        "<p><span class='dark-red'>You interrupt your other ability.</span></p>"
      )
    end

    remove(entity, oldest, show_expiration_message: entity)
  end

  def remove_all_stacks(%{effects: _effects} = entity, stack_key) do
    stacks =
      entity
      |> stack(stack_key)

    Enum.reduce(stacks, entity, fn stack, entity ->
      remove(entity, stack, show_expiration_message: entity)
    end)
  end

  def remove_all(%{effects: effects} = entity) do
    effects
    |> Map.keys()
    |> Enum.reduce(entity, fn key, entity ->
      remove(entity, key)
    end)
  end

  def remove(%{effects: effects} = entity, key, opts \\ []) do
    case effects[key] do
      %{} ->
        if opts[:fire_after_cast] && Map.has_key?(effects[key], "EndCast") do
          chance = effects[key]["EndCast%"] || 100
          roll = :rand.uniform(100)

          if roll <= chance do
            end_cast = effects[key]["EndCast"]

            send(
              self(),
              {:execute_ability,
               %{
                 caster: end_cast.caster,
                 ability: end_cast.ability,
                 target: end_cast.target
               }}
            )
          end
        end

        entity =
          if Map.has_key?(effects[key], "Enslave") do
            message =
              "<p><span class='dark-yellow'>With a shake of {{target:his/her/its}} head, {{target}} regains control of {{target:himself/herself/itself}}.</span></p>"
              |> Text.interpolate(%{"target" => entity})

            entity.room_id
            |> RoomServer.find()
            |> RoomServer.send_scroll(message)

            entity
            |> Map.put(:owner_id, nil)
            |> Map.put(:follow, nil)
          else
            entity
          end

        if opts[:show_expiration_message] && Map.has_key?(effects[key], "RemoveMessage") do
          message = "<p><span class='dark-yellow'>#{effects[key]["RemoveMessage"]}</span></p>"

          case entity do
            %Room{} ->
              Room.send_scroll(entity, message)

            %Item{} ->
              case opts[:show_expiration_message] do
                %Room{} = room ->
                  Room.send_scroll(room, message)

                %Item{} = item ->
                  Item.send_scroll(item, message)

                %{} = mobile ->
                  Mobile.send_scroll(mobile, message)
              end

            _ ->
              Mobile.send_scroll(entity, message)
          end
        end

        if Map.has_key?(effects[key], "member") do
          ApathyDrive.PubSub.unsubscribe(effects[key]["member"])
        end

        if Map.has_key?(effects[key], "timers") do
          Enum.each(effects[key]["timers"], fn timer_name ->
            TimerManager.cancel(entity, timer_name)
          end)
        end

        # if Map.has_key?(entity, :ref), do: send(self(), {:think, entity.ref})

        entity
        |> Map.put(:effects, Map.delete(effects, key))
        |> Map.put(:bust_cache, true)

      _ ->
        found_key =
          effects
          |> Map.keys()
          |> Enum.find(fn existing_key ->
            effects[existing_key]["timers"] == [key]
          end)

        if found_key do
          remove(entity, found_key)
        else
          entity
        end
    end
  end

  def max_stacks?(%{} = mobile, %{} = ability) do
    max = ability.traits["StackCount"] || ability.traits["stack_count"] || 1
    stack_key = ability.traits["StackKey"] || ability.traits["stack_key"] || ability.id
    stack_count(mobile, stack_key) >= max
  end

  def stack_count(%{effects: _effects} = entity, stack_key) do
    stack(entity, stack_key)
    |> length
  end

  def stack(%{effects: effects}, stack_key) do
    effects
    |> Map.keys()
    |> Enum.filter(fn key ->
      effects[key]["stack_key"] == stack_key
    end)
  end

  def effect_bonus(%{effects: effects}, name) do
    merged =
      effects
      |> Map.values()
      |> Enum.reduce(%{}, fn effect, merged ->
        Trait.merge_traits(merged, effect)
      end)

    Trait.value(merged, name)
  end

  def effect_list(%{effects: effects}, name) do
    effects
    |> Map.values()
    |> Enum.map(fn
      %{} = effect ->
        key =
          effect
          |> Map.keys()
          |> Enum.find(fn key ->
            String.downcase(to_string(key)) == String.downcase(to_string(name))
          end)

        if key, do: Map.get(effect, key), else: nil

      _ ->
        nil
    end)
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  def find_by_ref(%{effects: effects}, ref) do
    Enum.find(effects, fn {_key, effect} ->
      effect["effect_ref"] == ref
    end)
  end
end
