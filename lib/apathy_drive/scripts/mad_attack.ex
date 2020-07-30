defmodule ApathyDrive.Scripts.MadAttack do
  alias ApathyDrive.{Mobile, Room}

  def execute(%Room{} = room, mobile_ref, _target_ref) do
    rounds = Enum.random(2..7)

    Enum.reduce(1..rounds, room, fn _round, room ->
      mobile = room.mobiles[mobile_ref]

      if mobile do
        target = room.mobiles[Mobile.auto_attack_target(mobile, room)]

        if target do
          Mobile.send_scroll(
            mobile,
            "<p><span class='yellow'>You attack #{target.name} in a crazed, magic induced rage!</span></p>"
          )

          Mobile.send_scroll(
            target,
            "<p><span class='yellow'>#{mobile.name} attacks you in a crazed, magic induced rage!</span></p>"
          )

          Room.send_scroll(
            room,
            "<p><span class='yellow'>#{mobile.name} attacks #{target.name} in a crazed, magic induced rage!</span></p>",
            [mobile, target]
          )

          mobile = Map.put(mobile, :energy, mobile.max_energy)
          room = put_in(room.mobiles[mobile_ref].energy, mobile.max_energy)

          ApathyDrive.AI.auto_attack(mobile, room) || room
        else
          room
        end
      else
        room
      end
    end)
  end
end
