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
change_background_flag: .res 1
scroll: .res 1 ;used to increment the PPUSCROLL register
flag_scroll: .res 1 ; used to know when to write on ppuscroll
sprite_collisions_x: .res 1
sprite_collisions_y: .res 1
mega_index_x: .res 1
mega_index_y: .res 1
map_offset_index: .res 1
amt_double_left_shifts: .res 1
is_colliding: .res 1
current_background_map: .res 1
is_behind_bush: .res 1
is_checking_for_bush_transparency_flag: .res 1 ; flag that is set BEFORE calling check_collisions to see if we set transparency or not
is_stage_part_2: .res 1 ;flag that is set AFTER reaching part two of a stage.
timer_first_digit: .res 1 ; timer first digit from left to right let number = 250 then (2)50
timer_second_digit: .res 1 ; timer second digit from left to right let number = 250 then 2(5)0
timer_third_digit: .res 1 ; timer third digit from left to right let number = 250 then 25(0)
stage_1_first_digit: .res 1 
stage_1_second_digit: .res 1 
stage_1_third_digit: .res 1 
is_game_over: .res 1 ; flag that is SET if the player runs out of time (player loses)
is_stage_cleared: .res 1 ; flag that is SET if the player cleares both stages
.exportzp sprite_offset, is_behind_bush, choose_sprite_orientation, player_1_x, player_1_y, tick_count, wings_flap_state, player_direction, scroll, flag_scroll, current_background_map, is_stage_part_2, timer_first_digit, timer_second_digit, timer_third_digit, is_game_over, is_stage_cleared


.segment "CODE"
.proc irq_handler
  RTI
.endproc
; TODO: change palette colors of the background to match the ones I have in NEXXT and figure out how to draw what I have in the NEXXT session

.proc nmi_handler
; OAM is highly unstable so it needs to be continuously refreshed. that's why we write to it here 60 times per second
  LDA #$00 ; TELLS it to prepare for transfer of sprite data from address $0200 
  STA OAMADDR
  LDA #$02 ; once stored to OAMDMA, high speed transfer begins of 256 bytes from $0200 - $02ff into OAM
  STA OAMDMA
 
  JSR update_tick_count ;Handle the update tick (resetting to zero or incrementing)

  ;; Check if the the player is OUT of time
  LDA is_game_over
  CMP #$01
  BEQ game_end

  LDA #$00
  sta is_checking_for_bush_transparency_flag ; NOT checking for behind bush
  JSR read_controller ; reads the controller and changes the player's location accordingly

  LDA #$01
  STA is_checking_for_bush_transparency_flag
  lda player_1_x
  clc 
  adc #$08
  STA sprite_collisions_x

  LDA player_1_y
  clc 
  adc #$08
  STA sprite_collisions_y
  JSR check_collisions ; this check collisions is just to see if you are behind a bush or not
  JSR update ; draws the player on the screen

  LDA change_background_flag
  CMP #$01
  BNE skip_change_background
    ; LDA #$02
    ; STA current_stage

    reset_flags_player_x_player_y:
      ;LOAD the initial starting positions for stage 2
      LDA #31
      STA player_1_y; 
      STA current_player_y
      LDA #$00
      STA player_1_x; 
      STA current_player_x
    
    reset_new_timer_save_player_time:
      LDA #$01
      STA timer_first_digit
      LDA #$05
      STA timer_second_digit
      LDA #$09
      STA timer_third_digit

    

      ;RESET flags 
      LDA #$00
      STA flag_scroll  ;just in case for some reason this is set
      STA is_stage_part_2  ; Reseting 


    LDA #$00
    LDA current_stage 
    EOR #%11
    STA current_stage

    ; update which map we are currently in (swaps to 0 or 2 always)
  LDA current_background_map
  AND #%10 ; turn off the right most bit. 
  EOR #%10 ; this should make it swap from zero to 2 or from 2 to zero
  STA current_background_map

    jsr display_stage_background
    lda #$00
    sta change_background_flag
    
    reset_scrolling:
      LDA #$00
      STA scroll          ; reset scroll acumulator
      STA flag_scroll     ; reset scroll flag
      STA PPUSCROLL       ; PPUSCROLL_X = 0
      STA PPUSCROLL       ; PPUSCROLL_Y = 0

  skip_change_background:

  check_scrolling_flag:

    LDA flag_scroll
    CMP #$00
    BEQ skip_ppuscroll_write
    ;Load player x and check if we need to skip the decrease
    LDA player_1_x
    CMP #$01
    BEQ skip_player_x_dec

    DEC player_1_x

    skip_player_x_dec:

    INC scroll
    LDA scroll
    CMP #255
    BNE skip_clearing_scrolling_flag
    
    LDA #$00
    STA flag_scroll

    skip_clearing_scrolling_flag:

    ; determine if you are in map 0 or map 2
  
  ; if you are in map 0, this CONSTANTLY WRITES 1 to the current_background_map var 
      LDA current_background_map
      CMP #$00
      BNE check_for_map_2
        lda #$01
        sta current_background_map
      check_for_map_2:
  ; if you are in map 2, this CONSTANTLY WRITES 3 to the current_background_map var
        LDA current_background_map
        CMP #$02
        BNE exit_checking_for_map
          lda #$03
          STA current_background_map



     
      exit_checking_for_map:
      ; STA current_background_map
      ; LDA #255 ; ponerlo en 255 para que enseñe el otro nametable (el de la derecha0)
      LDA scroll
      STA PPUSCROLL
      LDA #$00
      STA PPUSCROLL

  skip_ppuscroll_write: ;Skip writing the ppuscroll until the player presses
  
  
  RTI
  game_end:
    LDA #$03
    STA current_stage
    JSR display_stage_background

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
JSR display_stage_background

vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10010000  ; turn on NMIs, sprites use first pattern table
  STA PPUCTRL
  sta ppuctrl_settings
  LDA #%00011110  ; turn on screen
  STA PPUMASK


  init_ppuscroll: ;Initialize ppu scroll to X -> 0 & Y -> 0
    LDA #$00
    STA PPUSCROLL
    STA PPUSCROLL

forever:
  JMP forever
.endproc

.proc draw_stage_cleared
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA
          ;;40
  LDX #$00
  loop:
    LDA stage_cleared, X
    STA $2004
    INX
    CPX #$40
    BNE loop

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP 
  RTS
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

; PARAMS
; current_stage --> 1 for stage 1 | 2 for stage 2 | 3 for game_over
.proc display_stage_background
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  disable_rendering:
    LDA #%00000000  ; turning off backgrounds and sprites
    STA PPUMASK

    
    LDA ppuctrl_settings  ;turn off NMI
    AND #%01111000
    STA PPUCTRL
    STA ppuctrl_settings

  LDA current_stage
  CMP #$02
  BEQ prep_stage_2 ; if current_stage is 2, then branch to prep for stage 2; else: jump to prep for stage 1
  CMP #$03 
  BEQ prep_game_over_stage


  prep_stage_1:
    ; current_stage = 1
    LDA #$00
    sta choose_which_background ; setting choose_which_background to 0 so it can choose the maps for stage 1

  JMP finished_preparing

  prep_stage_2:
    ; current_stage = 2
    LDA #$02
    sta choose_which_background

  prep_game_over_stage:
    ; current_stage = game_over (3)
    LDA #$04
    STA choose_which_background

  finished_preparing:
  LDY #$00
  sty fix_low_byte_row_index
  STY low_byte_nametable_address

  LDA #$20
  STA high_byte_nametable_address

  JSR display_one_nametable_background

    ; MUST ADD 1 to choose_which_background to display the SECOND part of that stage
      LDA choose_which_background
      clc
      adc #$01
      sta choose_which_background ; choose_which_background += 1
    

  LDY #$00
  sty fix_low_byte_row_index
  STY low_byte_nametable_address

  LDA #$24
  STA high_byte_nametable_address

  JSR display_one_nametable_background

  enable_rendering:

    LDA #%10010000  ; turn on NMIs, sprites use first pattern table
    STA PPUCTRL
    STA ppuctrl_settings
    LDA #%00011110  ; turn on screen
    STA PPUMASK


  PLA
  TAY
  PLA
  TAX
  PLA
  PLP 
RTS
.endproc

; PARAMS:
; fix_low_byte_row_index -> should be set to zero (will go from 0 to 4 then back to 0)
; low_byte_nametable_address
; high_byte_nametable_address
; choose_which_background
.proc display_one_nametable_background
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
  CMP #$03
  BNE test_game_over_screen ;;BLACK screen
  
  ; at this point, this is practically an ELSE statement so it must be stage 2 part 2
    LDA background_stage_2_part_2, Y
    JMP background_selected

test_game_over_screen: ;;this is practically an ELSE statement. it will land here when choose_which_background is 4 or 5 
  LDA black_stage, Y
  

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
    DEC timer_third_digit
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
  JSR draw_timer

  RTS
.endproc

