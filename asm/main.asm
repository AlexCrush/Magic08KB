;.device ATMega16A
;.include "m644Pdef.inc" ; for Avr Assembler 2
;.include "m16def.inc" ; for Avr Assembler 2
.include "m162def.inc" ; for Avr Assembler 2
;------------------------------------------------------------------------
.include "hw.asm-inc"
.include "macroses.asm-inc"
.include "consts.asm-inc"
;------------------------------------------------------------------------
; TODO
; переключение таблиц клавиш?


.CSEG
.ORG 0x0000
    rjmp _RESET
.ORG 0x0002
    rjmp Handler_Read1F
.ORG 0x0004
    rjmp Handler_WriteDosFF
.ORG 0x0006
Handler_ReadFF:
    in YL, Pin_ZXAddr ; receive data from bus                            ; 1 cycle  2 byte
    ld INT_TMP, Y     ; put data to r20 from SRAM key table at 0x100+YL  ; 2 cycles, 2 byte instruction
    out DD_ZXData, INT_TMP                                               ; 1 cycle, 2 byte instruction
    ;------ 5 cycle, 6 bytes
HOLD_BusFE: ; hold data on bus while /RDFE=0
    sbis    Pin_ReadFE, BIT_ReadFE
    rjmp    HOLD_BusFE
    out     DD_ZXData, CONST00; turn data bus to HI-Z state              ; 1 cycle, 2 byte instruction
    reti                                                                 ; 4 cycles
;.ORG 0x0004
;    rjmp Int1Handler
;///////////////////////////////////////////////////////////////////////////////////////////
;    0-5 prev instruction
;    4 cycles - interrupt (mega 162)
;    4 cycles - in, ld, out
;   т.е от 9 до 14 тактов
;  20 mhz: 1 cycle - 50ns; sum = 450..700ns
;
;  у нас 2.5 цикла z80 = 280*2.5 = 700ns

;// 16MHz: 1 cycle = 62ns, 62*7=434ns from falling edge to data set on port B
;// 20MHz: 1 cycle = 50ns, 50*7=350ns from falling edge to data set on port B
;// 24MHz: 1 cycle = 42ns, 42*7=294ns from falling edge to data set on port B
;// 25MHz: 1 cycle = 40ns, 40*7=280ns from falling edge to data set on port B
;// 27MHz: 1 cycle = 37ns, 37*7=259ns from falling edge to data set on port B
;// 28MHz: 1 cycle = 36ns, 36*7=252ns from falling edge to data set on port B
;// 30MHz: 1 cycle = 33ns, 33*7=231ns from falling edge to data set on port B
;// 32MHz: 1 cycle = 31ns, 31*7=217ns from falling edge to data set on port B
;// Чем быстрее работает это прерывание, тем лучше, а для этого частота кварца должна быть выше!
;///////////////////////////////////////////////////////////////////////////////////////////
;---------------------------------------------------------------------------------------------
Handler_Read1F:
    out    DD_ZXData, KEMPSTON_REG
HOLD_Bus1F:
    sbis   Pin_Read1F, BIT_Read1F
    rjmp   HOLD_Bus1F
    out    DD_ZXData, CONST00; turn data bus to HI-Z state
    reti
;---------------------------------------------------------------------------------------------
Handler_WriteDosFF:
    in INT_TMP, Pin_ZXData
    push tmp
    in tmp, SREG
    push tmp

    ldi tmp, 1
    sbrc VAR_STATE, VAR_STATE_BIT_DRIVESWAP
    eor INT_TMP, tmp

    bst INT_TMP, 0
    bld SERIAL_STATE, SerialBit_Drive0
    sbr VAR_STATE, 1 << VAR_STATE_BIT_REFRESH

    pop tmp
    out SREG, tmp
    pop tmp
    reti

;-----------------------------------------------------------
PortInitTable:
    .db IOBASE + ACSR    , 1 << ACD   ; disable Analog Comparator

    .db IOBASE + MCUCR   , (1 << ISC11) + (1 << ISC01)               ; Falling Edges at INT0, INT1
    .db IOBASE + EMCUCR  , (0 << ISC2)                               ; ISC2=0 -> Falling edge on INT2 causes interrupt)
    .db IOBASE + GICR    , (1 << INT0) + (1 << INT1) + (1 << INT2)   ; Enable

    ; Flash: PD5 = OC1A

    .db IOBASE + TCCR1A  , 0b01000000 ; CTC mode 4 + Toggle OC1A on Compare Match
    .db IOBASE + TCCR1B  , 0b00001101 ; CTC mode 4 & prescaler 1024
    .db IOBASE + OCR1AH  , HIGH(FREQ_MHZ * 1000000 / 1024 / FlashFreq)
    .db IOBASE + OCR1AL  , LOW (FREQ_MHZ * 1000000 / 1024 / FlashFreq)

    .db IOBASE + DD_ZXAddr, 0x00   ; All Input
    .db IOBASE + Port_ZXAddr, 0xFF ; With Pullup

    .db IOBASE + DD_ZXData, 0x00   ; All Input
    .db IOBASE + Port_ZXData, 0x00 ; no pullup to output zero on dir change


    .db 0xFF,0xFF

