defmodule Components.Help do
  use GenEvent.Behaviour

  ### Public API
  def get_help(entity) do
    :gen_event.call(entity, Components.Help, :get_help)
  end

  def get_keywords(entity) do
    :gen_event.call(entity, Components.Help, :get_keywords)
  end

  def get_name(entity) do
    :gen_event.call(entity, Components.Help, :get_name)
  end


  ### GenEvent API
  def init(state) do
    {:ok, state}
  end

  def handle_call(:get_help, state) do
    {:ok, state["help"], state}
  end

  def handle_call(:get_keywords, state) do
    {:ok, state["keywords"], state}
  end

  def handle_call(:get_name, state) do
    {:ok, state["name"], state}
  end

end
