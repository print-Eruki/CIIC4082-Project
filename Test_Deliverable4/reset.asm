.include "constants.inc"

.segment "ZEROPAGE"
.importzp sprite_offset, player_1_x, player_1_y, tick_count, choose_sprite_orientation, wings_flap_state, player_direction

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

; set x, y coords for player_1
  LDA #$50
  STA player_1_x
  LDA #$70
  STA player_1_y
  JMP main
.endproc
