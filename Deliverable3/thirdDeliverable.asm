.include "constants.inc"

.include "header.inc"

.segment "ZEROPAGE"
current_player_x: .res 1
current_player_y: .res 1
sprite_offset: .res 1
choose_sprite_orientation: .res 1
tick_count: .res 1
player_1_x: .res 1
player_1_y: .res 1
controller_read_output: .res 1
.exportzp sprite_offset, player_1_x, player_1_y, tick_count

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

  JSR read_controller ; reads the controller and changes the player's location accordingly

  JSR update ; draws the player on the screen


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
  ADC #$01              ; Add one to the A register

  CMP #$3F              ; Compare A (tick_count) with 0x3C -> 60
  BEQ reset_tick       ; If equal, branch to resetCount label

  CMP #$1E              ; Compare A again (tick_count) with 0x1E -> 30
  BNE done              ; If not equal, we are done, skip to done label
  
  ; If CMP #30 was equal, fall through to here
  STA tick_count
  LDA #$04             ; Load A with 04 for chosing sprite orientation
  STA choose_sprite_orientation    
  RTS            

reset_tick:
  LDA #$00             ; Load A with 0
  STA tick_count       ; Reset tick_count to 0              
  STA choose_sprite_orientation    ; Reset sprite offset to 00 (first animation)

done:
  STA tick_count
  RTS
.endproc

.proc update
; update method is in charge of drawing the player at that player's location.
  ; draw player subroutine:
  ; push to stack the Y coordinate and the X coordinate
  LDA #$00
  STA sprite_offset ; set sprite off set to be zero before drawing any sprites


  LDA player_1_y; Y-Coordinate
  sta current_player_y
  LDA player_1_x; X coordinate
  STA current_player_x 
  JSR draw_player
  RTS
.endproc

.proc read_controller
  LDA #1
  STA controller_read_output ; store it with 1 so that when that 1 gets passed to the carry flag after 8 left shifts, we can break out of the loop

LatchController:
  lda #$01
  STA $4016
  LDA #$00
  STA $4016  

; after the following loop: the controller_read_output var will contain the status of all of the buttons (if they were pressed or not) 
read_controller_loop:
  LDA $4016
  lsr A ; logical shift right to place first bit of accumulator to the carry flag
  ROL controller_read_output ; rotate left, place left most bit in controller_read_output to carry
  ;  and place what was in carry flag to the right most bit ofcontroller_read_output

  bcc read_controller_loop

; Reads A and the right arrow key to turn right
ReadA: ; en el original NES controller, la A está a la derecha así que la "S" en el teclado es la A
  ; LDA $4016
  LDA controller_read_output
  AND #%10000001 ; BIT MASK to look if accumulator holds a value different than 0 after performing the AND
  ; here we are checking to see if the A was pressed
  BEQ ReadADone

  ; if A is pressed, move sprite to the right
  LDA player_1_x
  CLC
  ADC #$01 ; x = x + 1
  STA player_1_x

  ReadADone:

; reads B and the left arrow key 
ReadB: ; la "A" en el teclado de la computadora es la B en el NES
  LDA controller_read_output
  AND #%01000010 ; BIT MASK to look if accumulator holds a value different than 0
  BEQ ReadBDone

  ; if A is pressed, move sprite to the right
  LDA player_1_x
  SEC ; make sure the carry flag is set for subtraction
  SBC #$01 ; X = X - 1
  sta player_1_x
 
  ReadBDone:

ReadUp:
  LDA controller_read_output
  AND #%00001000
  BEQ ReadUpDone

  ; if Up is pressed, move sprite up
  ; to move UP, we subtract from Y coordinate
  LDA player_1_y
  SEC 
  SBC #$01 ; Y = Y - 1
  STA player_1_y

  ReadUpDone:
  
ReadDown:
  LDA controller_read_output
  AND #%00000100
  BEQ ReadDownDone

  ; if Up is pressed, move sprite up
  ; to move UP, we subtract from Y coordinate
  LDA player_1_y
  CLC 
  ADC #$01 ; Y = Y + 1
  STA player_1_y

ReadDownDone:

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
