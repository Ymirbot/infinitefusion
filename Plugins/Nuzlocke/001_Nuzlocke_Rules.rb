module NuzlockeRules
  SECRET_SEQUENCE = [8, 8, 2, 2, 4, 6, 4, 6]

  def self.check_secret_sequence
    @secret_index ||= 0
    @last_direction ||= 0
    return unless $PokemonGlobal
    return if $PokemonGlobal.nuzlocke_secret_claimed
    unless active?
      @secret_index = 0
      @last_direction = 0
      return
    end
    direction = Input.dir4
    if direction == 0
      @last_direction = 0
      return
    end
    return if direction == @last_direction
    @last_direction = direction
    if direction != SECRET_SEQUENCE[@secret_index]
      @secret_index = 0
      return
    end
    @secret_index += 1
    return unless @secret_index == SECRET_SEQUENCE.length
    @secret_index = 0
    pbWait(Graphics.frame_rate * 2)
    pbMessage(_INTL("Really? Attempting the Konami code? Damn you're old..."))
    $PokemonGlobal.nuzlocke_secret_claimed = true if pbReceiveItem(:HELIXFOSSIL)
  end

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
    return unless active?
    $Trainer.party.dup.each do |pokemon|
      next unless dead?(pokemon)
      next if $PokemonStorage.full?
      next if $PokemonStorage.pbStoreCaught(pokemon) < 0
      $Trainer.party.delete(pokemon)
      pbMessage(_INTL("{1} was moved to your PC and cannot return to the party.", pokemon.name))
    end
  end

  def self.note_overworld_faint
    @overworld_faint_pending = true
  end

  def self.process_overworld_faint
    return unless active? && @overworld_faint_pending
    @overworld_faint_pending = false
    move_dead_pokemon
    return unless $Trainer.all_fainted?
    if storage_has_able_pokemon?
      @replacement_pending = true
    else
      @game_over_pending = true
    end
  end

  def self.storage_has_able_pokemon?
    found = false
    pbEachPokemon do |pokemon, _box|
      found = true if pokemon && !pokemon.egg? && !pokemon.fainted? && !dead?(pokemon)
    end
    found
  end

  def self.game_over_pending?
    @game_over_pending
  end

  def self.game_over?
    active? && $PokemonGlobal.nuzlocke_game_over
  end

  def self.mark_game_over
    $PokemonGlobal.nuzlocke_game_over = true
    @game_over_pending = false
    Game.save(safe: true)
  end

  def self.show_game_over_message
    pbMessage(_INTL("You have no Pokémon left. You lost the Nuzlocke challenge."))
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
    return unless active?
    move_dead_pokemon
    return unless $Trainer.all_fainted?
    if storage_has_able_pokemon?
      @replacement_pending = true
    else
      @game_over_pending = true
    end
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

  def self.active?
    enabled? && $Trainer && $Trainer.has_pokedex
  end

  def self.confirm_activation
    commands = [_INTL("Yes"), _INTL("No")]
    first = pbMessage(
      _INTL("\\c[2]Nuzlocke rules cannot be turned off once enabled. Enable them?\\c[0]"),
      commands, 2, nil, 1)
    return false unless first == 0
    second = pbMessage(
      _INTL("\\c[2]Are you sure? Nuzlocke rules cannot be turned off.\\c[0]"),
      commands, 2, nil, 1)
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
    $game_map.name.to_s.strip.downcase.gsub(/\s+/, " ").sub(/\s+(?:b|f)?\d+f\z/, "")
  end

  def self.skip_repeat_encounter?
    active? && $PokemonSystem.nuzlocke_skip_encounters &&
      encounter_count(area_key) >= encounters_per_area
  end

  def self.encounter_count(area)
    value = $PokemonGlobal.nuzlocke_catch_areas[area]
    return 1 if value == true
    value.is_a?(Numeric) ? value.to_i : 0
  end

  def self.encounters_per_area
    value = $PokemonSystem.nuzlocke_encounters_per_area
    value = value.to_i if value.is_a?(Numeric)
    value = 1 unless value.is_a?(Numeric)
    value.between?(1, 4) ? value : 1
  end

  def self.start_random_encounter
    return unless active?
    area = area_key
    return if !area || area.empty?
    used = $PokemonGlobal.nuzlocke_catch_areas
    count = encounter_count(area)
    $PokemonTemp.nuzlocke_catch_area = area
    $PokemonTemp.nuzlocke_catch_allowed = count < encounters_per_area
    used[area] = count + 1
  end

  def self.end_random_encounter
    $PokemonTemp.nuzlocke_catch_area = nil
    $PokemonTemp.nuzlocke_catch_allowed = nil
  end

  def self.can_catch?(battle)
    return true unless active? && battle.wildBattle?
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
      if can_catch?(battle)
        original.call(*args)
      else
        block_message(scene) if args[7]
        false
      end
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