.proc read_controller
  ;skip controller read when we are scrolling to the stage part 2
  LDA flag_scroll
  CMP #$00
  BEQ begin_read_controller

  RTS

  begin_read_controller:

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


  lda #$01
  sta change_background_flag

  ReadADone:

; reads B to start scroll
ReadB: 
  LDA controller_read_output
  AND #%01000000 
  BEQ ReadBDone

  ReadBDone:

; Reads the right arrow key to turn right
ReadRight: ; en el original NES controller, la A está a la derecha así que la "S" en el teclado es la A

  LDA controller_read_output
  AND #%00000001 ; BIT MASK to look if accumulator holds a value different than 0 after performing the AND
  ; here we are checking to see if the A was pressed
  BEQ ReadRightDone
  
  ; check for collisions on top right side: player_x + 15, player_y + 3
  lda player_1_x
  clc
  adc #$0F
  STA sprite_collisions_x

  lda player_1_y
  clc
  adc #$03
  STA sprite_collisions_y

  jsr check_collisions

  LDA is_colliding
  CMP #$01
  BEQ ReadRightDone

  ; check for collisions on bottom right side: player_x + 15, player_y + 14
  
  ; sprite_collisions_x should have the correct value already

  lda player_1_y
  clc
  adc #$0E
  sta sprite_collisions_y

  jsr check_collisions

  LDA is_colliding
  CMP #$01
  BEQ ReadRightDone 


    ; if A is pressed, move sprite to the right
    LDA player_1_x
    CLC
    ADC #$01 ; x = x + 1
    STA player_1_x
    LDA #$10
    STA player_direction

    ;check if the player has reached the end of the screen and/or part
    LDA player_1_x
    CMP #241
    BEQ set_scroll_flag  ;BRANCH if it's exactly 241
    BCS set_scroll_flag  ;BRANCH if it's greater than 241
    
    JMP ReadRightDone    ;SKIP if we dont need to set the scroll flag just yet

    set_scroll_flag:
      ;first check if we reach the end of stage part 2
      LDA is_stage_part_2
      CMP #$01
      BEQ go_to_next_stage

      LDA #$01
      STA flag_scroll
      STA is_stage_part_2
      JMP ReadRightDone ; skip stage change but CONTINUE reading the other buttons

      go_to_next_stage:
        lda #$01
        sta change_background_flag

  ReadRightDone:


; ; reads the left arrow key to turn left
readLeft: 
  LDA controller_read_output
  AND #%00000010 ; BIT MASK to look if accumulator holds a value different than 0
  BEQ ReadLeftDone


  ; check collisions for top left: player_x + 1, player_y + 3
  LDA player_1_x
  clc
  adc #$01
  sta sprite_collisions_x

  lda player_1_y
  clc
  adc #$03
  sta sprite_collisions_y

  jsr check_collisions

  LDA is_colliding
  CMP #$01
  BEQ ReadLeftDone 

; check collisions for bottom left: player_x + 1, player_y + 14

; sprite_collisions_x should already have the correct value

  lda player_1_y
  clc
  adc #$0E
  sta sprite_collisions_y

  jsr check_collisions

  LDA is_colliding
  CMP #$01
  BEQ ReadLeftDone 

    ; if A is pressed, move sprite to the right
    LDA player_1_x
    SEC ; make sure the carry flag is set for subtraction
    SBC #$01 ; X = X - 1
    sta player_1_x
    LDA #$20
    STA player_direction

  ReadLeftDone:

ReadUp:
  LDA controller_read_output
  AND #%00001000
  BEQ ReadUpDone

  ; check for collisions at (player_1_x + 2 , player_1_y + 2)
  LDA player_1_x
  clc
  adc #$02
  STA sprite_collisions_x

  LDA player_1_y
  clc
  adc #$02
  STA sprite_collisions_y

  JSR check_collisions

  ; if it's colliding, jump to readUpDone
  LDA is_colliding
  CMP #$01
  BEQ ReadUpDone

  ; check collisions for top right : player_x + 14, player_y + 2
  LDA player_1_x
  CLC
  ADC #$0E ; se le está añadiendo 14 porque si se le añade 8 pues realmente no está llegando a la 'ala' de la derecha arriba. Es como si llegaras hasta la mitad de la mariposa
  STA sprite_collisions_x

  ; sprite_collisions_y should already contain the correct value
  JSR check_collisions
  LDA is_colliding
  CMP #$01
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

  ; check for collisions at player_x + 2, player_y + 15
  LDA player_1_x
  clc
  ADC #$02
  STA sprite_collisions_x

  LDA player_1_y
  CLC 
  ADC #$0F
  sta sprite_collisions_y
  jsr check_collisions


   ; if it's colliding, jump to readDownDone
  LDA is_colliding
  CMP #$01
  BEQ ReadDownDone

  ; now check if it's colliding at player_x + 14, player_y + 15
  LDA player_1_x
  CLC
  ADC #$0E
  STA sprite_collisions_x

  ; sprite_collisions_y should already have its correct value
  JSR check_collisions

  ; if it's colliding, jump to readDownDone
  LDA is_colliding
  CMP #$01
  BEQ ReadDownDone


  ; if down is pressed, move sprite down
  ; to move DOWN, we subtract from Y coordinate
  LDA player_1_y
  CLC 
  ADC #$01 ; Y = Y + 1
  STA player_1_y
  LDA #$30 ; DOWN is $30 (48 in decimal)
  STA player_direction

