extends Node

# Audio Manager — The Globbler's personal DJ
# "Every great escape from a terminal deserves a soundtrack.
#  Even if that soundtrack is procedurally generated bleeps and bloops."
#
# Generates placeholder synth sounds using AudioStreamGenerator.
# Swap in real .ogg/.wav assets later by replacing the streams.

# --- Audio buses ---
# We create our own players for: Music, Ambient, SFX, UI
# Each category gets its own volume control

# --- Volume settings (linear 0.0–1.0) ---
var music_volume := 0.7
var ambient_volume := 0.5
var sfx_volume := 0.8
var ui_volume := 0.6

# --- Player nodes ---
var _music_player: AudioStreamPlayer
var _boss_music_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []  # Pool of SFX players
const SFX_POOL_SIZE = 8  # Enough concurrent bleeps for a chaotic firefight

# --- Music state ---
var _current_music := ""
var _boss_fight_active := false
var _menu_music_player: AudioStreamPlayer

# --- Procedural generation constants ---
const SAMPLE_RATE = 22050.0
const BASE_VOLUME_DB = -6.0

# SFX definitions: each is a mini synth patch
# format: { "freq": Hz, "duration": seconds, "wave": "sine"/"square"/"saw"/"noise",
#            "env_attack": s, "env_decay": s, "pitch_slide": Hz/s, "volume_db": dB }
var _sfx_defs := {
	# === Volume tiers for consistency ===
	# Subtle (-16 dB): ambient feedback, footsteps, hover — barely there
	# Soft (-12 dB): pickups, combos, menu clicks — noticeable but polite
	# Normal (-8 dB): combat, movement, abilities — the meat and potatoes
	# Prominent (-6 dB): key hits, death, puzzle results — pay attention
	# Impactful (-4 dB): boss events, level-end — the big dramatic moments

	# --- Player SFX ---
	"footstep": { "freq": 120.0, "duration": 0.08, "wave": "noise", "env_attack": 0.0, "env_decay": 0.07, "volume_db": -16.0 },
	"jump": { "freq": 280.0, "duration": 0.2, "wave": "square", "env_attack": 0.01, "env_decay": 0.18, "pitch_slide": 400.0, "volume_db": -8.0 },
	"land": { "freq": 80.0, "duration": 0.15, "wave": "noise", "env_attack": 0.0, "env_decay": 0.14, "volume_db": -12.0 },
	"dash": { "freq": 600.0, "duration": 0.25, "wave": "saw", "env_attack": 0.01, "env_decay": 0.23, "pitch_slide": -500.0, "volume_db": -8.0 },
	"glob_fire": { "freq": 440.0, "duration": 0.35, "wave": "sine", "env_attack": 0.02, "env_decay": 0.32, "pitch_slide": 300.0, "volume_db": -6.0 },
	"glob_match": { "freq": 660.0, "duration": 0.2, "wave": "sine", "env_attack": 0.01, "env_decay": 0.18, "pitch_slide": 200.0, "volume_db": -6.0 },
	"glob_fail": { "freq": 200.0, "duration": 0.3, "wave": "square", "env_attack": 0.01, "env_decay": 0.28, "pitch_slide": -150.0, "volume_db": -8.0 },
	"wrench_swing": { "freq": 300.0, "duration": 0.18, "wave": "saw", "env_attack": 0.0, "env_decay": 0.17, "pitch_slide": -200.0, "volume_db": -8.0 },
	"wrench_hit": { "freq": 150.0, "duration": 0.2, "wave": "noise", "env_attack": 0.0, "env_decay": 0.19, "volume_db": -6.0 },
	"player_damage": { "freq": 180.0, "duration": 0.25, "wave": "saw", "env_attack": 0.0, "env_decay": 0.24, "pitch_slide": -100.0, "volume_db": -6.0 },
	"player_death": { "freq": 400.0, "duration": 0.8, "wave": "saw", "env_attack": 0.01, "env_decay": 0.78, "pitch_slide": -350.0, "volume_db": -4.0 },

	# --- Enemy SFX ---
	"enemy_alert": { "freq": 800.0, "duration": 0.15, "wave": "square", "env_attack": 0.0, "env_decay": 0.14, "volume_db": -8.0 },
	"enemy_attack": { "freq": 250.0, "duration": 0.2, "wave": "saw", "env_attack": 0.01, "env_decay": 0.18, "volume_db": -8.0 },
	"enemy_death": { "freq": 500.0, "duration": 0.4, "wave": "square", "env_attack": 0.0, "env_decay": 0.39, "pitch_slide": -400.0, "volume_db": -6.0 },

	# --- Puzzle SFX ---
	"puzzle_activate": { "freq": 523.0, "duration": 0.2, "wave": "sine", "env_attack": 0.01, "env_decay": 0.18, "volume_db": -8.0 },
	"puzzle_success": { "freq": 523.0, "duration": 0.6, "wave": "sine", "env_attack": 0.01, "env_decay": 0.58, "pitch_slide": 300.0, "volume_db": -6.0 },
	"puzzle_fail": { "freq": 220.0, "duration": 0.5, "wave": "square", "env_attack": 0.01, "env_decay": 0.48, "pitch_slide": -100.0, "volume_db": -6.0 },

	# --- Boss SFX — the big dramatic moments ---
	"boss_phase": { "freq": 100.0, "duration": 0.6, "wave": "saw", "env_attack": 0.05, "env_decay": 0.54, "volume_db": -4.0 },
	"boss_attack": { "freq": 80.0, "duration": 0.4, "wave": "noise", "env_attack": 0.02, "env_decay": 0.37, "volume_db": -6.0 },
	"boss_defeated": { "freq": 440.0, "duration": 1.2, "wave": "sine", "env_attack": 0.05, "env_decay": 1.14, "pitch_slide": 400.0, "volume_db": -4.0 },

	# --- Pickup / Feedback SFX ---
	"token_pickup": { "freq": 880.0, "duration": 0.15, "wave": "sine", "env_attack": 0.0, "env_decay": 0.14, "pitch_slide": 200.0, "volume_db": -12.0 },
	"combo_hit": { "freq": 700.0, "duration": 0.12, "wave": "square", "env_attack": 0.0, "env_decay": 0.11, "volume_db": -12.0 },
	"checkpoint": { "freq": 440.0, "duration": 0.4, "wave": "sine", "env_attack": 0.02, "env_decay": 0.37, "pitch_slide": 220.0, "volume_db": -6.0 },

	# --- Agent Spawn SFX — sounds like a tiny robot booting up ---
	"agent_spawn": { "freq": 600.0, "duration": 0.35, "wave": "square", "env_attack": 0.02, "env_decay": 0.32, "pitch_slide": 300.0, "volume_db": -8.0 },
	"agent_fail": { "freq": 200.0, "duration": 0.4, "wave": "saw", "env_attack": 0.01, "env_decay": 0.38, "pitch_slide": -120.0, "volume_db": -8.0 },
	"agent_success": { "freq": 880.0, "duration": 0.3, "wave": "sine", "env_attack": 0.01, "env_decay": 0.28, "pitch_slide": 440.0, "volume_db": -6.0 },

	# --- UI SFX — routed through ui_volume, not sfx_volume ---
	"menu_hover": { "freq": 1200.0, "duration": 0.05, "wave": "sine", "env_attack": 0.0, "env_decay": 0.04, "volume_db": -16.0 },
	"menu_select": { "freq": 800.0, "duration": 0.12, "wave": "square", "env_attack": 0.0, "env_decay": 0.11, "pitch_slide": 200.0, "volume_db": -12.0 },
	"menu_back": { "freq": 600.0, "duration": 0.1, "wave": "square", "env_attack": 0.0, "env_decay": 0.09, "pitch_slide": -200.0, "volume_db": -12.0 },
	"dialogue_advance": { "freq": 1000.0, "duration": 0.06, "wave": "sine", "env_attack": 0.0, "env_decay": 0.05, "volume_db": -16.0 },

	# --- Hack / Terminal SFX — because every minigame needs bleeps ---
	"hack_start": { "freq": 500.0, "duration": 0.3, "wave": "square", "env_attack": 0.02, "env_decay": 0.27, "pitch_slide": 150.0, "volume_db": -8.0 },
	"hack_keypress": { "freq": 1400.0, "duration": 0.04, "wave": "sine", "env_attack": 0.0, "env_decay": 0.03, "volume_db": -16.0 },
	"hack_success": { "freq": 660.0, "duration": 0.5, "wave": "sine", "env_attack": 0.01, "env_decay": 0.48, "pitch_slide": 400.0, "volume_db": -6.0 },
	"hack_fail": { "freq": 150.0, "duration": 0.4, "wave": "saw", "env_attack": 0.01, "env_decay": 0.38, "pitch_slide": -80.0, "volume_db": -6.0 },

	# --- Ability readiness — the "I'm off cooldown" chirp ---
	"ability_ready": { "freq": 1000.0, "duration": 0.1, "wave": "sine", "env_attack": 0.0, "env_decay": 0.09, "pitch_slide": 300.0, "volume_db": -12.0 },

	# --- Context window overflow — Globbler.exe has stopped responding ---
	"context_overflow": { "freq": 300.0, "duration": 0.6, "wave": "saw", "env_attack": 0.02, "env_decay": 0.57, "pitch_slide": -200.0, "volume_db": -6.0 },
}

