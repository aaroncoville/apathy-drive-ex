defmodule Systems.Ability do
  use Systems.Reload

  def abilities(entity) do
    Abilities.all
    |> Enum.filter fn(ability) ->
         Components.Module.value(ability).useable_by?(entity)
       end
  end

  def execute(ability, entity, nil) do
    if ability.properties[:target] == "self" do
      execute(ability, entity, Components.Name.value(entity))
    else
      Components.Player.send_message(entity, ["scroll", "<p><span class='cyan'>You must supply a target.</span></p>"])
    end
  end

  def execute(ability, entity, target) do
    if ability.properties[:casting_time] do
      delay_execution(ability, entity, target)
    else
      execute(ability, entity, target, :now)
    end
  end

  def execute(ability, entity, target, :now) do
    room = Components.CurrentRoom.get_current_room(entity)
    target_entity = find_entity_in_room(room, target)
    if target_entity do
      Systems.Room.characters_in_room(room) |> Enum.each(fn(character) ->
        cond do
          character == entity ->
            Components.Player.send_message(entity, ["scroll", ability.properties[:user_message]])
          character == target_entity ->
            Components.Player.send_message(target_entity, ["scroll", ability.properties[:target_message]])
          true ->
            Components.Player.send_message(target_entity, ["scroll", ability.properties[:observer_message]])
        end
      end)
    else
      Components.Player.send_message(entity, ["scroll", "<p><span class='cyan'>Can't find #{target} here!  Your spell fails.</span></p>"])
    end
  end

  def delay_execution(ability, entity, target) do
    display_precast_message(ability, entity)

    delay = Float.floor(ability.properties[:casting_time] * 1000)
    :timer.apply_after(delay, __MODULE__, :execute, [ability, entity, target, :now])
  end

  def display_precast_message(ability, entity) do
    Components.CurrentRoom.get_current_room(entity)
    |> Systems.Room.characters_in_room
    |> Enum.each(fn(character) ->
         if character == entity do
           Components.Player.send_message(entity, ["scroll", "<p><span class='cyan'>You begin your casting.</span></p>"])
         else
           Components.Player.send_message(entity, ["scroll", "<p><span class='cyan'>#{Components.Name.value(entity)} begins casting a spell.</span></p>"])
         end
       end)
  end

  defp find_entity_in_room(room, target) do
    room
    |> Systems.Room.entities_in_room
    |> Systems.Match.first(:name_contains, target)
  end

  defmacro __using__(_opts) do
    quote do
      use Systems.Reload
      @after_compile Systems.Ability

      def name do
        __MODULE__
        |> Atom.to_string
        |> String.split(".")
        |> List.last
        |> Inflex.underscore
        |> String.replace("_", " ")
      end

      def keywords do
        name |> String.split
      end
    end
  end

  defmacro __after_compile__(_env, _bytecode) do
    quote do
      ability = Abilities.find_by_module(__MODULE__)
      if ability do
        Components.Keywords.value(ability, __MODULE__.keywords)
        Components.Name.value(ability, __MODULE__.name)
        Components.Help.value(ability, __MODULE__.help)
      else
        {:ok, ability} = Entity.init
        Entity.add_component(ability, Components.Keywords, __MODULE__.keywords)
        Entity.add_component(ability, Components.Name, __MODULE__.name)
        Entity.add_component(ability, Components.Module, __MODULE__)
        Entity.add_component(ability, Components.Help, __MODULE__.help)
        Abilities.add(__MODULE__.name, ability)
        Help.add(ability)
      end
    end
  end

end