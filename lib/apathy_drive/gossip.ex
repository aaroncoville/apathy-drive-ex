defmodule ApathyDrive.Gossip do
  use WebSockex
  require Logger

  def start_link() do
    WebSockex.start_link(config(:url), __MODULE__, [], name: __MODULE__)
  end

  def handle_connect(_conn, state) do
    Logger.info("Gossip connected to #{config(:url)}")
    send(self(), :authorize)
    {:ok, state}
  end

  def handle_info(:authorize, state) do
    message =
      Poison.encode!(%{
        "event" => "authenticate",
        "payload" => %{
          "client_id" => config(:client_id),
          "client_secret" => config(:secret_id)
        }
      })

    {:reply, {:text, message}, state}
  end

  def handle_frame({:text, msg}, state) do
    msg
    |> Poison.decode!()
    |> handle_message()

    {:ok, state}
  end

  def handle_frame(_, state) do
    {:ok, state}
  end

  def handle_cast({:broadcast, name, message}, state) do
    message =
      Poison.encode!(%{
        "event" => "messages/new",
        "payload" => %{
          "channel" => "gossip",
          "name" => name,
          "message" => message
        }
      })

    {:reply, {:text, message}, state}
  end

  defp handle_message(%{"event" => "messages/broadcast", "payload" => payload}) do
    ApathyDriveWeb.Endpoint.broadcast!("chat:gossip", "scroll", %{
      html:
        "<p>[<span class='dark-magenta'>gossip</span> : #{
          ApathyDrive.Character.sanitize(payload["name"])
        }@#{ApathyDrive.Character.sanitize(payload["game"])}] #{
          ApathyDrive.Character.sanitize(payload["message"])
        }</p>"
    })
  end

  defp handle_message(%{"event" => "authenticate", "status" => status}) do
    Logger.info("Gossip Authentication: #{status}")
  end

  defp handle_message(%{"event" => "channels/subscribed", "payload" => %{"channels" => channels}}) do
    Logger.info("Gossip subscribed to channels: #{inspect(channels)}")
  end

  defp handle_message(%{"event" => "heartbeat"}) do
    :noop
  end

  defp handle_message(msg) do
    IO.puts("unrecognized Gossip message: #{inspect(msg)}")
  end

  defp config(key) do
    Application.get_all_env(:apathy_drive)[:gossip][key]
  end
end