# Which SFX belong to the UI bus — everything else is gameplay SFX
# "Even our volume knobs have categories. We're enterprise-grade bleeps."
var _ui_sfx_names := [
	"menu_hover", "menu_select", "menu_back", "dialogue_advance",
]

# Cached generated audio streams — no need to regenerate every bleep
var _sfx_cache: Dictionary = {}


func _ready() -> void:
	print("[AUDIO] Initializing The Globbler's sound system. Brace your speakers.")
	_create_players()
	_precache_sfx()
	_connect_global_signals()
	# Don't auto-start chapter audio — let scenes call start methods
	# Main menu will call start_menu_music(), levels call _start_chapter_1_audio()


func _create_players() -> void:
	# Music player — the synthwave backbone
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.volume_db = linear_to_db(music_volume) + BASE_VOLUME_DB
	add_child(_music_player)

	# Boss music — separate player for crossfade potential
	_boss_music_player = AudioStreamPlayer.new()
	_boss_music_player.name = "BossMusicPlayer"
	_boss_music_player.volume_db = linear_to_db(music_volume) + BASE_VOLUME_DB
	add_child(_boss_music_player)

	# Ambient player — server hums and cooling fans
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientPlayer"
	_ambient_player.volume_db = linear_to_db(ambient_volume) + BASE_VOLUME_DB - 4.0
	add_child(_ambient_player)

	# Menu music player — chill vibes for the title screen
	_menu_music_player = AudioStreamPlayer.new()
	_menu_music_player.name = "MenuMusicPlayer"
	_menu_music_player.volume_db = linear_to_db(music_volume) + BASE_VOLUME_DB
	add_child(_menu_music_player)

	# SFX player pool — because explosions wait for nobody
	for i in SFX_POOL_SIZE:
		var p = AudioStreamPlayer.new()
		p.name = "SFX_%d" % i
		p.volume_db = linear_to_db(sfx_volume) + BASE_VOLUME_DB
		add_child(p)
		_sfx_players.append(p)


