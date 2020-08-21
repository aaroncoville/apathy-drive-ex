defmodule ApathyDrive.Scripts.SilverCasket do
  import ApathyDrive.Scripts
  alias ApathyDrive.{Mobile, Room}

  def execute(%Room{} = room, mobile_ref, _target_ref) do
    Room.update_mobile(room, mobile_ref, fn room, mobile ->
      Mobile.send_scroll(mobile, "<p>You open the silver casket, and find...</p>")

      room
      |> give_coins_up_to(mobile_ref, %{gold: 30, silver: 300})
      |> random_item_4149(mobile_ref)
      |> random_item_4149(mobile_ref)
      |> random_item_4149(mobile_ref)
      |> random_item_4149(mobile_ref)
      |> random_item_2922(mobile_ref)
    end)
  end
end
