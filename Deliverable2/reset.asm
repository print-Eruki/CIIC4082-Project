.include "constants.inc"

.segment "ZEROPAGE"
.importzp sprite_offset, choose_sprite_orientation, tick_count

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
  STA choose_sprite_orientation
  STA tick_count

  JMP main
.endproc