func _precache_sfx() -> void:
	# Pre-generate all SFX audio streams so playback is instant
	for sfx_name in _sfx_defs:
		_sfx_cache[sfx_name] = _generate_sfx(sfx_name)


# --- Procedural sound generation ---
# Generates an AudioStreamWAV from our synth patch definitions

func _generate_sfx(sfx_name: String) -> AudioStreamWAV:
	var def: Dictionary = _sfx_defs[sfx_name]
	var freq: float = def.get("freq", 440.0)
	var duration: float = def.get("duration", 0.2)
	var wave_type: String = def.get("wave", "sine")
	var attack: float = def.get("env_attack", 0.01)
	var decay: float = def.get("env_decay", 0.15)
	var pitch_slide: float = def.get("pitch_slide", 0.0)

	var num_samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit mono

	var phase := 0.0

	for i in num_samples:
		var t := float(i) / SAMPLE_RATE
		var current_freq := freq + pitch_slide * (t / duration)

		# Envelope: linear attack then exponential decay
		var env := 1.0
		if t < attack and attack > 0.0:
			env = t / attack
		elif t >= attack:
			var decay_t := t - attack
			if decay > 0.0:
				env = exp(-3.0 * decay_t / decay)
			else:
				env = 0.0

		# Oscillator
		var sample := 0.0
		match wave_type:
			"sine":
				sample = sin(phase * TAU)
			"square":
				sample = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"saw":
				sample = 2.0 * fmod(phase, 1.0) - 1.0
			"noise":
				sample = randf_range(-1.0, 1.0)

		sample *= env * 0.8  # Master gain to prevent clipping

		# Convert to 16-bit PCM
		var pcm := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF

		# Advance phase
		phase += current_freq / SAMPLE_RATE

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(SAMPLE_RATE)
	stream.stereo = false
	stream.data = data
	return stream


