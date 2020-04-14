defprotocol ApathyDrive.Mobile do
  def ability_value(mobile, ability)
  def accuracy_at_level(mobile, level, room)
  def attack_ability(mobile, riposte \\ false)
  def attribute_at_level(mobile, attribute, level)
  def auto_attack_target(mobile, room)
  def block_at_level(mobile, level)
  def colored_name(mobile)
  def color(mobile)
  def confused(mobile, room)
  def crits_at_level(mobile, level)
  def description(mobile, observer)
  def detected?(mobile, sneaker, room)
  def die(mobile, room)
  def die?(mobile)
  def dodge_at_level(mobile, level, room)
  def enough_mana_for_ability?(mobile, ability)
  def enter_message(mobile)
  def evil_points(mobile, attacker)
  def exhausted(mobile)
  def exit_message(mobile)
  def has_ability?(mobile, ability_name)
  def heartbeat(mobile, room)
  def held(mobile)
  def hp_description(mobile)
  def hp_regen_per_round(mobile)
  def magical_penetration_at_level(mobile, level)
  def magical_resistance_at_level(mobile, level)
  def mana_regen_per_round(mobile)
  def max_hp_at_level(mobile, level)
  def max_mana_at_level(mobile, level)
  def parry_at_level(mobile, level)
  def perception_at_level(mobile, level, room)
  def party_refs(mobile, room)
  def physical_penetration_at_level(mobile, level)
  def physical_resistance_at_level(mobile, level)
  def power_at_level(mobile, level)
  def send_scroll(mobile, html)
  def set_room_id(mobile, room_id)
  def shift_hp(mobile, percentage)
  def silenced(mobile, room)
  def spellcasting_at_level(mobile, level)
  def stealth_at_level(mobile, level)
  def subtract_mana(mobile, ability)
  def subtract_energy(mobile, ability)
  def tracking_at_level(mobile, level, room)
  def update_prompt(mobile, room)
end
