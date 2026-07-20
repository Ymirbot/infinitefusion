module NuzlockeCatchRule
  def self.enabled?
    $PokemonSystem && $PokemonSystem.nuzlocke_catch_rule
  end

  def self.area_key
    return nil unless $game_map
    $game_map.name.to_s.strip.downcase.gsub(/\s+/, " ")
  end

  def self.start_random_encounter
    return unless enabled? && $PokemonTemp.encounterType
    area = area_key
    return if !area || area.empty?
    used = $PokemonGlobal.nuzlocke_catch_areas
    $PokemonTemp.nuzlocke_catch_area = area
    $PokemonTemp.nuzlocke_catch_allowed = !used[area]
    used[area] = true
  end

  def self.end_random_encounter
    $PokemonTemp.nuzlocke_catch_area = nil
    $PokemonTemp.nuzlocke_catch_allowed = nil
  end

  def self.can_catch?(battle)
    return true unless enabled? && battle.wildBattle?
    return true unless $PokemonTemp.nuzlocke_catch_area
    return true if $PokemonTemp.nuzlocke_catch_allowed
    false
  end

  def self.block_message(scene)
    scene.pbDisplay(_INTL("You have already encountered a Pokémon in this area."))
  end

  def self.wrap_ball_handler(original)
    proc { |*args|
      battle = args[5]
      scene = args[6]
      show_messages = args[7]
      if !NuzlockeCatchRule.can_catch?(battle)
        NuzlockeCatchRule.block_message(scene) if show_messages
        next false
      end
      original.call(*args)
    }
  end

  def self.install_ball_handlers
    return if @ball_handlers_installed
    GameData::Item.each do |item|
      next unless item.is_poke_ball?
      original = ItemHandlers::CanUseInBattle[item.id]
      next unless original
      ItemHandlers::CanUseInBattle.add(item.id, wrap_ball_handler(original))
    end
    @ball_handlers_installed = true
  end
end

class PokemonSystem
  attr_writer :nuzlocke_catch_rule

  def nuzlocke_catch_rule
    @nuzlocke_catch_rule = false if @nuzlocke_catch_rule.nil?
    @nuzlocke_catch_rule
  end
end

class PokemonGlobalMetadata
  attr_writer :nuzlocke_catch_areas

  def nuzlocke_catch_areas
    @nuzlocke_catch_areas ||= {}
  end
end

class PokemonTemp
  attr_accessor :nuzlocke_catch_area
  attr_accessor :nuzlocke_catch_allowed
end

class ChallengeOptionsScene
  alias nuzlocke_original_pbGetOptions pbGetOptions

  def pbGetOptions(inloadscreen = false)
    options = nuzlocke_original_pbGetOptions(inloadscreen)
    options << EnumOption.new(
      _INTL("Nuzlocke catch rule"), [_INTL("Off"), _INTL("On")],
      proc { $PokemonSystem.nuzlocke_catch_rule ? 1 : 0 },
      proc { |value| $PokemonSystem.nuzlocke_catch_rule = value == 1 },
      _INTL("Only the first wild encounter in each area can be caught."))
    options
  end
end

class Object
  alias nuzlocke_original_pbWildBattle pbWildBattle
  alias nuzlocke_original_pbDoubleWildBattle pbDoubleWildBattle

  def pbWildBattle(*args, &block)
    NuzlockeCatchRule.start_random_encounter
    nuzlocke_original_pbWildBattle(*args, &block)
  ensure
    NuzlockeCatchRule.end_random_encounter
  end

  def pbDoubleWildBattle(*args, &block)
    NuzlockeCatchRule.start_random_encounter
    nuzlocke_original_pbDoubleWildBattle(*args, &block)
  ensure
    NuzlockeCatchRule.end_random_encounter
  end
end

Events.onStartBattle += proc { NuzlockeCatchRule.install_ball_handlers }
