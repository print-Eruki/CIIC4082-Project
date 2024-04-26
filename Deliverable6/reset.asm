.include "constants.inc"

.segment "ZEROPAGE"
.importzp sprite_offset, is_behind_bush, player_1_x, player_1_y, tick_count, current_background_map, choose_sprite_orientation, wings_flap_state, player_direction, scroll, flag_scroll, is_stage_part_2, timer_first_digit, timer_second_digit, timer_third_digit, is_game_over, is_stage_cleared

.segment "CODE"
.import main
.export reset_handler
.proc reset_handler
  SEI
  CLD
  LDX #$40
  STX $4017
  LDX #$FF
  TXS
  INX
  STX $2000
  STX $2001
  STX $4010
  BIT $2002
vblankwait:
  BIT $2002
  BPL vblankwait

	LDX #$00
	LDA #$FF
clear_oam:
	STA $0200,X ; set sprite y-positions off the screen
	INX
	INX
	INX
	INX
	BNE clear_oam

vblankwait2:
  BIT $2002
  BPL vblankwait2

; initialize zero-page values
  LDA #$00
  STA sprite_offset
  STA tick_count
  STA player_direction
  STA wings_flap_state
  STA choose_sprite_orientation
  STA scroll
  STA flag_scroll
  STA current_background_map
  STA is_behind_bush
  STA is_stage_part_2
  STA is_game_over
  STA is_stage_cleared
  
  ;LOAD timer initial time
  LDA #$00
  STA timer_first_digit
  LDA #05
  STA timer_second_digit
  LDA #00
  STA timer_third_digit

  ;INITIAL TIMER IS SET TO 059

; set x, y coords for player_1
  LDA #$00
  STA player_1_x
  LDA #$BF
  STA player_1_y
  JMP main
.endproc