module Input
  class << self
    alias nuzlocke_original_update update

    def update
      nuzlocke_original_update
      NuzlockeRules.check_secret_sequence
    end
  end
end

class PokemonSystem
  attr_accessor :nuzlocke_skip_encounters
  attr_accessor :nuzlocke_encounters_per_area

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
  attr_accessor :nuzlocke_game_over
  attr_accessor :nuzlocke_secret_claimed

  def nuzlocke_catch_areas
    @nuzlocke_catch_areas ||= {}
  end
end

class << Game
  alias nuzlocke_original_start_new start_new

  def start_new(*args)
    $PokemonSystem.nuzlocke_rules = false if $PokemonSystem
    $PokemonSystem.nuzlocke_skip_encounters = false if $PokemonSystem
    $PokemonSystem.nuzlocke_encounters_per_area = 1 if $PokemonSystem
    $PokemonGlobal.nuzlocke_game_over = false if $PokemonGlobal
    $PokemonGlobal.nuzlocke_secret_claimed = false if $PokemonGlobal
    nuzlocke_original_start_new(*args)
  end
end

class PokemonTemp
  attr_accessor :nuzlocke_catch_area
  attr_accessor :nuzlocke_catch_allowed
end

class PokemonEncounters
  alias nuzlocke_original_encounter_triggered? encounter_triggered?

  def encounter_triggered?(enc_type, repel_active = false, triggered_by_step = true)
    return false if NuzlockeRules.skip_repeat_encounter?
    nuzlocke_original_encounter_triggered?(enc_type, repel_active, triggered_by_step)
  end
end

class Pokemon
  attr_accessor :nuzlocke_dead

  alias nuzlocke_original_hp= hp=

  def hp=(value)
    alive = @hp && @hp > 0
    self.nuzlocke_original_hp = value
    if alive && @hp == 0 && NuzlockeRules.active? && (!$game_temp || !$game_temp.in_battle)
      NuzlockeRules.note_overworld_faint
      @nuzlocke_dead = true
    end
  end
end

class StorageTransferBox
  alias nuzlocke_original_can_use_transfer_box? can_use_transfer_box?
  alias nuzlocke_original_setDisabled setDisabled

  def can_use_transfer_box?
    return false if NuzlockeRules.active?
    nuzlocke_original_can_use_transfer_box?
  end

  def setDisabled
    unless @disabled
      @name = TRANSFER_BOX_NAME_DISABLED
      message = if NuzlockeRules.active?
                  _INTL("\\C[2]The Transfer Box is disabled while Nuzlocke rules are active. You can still use it as a normal PC box, but Pokémon placed here will not be available in other savefiles.")
                end
      message ? pbMessage(message) : nuzlocke_original_setDisabled
    end
    @disabled = true
  end
end

