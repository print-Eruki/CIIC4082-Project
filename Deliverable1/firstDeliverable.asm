.include "constants.inc"

.include "header.inc"
.segment "CODE"
.proc irq_handler
  RTI
.endproc
; TODO: change palette colors of the background to match the ones I have in NEXXT and figure out how to draw what I have in the NEXXT session

; dudas: no se porque solamente dibuja hasta cierto punto aunque le incremente la X. Tambien no se porque algunos bricks del background usan una paleta y otros usan otro
.proc nmi_handler
; OAM is highly unstable so it needs to be continuously refreshed. that's why we write to it here 60 times per second
  LDA #$00 ; TELLS it to prepare for transfer of sprite data from address $0200 
  STA OAMADDR
  LDA #$02 ; once stored to OAMDMA, high speed transfer begins of 256 bytes from $0200 - $02ff into OAM
  STA OAMDMA
  LDA #$00
  STA PPUSCROLL ; $2005 IS PPU SCROLL, it takes two writes: X Scroll , Y Scroll
  STA PPUSCROLL
  RTI
.endproc

.import reset_handler

.export main
.proc main
  LDX PPUSTATUS ; READ from PPUSTATUS to reset it and guarantee that the next byte that is loaded to it, will be a high byte
  LDX #$3f ; ppu only cares about color stored at $3f00, then it just uses that
  STX PPUADDR
  LDX #$00
  STX PPUADDR
;   LDA #$08 ; HERE we are choosing a color -> THE FIRST COLOR for the palette
;   STA PPUDATA ; storing color to PPUDATA


  load_palettes:
    LDA palettes, X
    STA PPUDATA
    INX
    CPX #$20 ; amount of total colors in palettes
    BNE load_palettes


;  LDX #$00
;   write_sprites:
;   LDA sprites, X
;   STA $0200, X ; $0200 is sprite buffer
;   INX
;   CPX #$10
;   BNE write_sprites
; store X into a specific memory address to keep track of how far we are from the memory address of $0200 (sprite buffer)

; STX $1f ; using $1f address to store how far we are from the memory address of $0200

; background to draw star:

; LDX #$00
; LDA PPUSTATUS
;   draw_steel_bricks:
;   LDA #$20
;   STA PPUADDR
;   LDA #$40 ; Address of where in the nametable we want to draw
;   CLC ; clear carry flag
;    STX $00
;    ADC $00 ; accumulator holds #$40 + X
;   STA PPUADDR
;   LDA #$06; $06 IS THE TILE NUMBER of the STEEL BRICK

;   STA PPUDATA
;   INX
;   CPX #$40
;   bne draw_steel_bricks
; ; do a while loop that changes the palette that is chosen for the steel bricks
; LDY #$00

; set_steel_brick_palette:
;   ; finally, attribute table -> this seems to not be working
;   LDA PPUSTATUS
;   LDA #$23
;   STA PPUADDR
;   LDA #$C0
;     CLC
;     STY $00; store Y register to $00
;     ADC $00
 
;   STA PPUADDR ; storing #$C0 + Y to PPUADDR
;   LDA #%01010000
;   STA PPUDATA
;   INY
;   CPY #$08 ; 
;   BNE set_steel_brick_palette



; display_tile subroutine
; tile_index -> $00
; low byte -> $01
; high byte -> $02
LDX #$03 ; #$03 is the steel tile
STX $00

LDX #$69 ; low byte
STX $01

LDX #$21; high byte
STX $02
jsr display_tile

; set attribute table for steel tile
  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$D2
  STA PPUADDR
  LDA #%00010000
  STA PPUDATA

LDX #$02 ; #$02 is the brick tile
STX $00

LDX #$6C ; low byte
STX $01

LDX #$21; high byte
STX $02
jsr display_tile




LDX #$01 ; #$01 is the bush tile
STX $00

LDX #$70 ; low byte
STX $01

LDX #$21; high byte
STX $02
jsr display_tile

; set attribute table for bush tile
  LDA PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$D4
  STA PPUADDR
  LDA #%00100000
  STA PPUDATA
; dislay_sprite subroutine:
; parameters:
; how far we are from sprite buffer -> $1F (SHOULD ALREADY BE THERE)
; Y-position of sprite -> $01
; TILE NUMBER -> $02
; ATTRIBUTES -> $03
; X-COORD -> $04

; Y-COORD, TILE NUMBER, ATTRIBUTES, X-COORD
; .byte $70, $04, $00, $80 ; need 4 bytes to describe a single sprite
ldx #$90; Y-Coord
STX $01
LDX #$04 ; Tile Number
STX $02
LDX #$00 ; attributes
STX $03
LDX #$80 ; X-coord
STX $04

jsr display_sprite

ldx #$98; Y-Coord
STX $01
LDX #$14 ; Tile Number
STX $02
LDX #$00 ; attributes
STX $03
LDX #$80 ; X-coord
STX $04

jsr display_sprite
JMP vblankwait


vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10010000  ; turn on NMIs, sprites use first pattern table
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK

forever:
  JMP forever
.endproc

; display_tile subroutine
; tile_index -> $00
; low byte -> $01
; high byte -> $02
.proc display_tile
  LDA PPUSTATUS; 
  LDA $02 ; LOADING highbyte to the accumulator
  STA PPUADDR
  LDA $01 ; LOADING lowbyte to the accumulator
  STA PPUADDR

  LDA $00
  STA PPUDATA
  
  rts ; return from subroutine
.endproc


; dislay_sprite subroutine:
; parameters:
; how far we are from sprite buffer -> $1F (SHOULD ALREADY BE THERE)
; Y-position of sprite -> $01
; TILE NUMBER -> $02
; ATTRIBUTES -> $03
; X-COORD -> $04
.proc display_sprite
  LDX $1F ; X holds how far we are from sprite buffer (which is stored in $1f)
  LDY #$00 ; Y is our index for the loop, we loop until Y is 4
  write_sprite_loop:
    LDA $01, Y ; accumulator holds the current sprite characteristic, which will be address $01 with an offset of Y
    STA $0200, X 
    INX
    INY
    CPY #$04
    BNE write_sprite_loop
  ; store what is in X back to $1f, to know how far we are from the sprite buffer
  STX $1F
  rts
.endproc
.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler
.segment "RODATA"

palettes:


; Background Palettes
.byte $0f, $16, $21, $30
.byte $0f, $10, $18, $20
.byte $0f, $19, $2A, $09
.byte $0f, $16, $09, $20

; Sprite Palettes
.byte $0f, $29, $19, $09 ; we already loaded the first color of this palette above
.byte $0f, $2C, $16, $09
.byte $0f, $04, $28, $11 
.byte $0f, $04, $28, $11

sprites:
; Y-COORD, TILE NUMBER, ATTRIBUTES, X-COORD
.byte $70, $04, $00, $80 ; need 4 bytes to describe a single sprite
.byte $70, $06, $00, $88
.byte $78, $07, $00, $80 ; using an offset of $08 between the adjacent tiles
.byte $78, $08, $00, $88
; choose sprite palette number with the last 2 bits of the attribute 

; low_byte_nametable_locations:
; .byte $63, $64, $83, $84

.segment "CHR"
; .res 8192 ; reservar 8,179 bytes of empty space 
.incbin "sprite_and_background.chr"