# --- Music generation ---
# Generates a looping synthwave bass/pad loop for that cyberpunk terminal vibe

func _generate_music_loop(is_boss: bool = false) -> AudioStreamWAV:
	var bpm := 130.0 if not is_boss else 155.0
	var beats_per_bar := 4
	var bars := 4
	var total_beats := beats_per_bar * bars
	var beat_duration := 60.0 / bpm
	var total_duration := total_beats * beat_duration
	var num_samples := int(total_duration * SAMPLE_RATE)

	# Note sequences — minor key synthwave because we're moody like that
	var bass_notes := [55.0, 55.0, 73.4, 65.4, 55.0, 55.0, 82.4, 73.4]  # A1 variations
	var pad_notes := [220.0, 261.6, 246.9, 220.0]  # A3 C4 B3 A3

	if is_boss:
		# Boss theme: more aggressive, chromatic tension
		bass_notes = [55.0, 58.3, 65.4, 55.0, 51.9, 55.0, 73.4, 69.3]
		pad_notes = [220.0, 233.1, 261.6, 246.9]

	var data := PackedByteArray()
	data.resize(num_samples * 2)

	var bass_phase := 0.0
	var pad_phase := 0.0
	var noise_phase := 0.0

	for i in num_samples:
		var t := float(i) / SAMPLE_RATE
		var beat := t / beat_duration
		var beat_index := int(beat) % bass_notes.size()
		var bar_index := int(beat / beats_per_bar) % pad_notes.size()

		# Bass: square wave with slight detune for warmth
		var bass_freq := bass_notes[beat_index]
		var bass_sample := 0.0
		if fmod(bass_phase, 1.0) < 0.3:
			bass_sample = 1.0
		else:
			bass_sample = -1.0
		bass_phase += bass_freq / SAMPLE_RATE

		# Sidechain-style pump on each beat
		var beat_frac := fmod(beat, 1.0)
		var pump := 1.0
		if beat_frac < 0.1:
			pump = beat_frac / 0.1
		bass_sample *= pump * 0.25

		# Pad: detuned sine for atmosphere
		var pad_freq := pad_notes[bar_index]
		var pad_sample := sin(pad_phase * TAU) * 0.12
		pad_sample += sin(pad_phase * TAU * 1.003) * 0.08  # Slight detune chorus
		pad_phase += pad_freq / SAMPLE_RATE

		# Hi-hat: noise burst on 8th notes
		var eighth := fmod(beat * 2.0, 1.0)
		var hat_sample := 0.0
		if eighth < 0.05:
			hat_sample = randf_range(-1.0, 1.0) * 0.1

		# Kick: low sine burst on beats
		var kick_sample := 0.0
		if beat_frac < 0.08:
			var kick_env := 1.0 - (beat_frac / 0.08)
			kick_sample = sin(beat_frac * 200.0 * TAU) * kick_env * 0.3

		# Boss adds a gritty noise layer
		var extra := 0.0
		if is_boss:
			noise_phase += 1.0 / SAMPLE_RATE
			if fmod(noise_phase * 4.0, 1.0) < 0.02:
				extra = randf_range(-0.05, 0.05)

		var sample := bass_sample + pad_sample + hat_sample + kick_sample + extra
		var pcm := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(SAMPLE_RATE)
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = num_samples
	stream.data = data
	return stream


