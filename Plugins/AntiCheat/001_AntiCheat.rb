module AntiCheat
  SOURCE = "Data/Scripts/999_Main/999_Main.rb"
  DEBUG_WRITE = /\$DEBUG\s*(?:=|\|=|\|\|=)\s*(?!false\b|nil\b)/
  DEBUG_FALSE_TRUE = /\$DEBUG\s*(?:=|\|=|\|\|=)\s*false\s*(?:\|\||or)\s*(?:true|1\b)/

  def self.detected?
    return false unless File.file?(SOURCE)
    source = File.read(SOURCE).gsub(/\\\s*\n/, "")
    source.match?(DEBUG_WRITE) || source.match?(DEBUG_FALSE_TRUE)
  end

  def self.game_over?
    $PokemonGlobal && $PokemonGlobal.anticheat_game_over
  end

  def self.check
    return unless $PokemonGlobal
    cheating = detected?
    $PokemonGlobal.anticheat_game_over = cheating
    $DEBUG = false if cheating
  end

  def self.block_transition
    pbMessage(_INTL("Professor Oak would be dissapointed, I should revert my changes."))
  end
end

class PokemonGlobalMetadata
  attr_accessor :anticheat_game_over
end

class << Game
  alias anticheat_original_start_new start_new

  def start_new(*args)
    $PokemonGlobal.anticheat_game_over = false if $PokemonGlobal
    result = anticheat_original_start_new(*args)
    AntiCheat.check
    result
  end

  alias anticheat_original_load load

  def load(*args)
    result = anticheat_original_load(*args)
    AntiCheat.check
    result
  end

  alias anticheat_original_save save

  def save(*args, **kwargs)
    AntiCheat.check
    anticheat_original_save(*args, **kwargs)
  end
end

class Scene_Map
  alias anticheat_original_transfer_player transfer_player

  def transfer_player(cancelVehicles = true)
    if AntiCheat.game_over?
      $game_temp.player_transferring = false
      AntiCheat.block_transition
      return
    end
    anticheat_original_transfer_player(cancelVehicles)
  end
end

class Game_Event
  alias anticheat_original_start start

  def start
    if AntiCheat.game_over? && @list.any? { |command| command.code == 201 }
      AntiCheat.block_transition
      return
    end
    anticheat_original_start
  end
end
