.include "constants.inc"

.include "header.inc"
; lets make the subroutine that displays 4 tiles (top left, top right, bottom left, bottom right) and test it to print in address: 2100
.segment "ZEROPAGE"
current_player_x: .res 1
current_player_y: .res 1
sprite_offset: .res 1
choose_sprite_orientation: .res 1
tick_count: .res 1
player_1_x: .res 1
player_1_y: .res 1
controller_read_output: .res 1
wings_flap_state: .res 1 ; wings_flap_state: 0 -> wings are open, wings_flap_state: 1 -> wings are closed
player_direction: .res 1 ; direction: UP -> 0 | RIGHT -> 16 (#$10) | LEFT -> 32 (#$20) | DOWN -> 48 (#$30)
tile_to_display: .res 1
high_byte_nametable_address: .res 1
low_byte_nametable_address: .res 1
current_byte_of_tiles: .res 1
fix_low_byte_row_index: .res 1
choose_which_background: .res 1 ; 0 -> background stage 1 part 1 | 1 -> stage 1 part 2 | 2 -> stage 2 part 1 | 3 -> stage 2 part 2
current_stage: .res 1 ; 1 -> stage 1 | 2 -> stage 2
ppuctrl_settings: .res 1
.exportzp sprite_offset, choose_sprite_orientation, player_1_x, player_1_y, tick_count, wings_flap_state, player_direction

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
 
  JSR update_tick_count ;Handle the update tick (resetting to zero or incrementing)

  JSR read_controller ; reads the controller and changes the player's location accordingly

  JSR update ; draws the player on the screen

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

  load_palettes:
    LDA palettes, X
    STA PPUDATA
    INX
    CPX #$20 ; amount of total colors in palettes
    BNE load_palettes


lda #$01
sta current_stage
; preguntart en que stage tu estas
; choose_which background = 0

LDY #$00
sty fix_low_byte_row_index
STY low_byte_nametable_address
LDA #$00 ; background stage 1 part 1
STA choose_which_background
LDA #$20
STA high_byte_nametable_address

JSR display_background


LDY #$00
sty fix_low_byte_row_index
STY low_byte_nametable_address
LDA #$01 ; stage 1 part 2
STA choose_which_background
LDA #$24
STA high_byte_nametable_address

JSR display_background




; LDX #$20
; STX high_byte_nametable_address
; LDX #$18
; STX low_byte_nametable_address
; LDX #$AA ; 10 10 10 10
; stx current_byte_of_tiles
; jsr display_byte_of_tiles

; lda #$e0
; ; LDA low_byte_nametable_address
; ; clc
; ; adc #$20
; sta low_byte_nametable_address
; ; LDX #$20
; ; STX high_byte_nametable_address
; ; LDX #$e0
; ; STX low_byte_nametable_address
; LDX #$AA ; 10 10 10 10
; stx current_byte_of_tiles
; jsr display_byte_of_tiles

; LDX #$20
; STX high_byte_nametable_address
; LDX #$10
; STX low_byte_nametable_address
; LDX #$AA ; 10 10 11 01
; stx current_byte_of_tiles
; jsr display_byte_of_tiles

; LDX #$06 ; tile
; STX tile_to_display
; LDX #$20
; STX high_byte_nametable_address
; LDX #$EF
; STX low_byte_nametable_address
; jsr display_4_background_tiles

; set attribute table for bush tile
  ; LDA PPUSTATUS
  ; LDA #$23
  ; STA PPUADDR
  ; LDA #$D4
  ; STA PPUADDR
  ; LDA #%00100000
  ; STA PPUDATA



vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10010000  ; turn on NMIs, sprites use first pattern table
  STA PPUCTRL
  sta ppuctrl_settings
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
; 00000100
  LDA $00
  STA PPUDATA
  
  rts ; return from subroutine
.endproc

; PARAMS:
; fix_low_byte_row_index -> should be set to zero (will go from 0 to 4 then back to 0)
; low_byte_nametable_address
; high_byte_nametable_address
; choose_which_background
.proc display_background
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

load_background:
  LDA choose_which_background
  CMP #$00
  BNE test_for_stage_1_part_2

    LDA background_stage_1_part_1, Y
    JMP background_selected

test_for_stage_1_part_2:
  CMP #$01
  BNE test_for_stage_2_part_1

    LDA background_stage_1_part_2, Y
    JMP background_selected
test_for_stage_2_part_1:
  CMP #$02
  BNE test_for_stage_2_part_2

    LDA background_stage_2_part_1, Y
    jmp background_selected

test_for_stage_2_part_2:
  ; at this point, this is practically an ELSE statement so it must be stage 2 part 2
    LDA background_stage_2_part_2, Y

  background_selected:
  
  STA current_byte_of_tiles
  JSR display_byte_of_tiles
  INY
  increment_fix_low_byte_row_index:
    lda fix_low_byte_row_index
    clc
    adc #$01
    sta fix_low_byte_row_index
  lda fix_low_byte_row_index
  cmp #$04 ; compare if fix_low_byte_row_index is 4
  BNE skip_low_byte_row_fix
    ; lda #$e0
    lda low_byte_nametable_address
    clc
    adc #$20 ; add 32 to skip to the next row
    sta low_byte_nametable_address
    bcc skip_overflow_fix_2
      ; if PC is here, then add 1 to high byte because of overflow
      lda high_byte_nametable_address
      clc
      adc #$01
      sta high_byte_nametable_address
    skip_overflow_fix_2:
      LDA #$00
      sta fix_low_byte_row_index

  skip_low_byte_row_fix:
    cpy #$3C
    bne load_background

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP 
RTS
.endproc

; PARAMS:
; current_byte_of_tiles
; tile_to_display
; high_byte_nametable_address 
; low_byte_nametable_address (must be updated within function)

.proc display_byte_of_tiles
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA
  ldx #$00 ; X will be our index to run the loop 4 times
  process_byte_of_tiles_loop:
    LDA #$00
    STA tile_to_display ; clear the tile to display var to zero (since we might have left over bits from previous loops)
    ASL current_byte_of_tiles ; place 7th bit of current_byte_of_tiles in CARRY flag and place a 0 in the current_byte_of_tiles (shift left)
    ROL tile_to_display ; rotate left the carry flag onto tile_to_display : C <- 7 6 5 4 3 2 1 0 <- C
    ASL current_byte_of_tiles ; C <- 7 6 5 4 3 2 1 0 <- 0
    ROL tile_to_display
    ; ask in which stage you are in
    ; si estas en stage 2 pues sumale 4 al tile to display
    lda current_stage
    CMP #$01
    BEQ skip_addition_to_display
      ; here it's stage 2
      lda tile_to_display
      clc
      adc #$04
      sta tile_to_display

    skip_addition_to_display:
    JSR display_4_background_tiles

    LDA low_byte_nametable_address
    CLC 
    ADC #$02 
    STA low_byte_nametable_address ; low_byte_nametable_address += 2
    
    BCC skip_overflow_fix
    ; MUST CHECK FOR OVERFLOW HERE !!! CHECK CARRY FLAG
    ;if there was overflow when adding 2 to low_byte, then increase high_byte by 1. Low_byte should have correct value already
    LDA high_byte_nametable_address
    CLC
    ADC #$01
    sta high_byte_nametable_address

    skip_overflow_fix:
      INX
      CPx #$04
      Bne process_byte_of_tiles_loop

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP   



RTS
.endproc

; PARAMS:
; tile_to_display
; high_byte_nametable_address
; low_byte_nametable_address
.proc display_4_background_tiles
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

LDA PPUSTATUS ; Read from PPUSTATUS ONCE to ensure that the next write to ppuaddr is the high byte (reset it)
; TOP LEFT
  LDA high_byte_nametable_address
  STA PPUADDR
  LDA low_byte_nametable_address
  STA PPUADDR
  LDA tile_to_display
  STA PPUDATA

; TOP RIGHT
  LDA high_byte_nametable_address
  STA PPUADDR
  LDA low_byte_nametable_address
  CLC ; CLEAR CARRY FLAG BEFORE ADDING
  ADC #$01 ; adding 1 to low byte nametable_address
  STA PPUADDR
  LDA tile_to_display
  STA PPUDATA



  ; bottom LEFT
  LDX #$00
  JSR handle_bottom_left_or_right

  ; bottom RIGHT
  ldx #$01
  jsr handle_bottom_left_or_right

   PLA
  TAY
  PLA
  TAX
  PLA
  PLP


RTS
.endproc

.proc handle_bottom_left_or_right
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA
  ; BEFORE CALLING THIS SUBROUTINE: 
  ; if X is 0 then we are handling bottom left tile
  ; if X is 1 then we are handling bottom right tile
  TXA
  CMP #$01
  beq add_to_low_byte_right_version

  LDA low_byte_nametable_address
  CLC ; CLEAR CARRY FLAG BEFORE ADDING
  ADC #$20 ; adding 32 to low byte nametable_address
  jmp check_overflow

add_to_low_byte_right_version:
  LDA low_byte_nametable_address
  CLC ; CLEAR CARRY FLAG BEFORE ADDING
  ADC #$21 ; adding 33 to low byte nametable_address

check_overflow:
  ; MUST CHECK IF CARRY FLAG WAS ACTIVATED
  BCC add_with_no_overflow

  ; if Program Counter is here, there was OVERFLOW
  ; if carry was SET: then we must add 1 to the high byte and set low_byte to 00
  LDA high_byte_nametable_address
  clc 
  adc #$01 ; accumulator = high_byte + 1
  sta PPUADDR
  TXA
  cmp #$01 ; check if we are handling right tile
  beq store_low_byte_for_right

  ; LOW BYTE FOR LEFT
  lda low_byte_nametable_address
  clc 
  adc #$20 ; an overflow will occur BUT, the accumulator will contain the correct value for the low byte
  STA PPUADDR 
  jmp store_tile_to_ppu

  store_low_byte_for_right:
  lda low_byte_nametable_address
  clc 
  adc #$21
  STA PPUADDR
  jmp store_tile_to_ppu
  
add_with_no_overflow: 
  ; IF THERE WAS NO OVERFLOW -> high_byte stays the same
  LDA high_byte_nametable_address
  sta PPUADDR
  TXA
  cmp #$01
  beq store_low_byte_for_right_no_overflow

  LDA low_byte_nametable_address
  CLC ; CLEAR CARRY FLAG BEFORE ADDING
  ADC #$20 
  sta PPUADDR
  jmp store_tile_to_ppu

store_low_byte_for_right_no_overflow:
  LDA low_byte_nametable_address
  CLC ; CLEAR CARRY FLAG BEFORE ADDING
  ADC #$21 ; accumulator = low_byte + 0x21 since we are handling the right tile
  sta PPUADDR

store_tile_to_ppu:

  LDA tile_to_display
  STA PPUDATA


  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
RTS
.endproc
.proc update_tick_count
  LDA tick_count       ; Load the updated tick_count into A for comparison
  CLC                  ; Clear the carry flag
  ADC #$1              ; Add one to the A register

  CMP #$28               ; Compare A (tick_count) with 0x28 -> 40
  BEQ reset_tick       ; If equal, branch to resetCount label

  CMP #$14            ; Compare A again (tick_count) with 0x14 -> 20
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
; update method is in charge of drawing the player at that player's location.
  ; draw player subroutine:
  ; push to stack the Y coordinate and the X coordinate
  LDA #$00
  STA sprite_offset ; set sprite off set to be zero before drawing any sprites

  LDA player_direction ; direction: UP -> 0 | RIGHT -> 16 (#$10) | LEFT -> 32 (#$20) | DOWN -> 48 (#$30)
  STA choose_sprite_orientation 

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

;  ; direction: UP -> 0 | RIGHT -> 16 (#$10) | LEFT -> 32 (#$20) | DOWN -> 48 (#$30)

ReadA:
  LDA controller_read_output
  AND #%10000000
  beq ReadADone
  LDA tick_count
  cmp #$00
  bne ReadADone
  ; only runs if A is pressed and tick_count is 0
  LDA ppuctrl_settings
  EOR #%00000001 ; flip bit #1 to its opposite
  STA ppuctrl_settings
  STA PPUCTRL

ReadADone:

; Reads A and the right arrow key to turn right
ReadRightArrowKey: ; en el original NES controller, la A está a la derecha así que la "S" en el teclado es la A

  LDA controller_read_output
  AND #%00000001 ; BIT MASK to look if accumulator holds a value different than 0 after performing the AND
  ; here we are checking to see if the A was pressed
  BEQ ReadRightArrowKeyDone
  
  ; if A is pressed, move sprite to the right
  LDA player_1_x
  CLC
  ADC #$01 ; x = x + 1
  STA player_1_x
  LDA #$10
  STA player_direction

  ReadRightArrowKeyDone:

; reads B and the left arrow key to turn left
ReadB: ; la "A" en el teclado de la computadora es la B en el NES
  LDA controller_read_output
  AND #%01000010 ; BIT MASK to look if accumulator holds a value different than 0
  BEQ ReadBDone

  ; if A is pressed, move sprite to the right
  LDA player_1_x
  SEC ; make sure the carry flag is set for subtraction
  SBC #$01 ; X = X - 1
  sta player_1_x
  LDA #$20
  STA player_direction

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
  LDA #$00 ; UP is 0
  STA player_direction

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
  LDA #$30 ; DOWN is $30 (48 in decimal)
  STA player_direction

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

background_stage_1_part_1:
.byte $B1, $B1, $B1, $B1
; .byte $AA, $AA, $AA, $AA
.byte $8D, $4D, $40, $02
.byte $8D, $CD, $FC, $F2
.byte $8D, $CD, $CC, $F2
.byte $80, $CD, $CC, $F6
.byte $80, $CF, $CC, $F0
.byte $B0, $C0, $00, $FE
.byte $B0, $CF, $FC, $02
.byte $B0, $CC, $00, $02
.byte $B0, $FF, $FC, $FE
.byte $B0, $43, $0C, $FE
.byte $B0, $C3, $0C, $02
.byte $00, $C3, $0F, $F2
.byte $B0, $C3, $00, $02
.byte $AA, $AA, $AA, $AA

background_stage_1_part_2:
  .byte $aa,$aa,$aa,$aa
  .byte $95,$40,$00,$32
  .byte $9f,$ff,$fc,$42
  .byte $95,$00,$0f,$02
  .byte $bf,$f0,$5c,$c2
  .byte $00,$00,$dc,$12
  .byte $bf,$03,$5f,$1e
  .byte $bc,$0f,$00,$c6
  .byte $b0,$04,$0f,$06
  .byte $80,$0c,$0c,$02
  .byte $9f,$ff,$0c,$32
  .byte $8f,$13,$0c,$c0
  .byte $8f,$33,$ff,$02
  .byte $80,$30,$00,$02
  .byte $aa,$aa,$aa,$aa


background_stage_2_part_1:
.byte $AA, $AA, $AA, $AA
.byte $8D, $4D, $40, $02
.byte $8D, $CD, $FC, $F2
.byte $8D, $CD, $CC, $F2
.byte $80, $CD, $CC, $F6
.byte $80, $CF, $CC, $F0
.byte $B0, $C0, $00, $FE
.byte $B0, $CF, $FC, $02
.byte $B0, $CC, $00, $02
.byte $B0, $FF, $FC, $FE
.byte $AA, $AA, $AA, $AA
.byte $AA, $AA, $AA, $AA
.byte $AA, $AA, $AA, $AA
.byte $AA, $AA, $AA, $AA
.byte $AA, $AA, $AA, $AA

background_stage_2_part_2:
.byte $AA, $AA, $AA, $AA
.byte $AA, $AA, $AA, $AA
.byte $AA, $AA, $AA, $AA
.byte $AA, $AA, $AA, $AA
.byte $80, $CD, $CC, $F6
.byte $80, $CF, $CC, $F0
.byte $B0, $C0, $00, $FE
.byte $B0, $CF, $FC, $02
.byte $B0, $CC, $00, $02
.byte $B0, $FF, $FC, $FE
.byte $B0, $43, $0C, $FE
.byte $B0, $C3, $0C, $02
.byte $00, $C3, $0F, $F2
.byte $B0, $C3, $00, $02
.byte $AA, $AA, $AA, $AA

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