class HallOfFame_Scene
  alias nuzlocke_original_getCurrentGameMode getCurrentGameMode

  def getCurrentGameMode
    return _INTL("Nuzlocke mode") if NuzlockeRules.enabled?
    nuzlocke_original_getCurrentGameMode
  end
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
    @pokemon.nuzlocke_dead = true if NuzlockeRules.active? && @pokemon && !opposes?
    nuzlocke_original_pbFaint(*args)
  end
end

class PokemonStorageScreen
  alias nuzlocke_original_pbWithdraw pbWithdraw
  alias nuzlocke_original_pbPlace pbPlace
  alias nuzlocke_original_pbSwap pbSwap

  def pbWithdraw(selected, heldpoke)
    if NuzlockeRules.active? && (NuzlockeRules.dead?(heldpoke) ||
       (selected[0] >= 0 && NuzlockeRules.dead?(@storage[selected[0], selected[1]])))
      NuzlockeRules.block_party_move
      return false
    end
    nuzlocke_original_pbWithdraw(selected, heldpoke)
  end

  def pbPlace(selected)
    if NuzlockeRules.active? && selected[0] == -1 && NuzlockeRules.dead?(@heldpkmn)
      NuzlockeRules.block_party_move
      return false
    end
    nuzlocke_original_pbPlace(selected)
  end

  def pbSwap(selected)
    if NuzlockeRules.active? && selected[0] == -1 && NuzlockeRules.dead?(@heldpkmn)
      NuzlockeRules.block_party_move
      return false
    end
    nuzlocke_original_pbSwap(selected)
  end

  alias nuzlocke_original_pbPlaceMulti pbPlaceMulti

  def pbPlaceMulti(box, selected_index)
    if NuzlockeRules.active? && box == -1 && @multiheldpkmn.any? { |held| NuzlockeRules.dead?(held[0]) }
      NuzlockeRules.block_party_move
      return
    end
    nuzlocke_original_pbPlaceMulti(box, selected_index)
  end

  alias nuzlocke_original_pbFuseFromPC pbFuseFromPC
  alias nuzlocke_original_pbFusionCommands pbFusionCommands
  alias nuzlocke_original_reverseFromPC reverseFromPC
  alias nuzlocke_original_pbUnfuseFromPC pbUnfuseFromPC

  def pbFuseFromPC(selected, heldpoke)
    if NuzlockeRules.active? && (NuzlockeRules.dead?(heldpoke) || NuzlockeRules.dead?(@storage[selected[0], selected[1]]))
      NuzlockeRules.block_fusion
      return
    end
    nuzlocke_original_pbFuseFromPC(selected, heldpoke)
  end

  def pbFusionCommands(selected)
    if NuzlockeRules.active? && (NuzlockeRules.dead?(@heldpkmn) || NuzlockeRules.dead?(@storage[selected[0], selected[1]]))
      NuzlockeRules.block_fusion
      return
    end
    nuzlocke_original_pbFusionCommands(selected)
  end

  def reverseFromPC(selected)
    if NuzlockeRules.active? && NuzlockeRules.dead?(@storage[selected[0], selected[1]])
      NuzlockeRules.block_fusion
      return
    end
    nuzlocke_original_reverseFromPC(selected)
  end

  def pbUnfuseFromPC(selected)
    if NuzlockeRules.active? && NuzlockeRules.dead?(@storage[selected[0], selected[1]])
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

class PokemonGameOption_Scene
  alias nuzlocke_original_pbGetOptions pbGetOptions

  def pbGetOptions(inloadscreen = false)
    options = nuzlocke_original_pbGetOptions(inloadscreen)
    return options unless $game_switches
    options << ButtonOption.new(
      _INTL("Nuzlocke Options"),
      proc {
        @nuzlocke_menu = true
        openNuzlockeMenu
      },
      "<icon=#{ICON_CHALLENGE}> " + _INTL("Configure Nuzlocke rules."))
    options
  end

  def openNuzlockeMenu
    return unless @nuzlocke_menu
    pbFadeOutIn {
      scene = NuzlockeOptionsScene.new
      screen = PokemonOptionScreen.new(scene)
      screen.pbStartScreen
    }
    @nuzlocke_menu = false
  end