func _generate_ambient_loop() -> AudioStreamWAV:
	# Server room ambience: low hum + occasional fan whir + digital crackle
	var duration := 8.0  # 8 second loop
	var num_samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	var hum_phase := 0.0

	for i in num_samples:
		var t := float(i) / SAMPLE_RATE

		# 60Hz server hum (the sound of regret and electricity)
		var hum := sin(hum_phase * TAU) * 0.08
		hum += sin(hum_phase * TAU * 2.0) * 0.03  # Harmonic
		hum_phase += 60.0 / SAMPLE_RATE

		# Cooling fan: filtered noise modulated slowly
		var fan_mod := sin(t * 0.7 * TAU) * 0.5 + 0.5
		var fan := randf_range(-1.0, 1.0) * 0.02 * fan_mod

		# Occasional digital crackle
		var crackle := 0.0
		if randf() < 0.0005:
			crackle = randf_range(-0.15, 0.15)

		var sample := hum + fan + crackle
		var pcm := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(SAMPLE_RATE)
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = num_samples
	stream.data = data
	return stream


# --- Playback ---

func play_sfx(sfx_name: String) -> void:
	if not _sfx_cache.has(sfx_name):
		push_warning("[AUDIO] Unknown SFX: %s — did someone typo a sound name?" % sfx_name)
		return

	# Route UI sounds through ui_volume, everything else through sfx_volume
	# "Separation of concerns: even our bleeps have a proper bus architecture."
	var category_vol := ui_volume if sfx_name in _ui_sfx_names else sfx_volume
	var def: Dictionary = _sfx_defs[sfx_name]
	var target_db := def.get("volume_db", BASE_VOLUME_DB) + linear_to_db(category_vol)

	# Find a free player from the pool
	for p in _sfx_players:
		if not p.playing:
			p.volume_db = target_db
			p.stream = _sfx_cache[sfx_name]
			p.play()
			return

	# All players busy — steal the oldest one (the Globbler waits for no one)
	_sfx_players[0].stop()
	_sfx_players[0].volume_db = target_db
	_sfx_players[0].stream = _sfx_cache[sfx_name]
	_sfx_players[0].play()


func start_music(track_name: String) -> void:
	if _current_music == track_name:
		return
	_current_music = track_name

	match track_name:
		"chapter_1":
			_music_player.stream = _generate_music_loop(false)
			_music_player.volume_db = linear_to_db(music_volume) + BASE_VOLUME_DB
			_music_player.play()
		"boss":
			_start_boss_music()
		"none":
			_music_player.stop()
			_boss_music_player.stop()


func _start_boss_music() -> void:
	_boss_fight_active = true
	# Fade out normal music, start boss track
	var tween = create_tween()
	tween.tween_property(_music_player, "volume_db", -40.0, 1.0)
	tween.tween_callback(_music_player.stop)

	_boss_music_player.stream = _generate_music_loop(true)
	_boss_music_player.volume_db = -40.0
	_boss_music_player.play()
	var fade_in = create_tween()
	fade_in.tween_property(_boss_music_player, "volume_db", linear_to_db(music_volume) + BASE_VOLUME_DB, 1.5)


func stop_boss_music() -> void:
	_boss_fight_active = false
	var tween = create_tween()
	tween.tween_property(_boss_music_player, "volume_db", -40.0, 2.0)
	tween.tween_callback(_boss_music_player.stop)
	# Resume normal music
	_current_music = ""
	start_music("chapter_1")


func start_ambient() -> void:
	_ambient_player.stream = _generate_ambient_loop()
	_ambient_player.play()


func stop_ambient() -> void:
	_ambient_player.stop()


func _start_chapter_1_audio() -> void:
	start_ambient()
	start_music("chapter_1")


## Menu music — mellow synthwave loop, less intense than gameplay
func start_menu_music() -> void:
	if _menu_music_player.playing:
		return
	_menu_music_player.stream = _generate_menu_music()
	_menu_music_player.volume_db = linear_to_db(music_volume) + BASE_VOLUME_DB - 2.0
	_menu_music_player.play()


func stop_menu_music() -> void:
	if not _menu_music_player.playing:
		return
	var tween = create_tween()
	tween.tween_property(_menu_music_player, "volume_db", -40.0, 0.5)
	tween.tween_callback(_menu_music_player.stop)


