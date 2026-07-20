module NuzlockeRules
  def self.dead?(pokemon)
    pokemon && pokemon.nuzlocke_dead
  end

  def self.block_party_move
    Kernel.pbMessage(_INTL("One or more of the selected Pokémon have fainted."))
  end

  def self.block_fusion
    Kernel.pbMessage(_INTL("Fainted Pokémon cannot be used for fusion."))
  end

  def self.move_dead_pokemon
    return unless enabled?
    $Trainer.party.dup.each do |pokemon|
      next unless dead?(pokemon)
      next if $PokemonStorage.full?
      box = $PokemonStorage.pbStoreCaught(pokemon)
      next if box < 0
      $Trainer.party.delete(pokemon)
      pbMessage(_INTL("{1} was moved to your PC and cannot return to the party.", pokemon.name))
    end
  end

  def self.storage_has_able_pokemon?
    found = false
    pbEachPokemon do |pokemon, _box|
      found = true if pokemon && !pokemon.egg? && !pokemon.fainted? && !dead?(pokemon)
    end
    found
  end

  def self.open_storage_for_replacement
    pbMessage(_INTL("All of your party Pokémon fainted. Withdraw replacements from the PC."))
    loop do
      pbFadeOutIn do
        scene = PokemonStorageScene.new
        screen = PokemonStorageScreen.new(scene, $PokemonStorage)
        screen.pbStartScreen(1)
      end
      break if $Trainer.able_pokemon_count > 0
      pbMessage(_INTL("You must withdraw at least 1 Pokémon from the PC before continuing."))
    end
  end

  def self.on_end_battle(_sender, event)
    return unless enabled?
    move_dead_pokemon
    return unless $Trainer.all_fainted?
    return unless storage_has_able_pokemon?
    @replacement_pending = true
  end

  def self.open_pending_replacement
    return unless @replacement_pending
    @replacement_pending = false
    open_storage_for_replacement if storage_has_able_pokemon?
  end

  def self.install_end_battle_handler
    return if @end_battle_handler_installed
    callback = proc { |sender, event| on_end_battle(sender, event) }
    Events.onEndBattle.instance_variable_get(:@callbacks).unshift(callback)
    @end_battle_handler_installed = true
  end

  def self.enabled?
    $PokemonSystem && $PokemonSystem.nuzlocke_rules
  end

  def self.confirm_activation
    commands = [_INTL("Yes"), _INTL("No")]
    first = pbMessage(
      _INTL("\\c[2]Nuzlocke rules cannot be turned off once enabled. Enable them?\\c[0]"),
      commands, 1, nil, 1)
    return false unless first == 0
    second = pbMessage(
      _INTL("\\c[2]Are you sure? Nuzlocke rules cannot be turned off.\\c[0]"),
      commands, 1, nil, 1)
    second == 0
  end

  def self.activation_cancelled?
    @activation_cancelled == true
  end

  def self.clear_activation_cancelled
    @activation_cancelled = false
  end

  def self.reset_disable_attempt
    @disable_attempted = false
  end

  def self.record_disable_attempt
    @disable_attempted = true
  end

  def self.cancel_activation
    $PokemonSystem.nuzlocke_rules = false
    @activation_cancelled = true
  end

  def self.show_disable_warning
    return unless @disable_attempted
    @disable_attempted = false
    $PokemonSystem.nuzlocke_rules = true
    pbMessage(_INTL("Nuzlocke rules cannot be turned off once enabled. Re-enabling..."))
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
    $PokemonTemp.nuzlocke_catch_allowed
  end

  def self.block_message(scene)
    scene.pbDisplay(_INTL("You have already encountered a Pokémon in this area."))
  end

  def self.wrap_ball_handler(original)
    proc { |*args|
      battle = args[5]
      scene = args[6]
      show_messages = args[7]
      if !NuzlockeRules.can_catch?(battle)
        NuzlockeRules.block_message(scene) if show_messages
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
  def nuzlocke_rules
    if $PokemonGlobal
      if $PokemonGlobal.nuzlocke_rules.nil?
        legacy = @nuzlocke_rules
        legacy = @nuzlocke_catch_rule if legacy.nil?
        $PokemonGlobal.nuzlocke_rules = !!legacy
      end
      return $PokemonGlobal.nuzlocke_rules
    end
    @nuzlocke_rules = @nuzlocke_catch_rule if @nuzlocke_rules.nil? && !@nuzlocke_catch_rule.nil?
    @nuzlocke_rules = false if @nuzlocke_rules.nil?
    @nuzlocke_rules
  end

  def nuzlocke_rules=(value)
    @nuzlocke_rules = value
    $PokemonGlobal.nuzlocke_rules = value if $PokemonGlobal
  end
end

class PokemonGlobalMetadata
  attr_writer :nuzlocke_catch_areas
  attr_accessor :nuzlocke_rules

  def nuzlocke_catch_areas
    @nuzlocke_catch_areas ||= {}
  end
end

class << Game
  alias nuzlocke_original_start_new start_new

  def start_new(*args)
    $PokemonSystem.nuzlocke_rules = false if $PokemonSystem
    nuzlocke_original_start_new(*args)
  end
end

class PokemonTemp
  attr_accessor :nuzlocke_catch_area
  attr_accessor :nuzlocke_catch_allowed
end

class Pokemon
  attr_accessor :nuzlocke_dead
end

class PokemonBoxIcon
  alias nuzlocke_original_update update

  def update
    nuzlocke_original_update
    self.color = Color.new(255, 0, 0, 96) if NuzlockeRules.dead?(@pokemon)
  end
end

class PokeBattle_Battler
  alias nuzlocke_original_pbFaint pbFaint

  def pbFaint(*args)
    @pokemon.nuzlocke_dead = true if NuzlockeRules.enabled? && @pokemon && !opposes?
    nuzlocke_original_pbFaint(*args)
  end
end

class PokemonStorageScreen
  alias nuzlocke_original_pbWithdraw pbWithdraw
  alias nuzlocke_original_pbPlace pbPlace
  alias nuzlocke_original_pbSwap pbSwap

  def pbWithdraw(selected, heldpoke)
    if NuzlockeRules.enabled? && (NuzlockeRules.dead?(heldpoke) ||
       (selected[0] >= 0 && NuzlockeRules.dead?(@storage[selected[0], selected[1]])))
      NuzlockeRules.block_party_move
      return false
    end
    nuzlocke_original_pbWithdraw(selected, heldpoke)
  end

  def pbPlace(selected)
    if NuzlockeRules.enabled? && selected[0] == -1 && NuzlockeRules.dead?(@heldpkmn)
      NuzlockeRules.block_party_move
      return false
    end
    nuzlocke_original_pbPlace(selected)
  end

  def pbSwap(selected)
    if NuzlockeRules.enabled? && selected[0] == -1 && NuzlockeRules.dead?(@heldpkmn)
      NuzlockeRules.block_party_move
      return false
    end
    nuzlocke_original_pbSwap(selected)
  end
end

class PokemonStorageScreen
  alias nuzlocke_original_pbPlaceMulti pbPlaceMulti

  def pbPlaceMulti(box, selected_index)
    if NuzlockeRules.enabled? && box == -1 && @multiheldpkmn.any? { |held| NuzlockeRules.dead?(held[0]) }
      NuzlockeRules.block_party_move
      return
    end
    nuzlocke_original_pbPlaceMulti(box, selected_index)
  end
end

class PokemonStorageScreen
  alias nuzlocke_original_pbFuseFromPC pbFuseFromPC
  alias nuzlocke_original_pbFusionCommands pbFusionCommands
  alias nuzlocke_original_reverseFromPC reverseFromPC
  alias nuzlocke_original_pbUnfuseFromPC pbUnfuseFromPC

  def pbFuseFromPC(selected, heldpoke)
    if NuzlockeRules.enabled? && (NuzlockeRules.dead?(heldpoke) || NuzlockeRules.dead?(@storage[selected[0], selected[1]]))
      NuzlockeRules.block_fusion
      return
    end
    nuzlocke_original_pbFuseFromPC(selected, heldpoke)
  end

  def pbFusionCommands(selected)
    if NuzlockeRules.enabled? && (NuzlockeRules.dead?(@heldpkmn) || NuzlockeRules.dead?(@storage[selected[0], selected[1]]))
      NuzlockeRules.block_fusion
      return
    end
    nuzlocke_original_pbFusionCommands(selected)
  end

  def reverseFromPC(selected)
    if NuzlockeRules.enabled? && NuzlockeRules.dead?(@storage[selected[0], selected[1]])
      NuzlockeRules.block_fusion
      return
    end
    nuzlocke_original_reverseFromPC(selected)
  end

  def pbUnfuseFromPC(selected)
    if NuzlockeRules.enabled? && NuzlockeRules.dead?(@storage[selected[0], selected[1]])
      NuzlockeRules.block_fusion
      return
    end
    nuzlocke_original_pbUnfuseFromPC(selected)
  end
end

class NuzlockeOption < EnumOption
end

class Window_PokemonOption
  alias nuzlocke_original_update update

  def update
    nuzlocke_original_update
    if NuzlockeRules.activation_cancelled?
      index = self.index
      if @options[index].is_a?(NuzlockeOption)
        setValueNoRefresh(index, 0)
        NuzlockeRules.clear_activation_cancelled
        refresh
      end
    end
  end
end

class ChallengeOptionsScene
  alias nuzlocke_original_pbGetOptions pbGetOptions

  def pbGetOptions(inloadscreen = false)
    NuzlockeRules.clear_activation_cancelled
    options = nuzlocke_original_pbGetOptions(inloadscreen)
    options << NuzlockeOption.new(
      _INTL("Nuzlocke rules"), [_INTL("Off"), _INTL("On")],
      proc { $PokemonSystem.nuzlocke_rules ? 1 : 0 },
      proc { |value|
        if value == 1
          NuzlockeRules.reset_disable_attempt
          if !$PokemonSystem.nuzlocke_rules
            if NuzlockeRules.confirm_activation
              $PokemonSystem.nuzlocke_rules = true
            else
              NuzlockeRules.cancel_activation
            end
          end
        elsif $PokemonSystem.nuzlocke_rules
          NuzlockeRules.record_disable_attempt
        else
          NuzlockeRules.clear_activation_cancelled
        end
      },
      _INTL("Only capture first encounter per area; fainted Pokémon are retired permanently."))
    options
  end

  alias nuzlocke_original_pbEndScene pbEndScene

  def pbEndScene
    nuzlocke_original_pbEndScene
    NuzlockeRules.show_disable_warning
  end
end

class Object
  alias nuzlocke_original_pbWildBattle pbWildBattle
  alias nuzlocke_original_pbDoubleWildBattle pbDoubleWildBattle

  def pbWildBattle(*args, &block)
    NuzlockeRules.start_random_encounter
    nuzlocke_original_pbWildBattle(*args, &block)
  ensure
    NuzlockeRules.end_random_encounter
  end

  def pbDoubleWildBattle(*args, &block)
    NuzlockeRules.start_random_encounter
    nuzlocke_original_pbDoubleWildBattle(*args, &block)
  ensure
    NuzlockeRules.end_random_encounter
  end
end

Events.onStartBattle += proc { NuzlockeRules.install_ball_handlers }
NuzlockeRules.install_end_battle_handler

class Object
  alias nuzlocke_original_pbAfterBattle pbAfterBattle

  def pbAfterBattle(*args)
    nuzlocke_original_pbAfterBattle(*args)
    NuzlockeRules.open_pending_replacement
  end
end