end

class NuzlockeOptionsScene < PokemonOption_Scene
  def pbStartScene(inloadscreen = false)
    super
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Nuzlocke Options"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["textbox"].text = _INTL("Nuzlocke rules")
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def pbGetOptions(inloadscreen = false)
    NuzlockeRules.clear_activation_cancelled
    [NuzlockeOption.new(
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
      _INTL("Only capture first encounter per area; fainted Pokémon are retired permanently.")),
     EnumOption.new(
       _INTL("Repel effect"), [_INTL("Off"), _INTL("On")],
       proc { $PokemonSystem.nuzlocke_rules && $PokemonSystem.nuzlocke_skip_encounters ? 1 : 0 },
       proc { |value|
         $PokemonSystem.nuzlocke_skip_encounters = value == 1 if NuzlockeRules.enabled?
       },
       _INTL("Repel effect in areas where max encounters are reached.")),
     EnumOption.new(
       _INTL("Max encounters"), %w[1 2 3 4],
       proc { NuzlockeRules.encounters_per_area - 1 },
       proc { |value| $PokemonSystem.nuzlocke_encounters_per_area = value + 1 },
       _INTL("Number of Pokémon encounters allowed in each area."))]
  end

  def pbEndScene
    super
    NuzlockeRules.show_disable_warning
  end
end

class Object
  alias nuzlocke_original_pbWildBattle pbWildBattle
  alias nuzlocke_original_pbDoubleWildBattle pbDoubleWildBattle
  alias nuzlocke_original_pbWildBattleSpecific pbWildBattleSpecific

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

  def pbWildBattleSpecific(*args, &block)
    NuzlockeRules.start_random_encounter
    nuzlocke_original_pbWildBattleSpecific(*args, &block)
  ensure
    NuzlockeRules.end_random_encounter
  end
end

Events.onStartBattle += proc {
  NuzlockeRules.install_ball_handlers
}
NuzlockeRules.install_end_battle_handler

class Object
  alias nuzlocke_original_pbCheckAllFainted pbCheckAllFainted

  def pbCheckAllFainted
    NuzlockeRules.process_overworld_faint
    nuzlocke_original_pbCheckAllFainted
    NuzlockeRules.mark_game_over if NuzlockeRules.game_over_pending?
    NuzlockeRules.open_pending_replacement
  end

  alias nuzlocke_original_pbAfterBattle pbAfterBattle

  def pbAfterBattle(*args)
    nuzlocke_original_pbAfterBattle(*args)
    NuzlockeRules.mark_game_over if NuzlockeRules.game_over_pending?
    NuzlockeRules.open_pending_replacement
  end
end

Events.onStepTakenTransferPossible += proc {
  NuzlockeRules.process_overworld_faint
  NuzlockeRules.mark_game_over if NuzlockeRules.game_over_pending?
  NuzlockeRules.open_pending_replacement
}

class DoublePreviewScreen
  alias nuzlocke_original_draw_window draw_window

  def draw_window(dexNumber, level, x, y, isShiny=false, bodyShiny=false, headShiny=false, window_position=0)
    previewwindow = nuzlocke_original_draw_window(dexNumber, level, x, y, isShiny, bodyShiny, headShiny, window_position)
    pif_sprite = window_position == 0 ? @sprite_left : @sprite_right
    bitmap = BattleSpriteLoader.new.load_pif_sprite_directly(pif_sprite)
    bitmap.shiftAllColors(dexNumber, bodyShiny, headShiny)
    bitmap.scale_bitmap(Settings::FRONTSPRITE_SCALE)
    previewwindow.setBitmap(bitmap)
    previewwindow
  end
end