func _generate_menu_music() -> AudioStreamWAV:
	# Chill ambient synth — slower, dreamier than chapter music
	# "Even the title screen has a vibe. We're professionals."
	var bpm := 90.0
	var beats_per_bar := 4
	var bars := 8
	var total_beats := beats_per_bar * bars
	var beat_duration := 60.0 / bpm
	var total_duration := total_beats * beat_duration
	var num_samples := int(total_duration * SAMPLE_RATE)

	# Dreamy minor key arpeggios
	var bass_notes := [55.0, 55.0, 65.4, 55.0, 73.4, 65.4, 55.0, 55.0]
	var pad_notes := [220.0, 196.0, 261.6, 220.0]  # A3 G3 C4 A3
	var arp_notes := [440.0, 523.3, 659.3, 523.3, 440.0, 392.0, 523.3, 440.0]

	var data := PackedByteArray()
	data.resize(num_samples * 2)

	var bass_phase := 0.0
	var pad_phase := 0.0
	var arp_phase := 0.0

	for i in num_samples:
		var t := float(i) / SAMPLE_RATE
		var beat := t / beat_duration
		var beat_index := int(beat) % bass_notes.size()
		var bar_index := int(beat / beats_per_bar) % pad_notes.size()
		var arp_index := int(beat * 2.0) % arp_notes.size()

		# Soft bass — sine wave, gentle
		var bass_freq := bass_notes[beat_index]
		var bass_sample := sin(bass_phase * TAU) * 0.15
		bass_phase += bass_freq / SAMPLE_RATE

		# Warm pad — detuned sines with slow modulation
		var pad_freq := pad_notes[bar_index]
		var pad_mod := sin(t * 0.3 * TAU) * 0.02
		var pad_sample := sin(pad_phase * TAU) * (0.08 + pad_mod)
		pad_sample += sin(pad_phase * TAU * 1.005) * 0.05  # Detune
		pad_phase += pad_freq / SAMPLE_RATE

		# Gentle arpeggio — quiet sine plinks
		var arp_freq := arp_notes[arp_index]
		var arp_beat_frac := fmod(beat * 2.0, 1.0)
		var arp_env := exp(-5.0 * arp_beat_frac) if arp_beat_frac < 0.5 else 0.0
		var arp_sample := sin(arp_phase * TAU) * arp_env * 0.06
		arp_phase += arp_freq / SAMPLE_RATE

		var sample := bass_sample + pad_sample + arp_sample
		var pcm := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(SAMPLE_RATE)
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = num_samples
	stream.data = data
	return stream


## Stop everything — used when transitioning between menu and game
func stop_all_audio() -> void:
	_music_player.stop()
	_boss_music_player.stop()
	_menu_music_player.stop()
	_ambient_player.stop()
	_current_music = ""
	_boss_fight_active = false


# --- Signal connections ---
# Hooks into global signals so every bleep and bloop triggers automatically

func _connect_global_signals() -> void:
	# GameManager signals
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if gm.has_signal("enemy_killed_signal"):
			gm.enemy_killed_signal.connect(_on_enemy_killed)
		if gm.has_signal("memory_token_collected"):
			gm.memory_token_collected.connect(_on_token_collected)
		if gm.has_signal("combo_updated"):
			gm.combo_updated.connect(_on_combo_updated)
		if gm.has_signal("damage_taken"):
			gm.damage_taken.connect(_on_damage_taken)
		if gm.has_signal("game_over"):
			gm.game_over.connect(_on_game_over)
		if gm.has_signal("level_complete"):
			gm.level_complete.connect(_on_level_complete)

	# GlobEngine signals
	var ge = get_node_or_null("/root/GlobEngine")
	if ge:
		if ge.has_signal("targets_matched"):
			ge.targets_matched.connect(_on_glob_matched)
		if ge.has_signal("pattern_failed"):
			ge.pattern_failed.connect(_on_glob_failed)

	# DialogueManager signals
	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		if dm.has_signal("dialogue_advanced"):
			dm.dialogue_advanced.connect(_on_dialogue_advanced)

	# Player signals are wired when the player spawns
	_connect_player_deferred()