;///////////////////////////////////////////////////////////////////////////////////////////
;// PROGRAM START
;///////////////////////////////////////////////////////////////////////////////////////////

_RESET:
    cli
    ldi tmp, LOW(RAMEND)
    out SPL, tmp
    ldi tmp, HIGH(RAMEND)
    out SPH, tmp

    LDIProgMemAddrZ PortInitTable
    rcall PortInitByTable

    clr Const00
    ser ConstFF

    cbi DD_Read1F, BIT_Read1F       ; input
    sbi Port_Read1F, BIT_Read1F     ; pullup

    cbi DD_WriteDOSFF, BIT_Read1F   ; input
    sbi Port_WriteDOSFF, BIT_Read1F ; pullup

    cbi DD_ReadFE, BIT_ReadFE       ; input
    sbi Port_ReadFE, BIT_ReadFE     ; pullup

    sbi DD_ZXWait, BIT_ZXWait       ; output
    sbi Port_ZXWait, BIT_ZXWait     ; 1

    sbi DD_ZXFlash, BIT_ZXFlash     ; output
    cbi Port_ZXFlash, BIT_ZXFlash   ; 0

    sbi DD_LCD_RS, BIT_LCD_RS       ; output
    cbi Port_LCD_RS, BIT_LCD_RS     ; 0
    sbi DD_LCD_E, BIT_LCD_E         ; output
    cbi Port_LCD_E, BIT_LCD_E       ; 0
    sbi DD_LCD_RW, BIT_LCD_RW       ; output
    cbi Port_LCD_RW, BIT_LCD_RW     ; 0

    sbi DD_LCD_Bit7, BIT_LCD_Bit7   ; output
    cbi Port_LCD_Bit7, BIT_LCD_Bit7 ; 0
    sbi DD_LCD_Bit6, BIT_LCD_Bit6   ; output
    cbi Port_LCD_Bit6, BIT_LCD_Bit6 ; 0
    sbi DD_LCD_Bit5, BIT_LCD_Bit5   ; output
    cbi Port_LCD_Bit5, BIT_LCD_Bit5 ; 0
    sbi DD_LCD_Bit4, BIT_LCD_Bit4   ; output
    cbi Port_LCD_Bit4, BIT_LCD_Bit4 ; 0

    sbi DD_SerialStore, BIT_SerialStore   ; OUTPUT
    cbi Port_SerialStore, BIT_SerialStore ; 0
    sbi DD_SerialClock, BIT_SerialClock   ; OUTPUT
    cbi Port_SerialClock, BIT_SerialClock ; 0
    sbi DD_SerialData, BIT_SerialData     ; OUTPUT
    cbi Port_SerialData, BIT_SerialData   ; 0

    mov KEMPSTON_REG, CONSTFF

    ldi VAR_STATE, (1 << VAR_STATE_BIT_DRIVESWAP) + (1 << VAR_STATE_BIT_STARTUP)

    ldi SERIAL_STATE, (0 << SerialBit_Turbo) + (1 << SerialBit_KeyNMI) + (0 << SerialBit_Reset) + (0 << SerialBit_ResetFF7C) + (1 << SerialBit_Drive0)
    rcall SendSerialState

    ; // Init constants
    ldi YH, HIGH(PORT_FE_DATA)

    rcall INIT_KEYBOARD_BUFFERS

    rcall LCD_Init

    ori SERIAL_STATE, (1 << SerialBit_Reset) + (1 << SerialBit_ResetFF7C)
    rcall SendSerialState

    sei

KBD_RESET_LOOP: ;// цикл сделать сброс клавиатуры
    ldi tmp, 100
    rcall WAIT_Tmp_Millis
    ldi KBD_BYTE, 0xFF ; Keyboard Command RESET
    rcall KBD_SEND
    brcs  KBD_RESET_LOOP     ; если не сбросилась то снова...

    rcall KBD_READ0
    brcs KBD_RESET_LOOP

    ; set scan code 2
    ldi KBD_BYTE, 0xF0
    rcall KBD_SEND

    ldi KBD_BYTE, 2
    rcall KBD_SEND

    ; // enable scan
    ldi KBD_BYTE, 0xF4
    rcall KBD_SEND


    ; init indicators
    ldi KBD_IND, 3 ; 3 = Scroll lock + num lock
    rcall KBD_SEND_INDICATORS

CLEAR_KB_STATE:
    clr KBD_STATE
    clr KBD_BYTE_PREV

MAIN_LOOP:
    sbrs VAR_STATE, VAR_STATE_BIT_REFRESH
    rjmp SKIP_REFRESH

