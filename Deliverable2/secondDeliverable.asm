.include "constants.inc"

.include "header.inc"

.segment "ZEROPAGE"
current_player_x: .res 1
current_player_y: .res 1
sprite_offset: .res 1
choose_sprite_orientation: .res 1
tick_count: .res 1
wings_flap_state: .res 1 ; wings_flap_state: 0 -> wings are open, wings_flap_state: 1 -> wings are closed
.exportzp sprite_offset, choose_sprite_orientation, tick_count, wings_flap_state
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
  JSR update_tick_count ;Handle the update tick (resetting to zero or incrementing)
  JSR update
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

  ;initialize wings_flap_state to zero
  LDA #$00
  STA wings_flap_state

  load_palettes:
    LDA palettes, X
    STA PPUDATA
    INX
    CPX #$20 ; amount of total colors in palettes
    BNE load_palettes


; display_tile subroutine
; tile_index -> $00
; low byte -> $01
; high byte -> $02


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

.proc update_tick_count
  LDA tick_count       ; Load the updated tick_count into A for comparison
  CLC                  ; Clear the carry flag
  ADC #$1              ; Add one to the A register

  CMP #$3C              ; Compare A (tick_count) with 0x3C -> 60
  BEQ reset_tick       ; If equal, branch to resetCount label

  CMP #$1E              ; Compare A again (tick_count) with 0x1E -> 30
  BNE done              ; If not equal, we are done, skip to done label
  
  ; If CMP #30 was equal, fall through to here
  STA tick_count
  LDA #$01
  STA wings_flap_state
  RTS            

reset_tick:
  LDA #$00             ; Load A with 0
  STA tick_count       ; Reset tick_count to 0 
  STA wings_flap_state    
  RTS

done:
  STA tick_count
  RTS
.endproc

.proc update
  ;UP 
  LDA #$70 ; Y-Coordinate
  sta current_player_y
  LDA #$70 ; X coordinate
  STA current_player_x 
  LDA #$00
  STA choose_sprite_orientation
  JSR draw_player

  ; Right
  LDA #$80 ; Y-Coordinate
  sta current_player_y
  LDA #$80 ; X coordinate
  STA current_player_x 
  LDA #$10
  STA choose_sprite_orientation
  JSR draw_player

  ;Left
  LDA #$80 ; Y-Coordinate
  sta current_player_y
  LDA #$60 ; X coordinate
  STA current_player_x 
  LDA #$20
  STA choose_sprite_orientation
  JSR draw_player

  

  ;Down
  LDA #$90 ; Y-Coordinate
  STA current_player_y
  LDA #$70 ; X coordinate
  STA current_player_x 
  LDA #$30
  STA choose_sprite_orientation
  JSR draw_player

  RTS
.endproc

.proc draw_player
; save registers

; pull the coordinates of the players from the stack
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA wings_flap_state
  CMP #$00              ; Compare if wings_flap_state is 0 to skip close_wings
  BEQ continue          ;

  close_wings:          ; If wings_flap_state is one then this label is executed

    LDA choose_sprite_orientation
    CLC
    ADC #$04
    STA choose_sprite_orientation

  continue:             ; Continue drawing the sprite

  LDX sprite_offset
  LDY choose_sprite_orientation
  ; store tile numbers
  ; write player ship tile numbers
  ; tile numbers were changed to be able to draw 

    ; Y register contains the index offset needed to display the sprite at a specific orientation/posture
  TYA
  CLC 
  ADC #$01 ; top left
  STA $0201, X

  TYA
  CLC 
  ADC #$03 ; top right
  STA $0205, X

  TYA
  CLC 
  ADC #$02; bottom left
  STA $0209, X

  TYA
  CLC 
  ADC #$04; bottom right
  STA $020d, X
  ; store attributes
; use palette 0
  LDA #$00
  STA $0202, X
  STA $0206, X
  STA $020a, X
  STA $020e, X


  ; store tile locations
  ; top left tile:
  LDA current_player_y
  STA $0200, X
  LDA current_player_x
  STA $0203, X

  ; top right tile (x + 8):
  LDA current_player_y
  STA $0204, X
  LDA current_player_x
  CLC
  ADC #$08
  STA $0207, X

  ; bottom left tile (y + 8):
  LDA current_player_y
  CLC
  ADC #$08
  STA $0208, X
  LDA current_player_x
  STA $020b, X

  ; bottom right tile (x + 8, y + 8)
  LDA current_player_y
  CLC
  ADC #$08
  STA $020c, X
  LDA current_player_x
  CLC
  ADC #$08
  STA $020f, X


    LDA sprite_offset
    CLC
    ADC #$10 ;Cordero, incrementing by 16
    STA sprite_offset ; sprite_offset += 16 
  ; restore registers and return
   PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
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


.segment "CHR"
; .res 8192 ; reservar 8,179 bytes of empty space 
.incbin "sprite_and_background.chr"