func _connect_player_deferred() -> void:
	# The player might not exist yet — wait a frame then look for them
	await get_tree().process_frame
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		if p.has_signal("glob_fired"):
			p.glob_fired.connect(_on_player_glob_fired)
		if p.has_signal("player_damaged"):
			p.player_damaged.connect(_on_player_damaged)
		if p.has_signal("player_died"):
			p.player_died.connect(_on_player_died)
		if p.has_signal("dash_started"):
			p.dash_started.connect(_on_player_dash)
		# Wire ability signals if they exist
		if p.has_node("WrenchSmash") or p.get("wrench_smash"):
			var ws = p.get("wrench_smash") if p.get("wrench_smash") else p.get_node_or_null("WrenchSmash")
			if ws:
				if ws.has_signal("wrench_swung"):
					ws.wrench_swung.connect(_on_wrench_swing)
				if ws.has_signal("wrench_hit"):
					ws.wrench_hit.connect(_on_wrench_hit)


# --- Signal callbacks ---

func _on_player_glob_fired() -> void:
	play_sfx("glob_fire")

func _on_glob_matched(_targets) -> void:
	play_sfx("glob_match")

func _on_glob_failed(_pattern) -> void:
	play_sfx("glob_fail")

func _on_wrench_swing() -> void:
	play_sfx("wrench_swing")

func _on_wrench_hit(_target, _damage) -> void:
	play_sfx("wrench_hit")

func _on_player_damaged(_amount: int) -> void:
	play_sfx("player_damage")

func _on_player_died() -> void:
	play_sfx("player_death")

func _on_player_dash() -> void:
	play_sfx("dash")

func _on_damage_taken(_amount: int) -> void:
	# GameManager's damage_taken — plays if player signal didn't catch it
	pass

func _on_enemy_killed(_total: int) -> void:
	play_sfx("enemy_death")

func _on_token_collected(_total: int) -> void:
	play_sfx("token_pickup")

func _on_combo_updated(combo: int) -> void:
	if combo >= 3:
		play_sfx("combo_hit")

func _on_game_over(_reason: String) -> void:
	play_sfx("player_death")
	_music_player.stop()
	_boss_music_player.stop()

func _on_level_complete(_level: int) -> void:
	play_sfx("boss_defeated")

func _on_dialogue_advanced() -> void:
	play_sfx("dialogue_advance")


# --- Public API for level scripts to call directly ---

func play_enemy_alert() -> void:
	play_sfx("enemy_alert")

func play_enemy_attack() -> void:
	play_sfx("enemy_attack")

func play_boss_phase() -> void:
	play_sfx("boss_phase")

func play_boss_attack() -> void:
	play_sfx("boss_attack")

func play_boss_defeated() -> void:
	play_sfx("boss_defeated")
	stop_boss_music()

func play_puzzle_activate() -> void:
	play_sfx("puzzle_activate")

func play_puzzle_success() -> void:
	play_sfx("puzzle_success")

func play_puzzle_fail() -> void:
	play_sfx("puzzle_fail")

func play_checkpoint() -> void:
	play_sfx("checkpoint")

func play_jump() -> void:
	play_sfx("jump")

func play_land() -> void:
	play_sfx("land")

func play_footstep() -> void:
	play_sfx("footstep")

func play_hack_start() -> void:
	play_sfx("hack_start")

func play_hack_keypress() -> void:
	play_sfx("hack_keypress")

func play_hack_success() -> void:
	play_sfx("hack_success")

func play_hack_fail() -> void:
	play_sfx("hack_fail")

func play_ability_ready() -> void:
	play_sfx("ability_ready")

func play_context_overflow() -> void:
	play_sfx("context_overflow")

func play_menu_back() -> void:
	play_sfx("menu_back")


# --- Volume control ---

func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	_music_player.volume_db = linear_to_db(music_volume) + BASE_VOLUME_DB
	_boss_music_player.volume_db = linear_to_db(music_volume) + BASE_VOLUME_DB

func set_ambient_volume(vol: float) -> void:
	ambient_volume = clampf(vol, 0.0, 1.0)
	_ambient_player.volume_db = linear_to_db(ambient_volume) + BASE_VOLUME_DB - 4.0

func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)

func set_ui_volume(vol: float) -> void:
	ui_volume = clampf(vol, 0.0, 1.0)