MAIN_LOOP_WITH_REFRESH:
    rcall SendSerialState
    rcall LCD_Regenerate
    cbr VAR_STATE, 1 << VAR_STATE_BIT_REFRESH
SKIP_REFRESH:
;------ чтение байта от клавиатуры -------------------------------------
    set
    rcall KBD_READ
    brcs  CLEAR_KB_STATE  ; if parity error - forget state and repeat  TODO : retry, then reset KB
;-----------------------------------------------------------------------

    tst KBD_BYTE
    breq MAIN_LOOP

    sbrc VAR_STATE, VAR_STATE_BIT_STARTUP
    sbr VAR_STATE, 1 << VAR_STATE_BIT_REFRESH
    cbr VAR_STATE, 1 << VAR_STATE_BIT_STARTUP

    LDIProgMemAddrZ RAW_KEYCODE_PREPROCESS_TABLE
    rcall RAW_KEYCODE_PROCESS
    tst KBD_BYTE
    breq MAIN_LOOP_WITH_REFRESH

    sbrc KBD_STATE, KBD_STATE_BIT_E0_PFX
    ori KBD_BYTE, 0x80  ; add E0 flag to bit 7 of key code
    cbr  KBD_STATE, 1 << KBD_STATE_BIT_E0_PFX ; clear E0 prefix flag

    sbrc KBD_STATE, KBD_STATE_BIT_F0_PFX  ; check KBD_STATE bit 1, if set then used prefix #F0
    rjmp F0_SET              ; jump to F0 keys set

    ; skip repeatable codes
    cp KBD_BYTE_PREV, KBD_BYTE ; if KBD_BYTE = previous value repeat loop
    breq MAIN_LOOP
    mov KBD_BYTE_PREV, KBD_BYTE

    sbrc KBD_STATE, KBD_STATE_BIT_WIN_PRESSED
    rjmp WIN_PRESSED

    LDIProgMemAddrZ RAW_KEYCODE_PRESSED_TABLE
    rcall RAW_KEYCODE_PROCESS
    tst KBD_BYTE
    breq MAIN_LOOP_WITH_REFRESH

    ; Process pressed key -----------------------------------------------------------------------
UPDATE_KEY_BUFFER:
    rcall ADD_KEY_TO_BUFFER
    rcall PROCESS_KBD_BUFFER
    rjmp  MAIN_LOOP_WITH_REFRESH

WIN_PRESSED:
    LDIProgMemAddrZ RAW_KEYCODE_WINPRESSED_TABLE
    rcall RAW_KEYCODE_PROCESS
    rjmp MAIN_LOOP_WITH_REFRESH

F0_SET:
; process F0 prefixes, #E0 also may be set
; F0 prefixe set when key release, so we need to remove key from the buffer
    clr  KBD_BYTE_PREV      ; clear previous key value
    andi KBD_STATE, 255 - (1 << KBD_STATE_BIT_F0_PFX) ; clear F0 prefix flag

    LDIProgMemAddrZ RAW_KEYCODE_RELEASED_TABLE
    rcall RAW_KEYCODE_PROCESS
    tst KBD_BYTE
    breq MAIN_LOOP_WITH_REFRESH

    rcall REMOVE_KEY_FROM_BUFFER
    rcall PROCESS_KBD_BUFFER
;-------------------------------------------------------------------------------------
    rjmp  MAIN_LOOP_WITH_REFRESH


;------------------------------------------------------------------------------------------------------------
;------------------------------------------------------------------------------------------------------------
;  Всякие подпрограммы
;----------------------------------------------------
;----------------------------------------------------------------------------------------
;-----------------------------------------------------------------
PortInitByTable:
    clr yh
PortInitLoop:
    lpm yL, Z+
    cpi yL, 0xFF
    breq PortInitLoopEnd
    lpm tmp, Z+
    st Y, tmp
    rjmp PortInitLoop
PortInitLoopEnd:
    ret
;-----------------------------------------------------------------
SendSerialState:
    ldi tmp2, 8
    mov tmp, SERIAL_STATE

SendSerialState_Loop:
    cbi Port_SerialData, BIT_SerialData
    rol tmp
    brcc SendSerialState_Zero
    sbi Port_SerialData, BIT_SerialData
SendSerialState_Zero:
    nop
    nop
    sbi Port_SerialClock, BIT_SerialClock
    nop
    nop
    cbi Port_SerialClock, BIT_SerialClock
    dec tmp2
    brne SendSerialState_Loop

    sbi Port_SerialStore, BIT_SerialStore
    nop
    nop
    cbi Port_SerialStore, BIT_SerialStore
    ret
;---------------------------------------------------------------------
.include "keytables.asm-inc"
.include "kb.asm-inc"
.include "kbRawCodes.asm-inc"
.include "delays.asm-inc"
.include "lcdWorks.asm-inc"
.include "vars.asm-inc"
;---------------------------------------------------------------------