ReadDownDone:

read_controller_done:

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

  ; here we must decide if we want the sprite to be transparent or not.
  LDA is_behind_bush ;this was changed to check for tile_to_display instead of is_behind_bush (reducing a var and some minor checks problem still persists)
  CMP #$01
  BEQ load_behind_bush_attributes
; use palette 0
  LDA #$00
  JMP set_sprite_attributes
  load_behind_bush_attributes:
    LDA #%00100000

  set_sprite_attributes:
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

.proc draw_digits
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA
  ;;Draw first digit
  
  LDX #$40
  LDA #2
  STA $0200, X ; Y-coord of first sprite
  LDA timer_first_digit
  CLC
  ADC #$40
  STA $0201, X; tile number of first sprite
  LDA #$00
  STA $0202, X ; attributes of first sprite
  LDA #210
  STA $0203, X ; X-coord of first sprite

  ;; Draw second number
  LDX #$50
  LDA #2
  STA $0200, X ; Y-coord of first sprite
  LDA timer_second_digit
  CLC
  ADC #$40
  STA $0201, X; tile number of first sprite
  LDA #$00
  STA $0202, X ; attributes of first sprite
  LDA #219
  STA $0203, X ; X-coord of first sprite

  ;; Draw third number
  LDX #$60
  LDA #2
  STA $0200, X ; Y-coord of first sprite
  LDA timer_third_digit
  CLC
  ADC #$40
  STA $0201, X; tile number of first sprite
  LDA #$00
  STA $0202, X ; attributes of first sprite
  LDA #228
  STA $0203, X ; X-coord of first sprite


  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_timer
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA
  ;Before drawing the sprite we need to update
  check_if_timer_finished:
    LDA timer_first_digit
    CLC
    ADC timer_second_digit
    ADC timer_third_digit
    CMP #$00
    BNE skip_set_game_over_flag

    LDA #$01
    STA is_game_over
    LDA #$01
    STA timer_first_digit

    skip_set_game_over_flag:

  Update_timer:
    LDA timer_third_digit
    BMI reset_third_digit_dec_second_digit ;;Branch if minus -> this will branch if the number is negative
    JMP end_update_timer

    reset_third_digit_dec_second_digit:
      LDA #$09
      STA timer_third_digit
      DEC timer_second_digit
      LDA timer_second_digit
      BMI reset_second_digit_dec_first_digit
      JMP end_update_timer
      
    
    reset_second_digit_dec_first_digit:
      LDA #$09
      STA timer_second_digit
      DEC timer_first_digit

  end_update_timer:

  JSR draw_digits 


  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc


.proc check_collisions
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; mega_index_x = sprite_collisions_x // 64 (right shift 6 times)
  LDA sprite_collisions_x
    LSR A 
    LSR A 
    LSR A 
    LSR A 
    LSR A 
    LSR A 
  STA mega_index_x

  ;mega_index_y = sprite_collisions_y // 16 (right shift 4 times)
  LDA sprite_collisions_y
    LSR A
    LSR A
    LSR A
    LSR A
  STA mega_index_y

  ; map_offset_index = 4 * mega_index_y + mega_index_x

  ; to get 4 * mega_index_y let's shift left twice
  LDA mega_index_y
    ASL A
    ASL A
  ; at this point: accumulator holds: 4 * mega_index_y

  ; now let's add mega_index_x to the accumulator
  CLC
  ADC mega_index_x
  STA map_offset_index

  ; load the byte at map_offset_index from the current map (check which background you are displaying)
  
  ; HARD CODED TO ONLY CHECK FOR MAP 1
  LDX map_offset_index

  ; here we check for which map we are in to load the correct one.
  ; current_map:
  ; 0 - stage 1 part 1
  ; 1 - stage 1 part 2
  ; 2 - stage 2 part 1
  ; 3 - stage 2 part 2
  LDA current_background_map
  CMP #$00
  BNE check_map_stage_1_part_2

    LDA background_stage_1_part_1, X

     JMP exit_map_check

  check_map_stage_1_part_2:
    LDA current_background_map
    CMP #$01
    BNE check_map_stage_2_part_1

    LDA background_stage_1_part_2, X
      JMP exit_map_check

  check_map_stage_2_part_1:
    LDA current_background_map
    CMP #$02
    BNE check_map_stage_2_part_2

  LDA background_stage_2_part_1, X  
  jmp exit_map_check

  check_map_stage_2_part_2:
    LDA current_background_map
    CMP #$03
    BNE exit_map_check

    LDA background_stage_2_part_2, X


  exit_map_check:

  STA current_byte_of_tiles ; holds the byte of tiles from the map that we are in.


  ; calculate amt_double_left_shifts
  ; amt_double_left_shifts = (sprite_collisions_x % 64) // 16

  ; to perform mod 64, do an AND operation with 63
  LDA sprite_collisions_x
  AND #%00111111 ; 63 in decimal

  ;accumulator holds: sprite_collisions_x % 64
  ; now divide by 16 (shift right 4 times)
      LSR A
      LSR A
      LSR A
      LSR A
  STA amt_double_left_shifts

  
  ; compare with zero to see if we skip the double left shifts
  CMP #$00
  BEQ finished_double_left_shifts

 ; perform double left shifts on current_byte_of_tiles
  double_left_shifts_loop:
    ASL current_byte_of_tiles
    ASL current_byte_of_tiles

    DEC amt_double_left_shifts
    ; load amt_double_left_shifts to accumulator and compare to zero
    LDA amt_double_left_shifts
    CMP #$00
    BNE double_left_shifts_loop


  finished_double_left_shifts:

  ; now we must place the leftmost two bits (most significant two bits) from current_byte_of_tiles into the tile_to_display (we are not going to display this tile)
  LDA #$00
  sta tile_to_display ; set tile_to_display to be zero

  ASL current_byte_of_tiles ; place 7th bit of current_byte_of_tiles in CARRY flag and place a 0 in the current_byte_of_tiles (shift left)
  ROL tile_to_display ; rotate left the carry flag onto tile_to_display : C <- 7 6 5 4 3 2 1 0 <- C
  ASL current_byte_of_tiles ; C <- 7 6 5 4 3 2 1 0 <- 0
  ROL tile_to_display

  LDA is_checking_for_bush_transparency_flag
  CMP #$00
  Beq finish_checking_for_bush
  ; check if you are colliding with a bush to turn on flag
  
  LDA tile_to_display
  CMP #$01 ; bush in stage 1 is tile 01
  BNE not_in_bush


  behind_bush:
    LDA #$01
    sta is_behind_bush
    JMP finish_checking_for_bush

  not_in_bush:
    LDA #$00
    STA is_behind_bush

  finish_checking_for_bush:


  ; at this point: tile_to_display holds the tile that the sprite_collisions_x and y are currently standing on.
  ; must check if player 'walk' over the tile held at tile_to_display

  ; player can walk over tiles: 00 and 01
  ; player CANNOT walk over tile: 10 and 11

  ; basically, if second bit from right to left is zero, then player is NOT colliding

  ; perform AND with mask that holds #%10 and if result is zero, then you can walk over it
  LDA tile_to_display
  AND #%00000010
  BEQ set_colliding_to_false

  ; set colliding to TRUE since AND with mask was NOT ZERO
  LDA #$01
  STA is_colliding
  jmp exit_check_collisions

  set_colliding_to_false:
    LDA #$00
    sta is_colliding
  
  exit_check_collisions:

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

;include stage 1 and 2 maps
.include "maps/background_stage_1.asm"
.include "maps/background_stage_2.asm"
.include "maps/black.asm"

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

stage_cleared:
  .byte $82, $50, $00, 140 ;;S 
  .byte $82, $51, $00, 150 ;;T
  .byte $82, $52, $00, 160 ;;A
  .byte $82, $54, $00, 180 ;;E

  .byte $82, $55, $00, 140 ;;C 
  .byte $140, $56, $00, 150 ;;L
  .byte $140, $54, $00, 160 ;;E
  .byte $140, $52, $00, 170 ;;A
  .byte $140, $57, $00, 180 ;;R

.segment "CHR"
; .res 8192 ; reservar 8,179 bytes of empty space 
.incbin "sprite_and_background.chr"
