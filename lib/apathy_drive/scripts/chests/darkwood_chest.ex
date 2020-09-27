defmodule ApathyDrive.Scripts.DarkwoodChest do
  import ApathyDrive.Scripts
  alias ApathyDrive.{Mobile, Room}

  def execute(%Room{} = room, mobile_ref, _target_ref) do
    Room.update_mobile(room, mobile_ref, fn room, mobile ->
      Mobile.send_scroll(mobile, "<p>You open the darkwood chest, and find...</p>")

      room
      |> give_coins_up_to(mobile_ref, %{platinum: 10, gold: 1500, silver: 10500})
      |> random_item_886(mobile_ref)
      |> random_item_886(mobile_ref)
      |> random_item_886(mobile_ref)
      |> random_item_886(mobile_ref)
      |> random_item_889(mobile_ref)
      |> random_item_889(mobile_ref)
      |> random_item_889(mobile_ref)
      |> random_item_889(mobile_ref)
      |> random_item_889(mobile_ref)
    end)
  end
end
