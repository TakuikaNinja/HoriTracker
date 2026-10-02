; enable backslash escape sequences
.feature string_escapes +

.include "defs.asm"
.include "ram.asm"
.include "constants.asm"
.include "macros.asm"

.segment "HEADER"
	.byte "NES", $1A ; iNES header identifier
	.byte $01        ; 1x 16KB PRG code
	.byte $00        ; 0x  8KB CHR data
	.byte $A9, $D8   ; mapper 218, "Single-screen, BLK1" config: https://www.nesdev.org/wiki/INES_Mapper_218
	.byte 0,0,0,0,0,0,0
	.byte $50        ; default expansion device: HORI Track (thx 4 the new assignment, NewRisingSun)

.charmap '0', $00
.charmap '1', $01
.charmap '2', $02
.charmap '3', $03
.charmap '4', $04
.charmap '5', $05
.charmap '6', $06
.charmap '7', $07
.charmap '8', $08
.charmap '9', $09
.charmap 'A', $0a
.charmap 'B', $0b
.charmap 'C', $0c
.charmap 'D', $0d
.charmap 'E', $0e
.charmap 'F', $0f
.charmap 'G', $10
.charmap 'H', $11
.charmap 'I', $12
.charmap 'J', $13
.charmap 'K', $14
.charmap 'L', $15
.charmap 'M', $16
.charmap 'N', $17
.charmap 'O', $18
.charmap 'P', $19
.charmap 'Q', $1a
.charmap 'R', $1b
.charmap 'S', $1c
.charmap 'T', $1d
.charmap 'U', $1e
.charmap 'V', $1f
.charmap 'W', $20
.charmap 'X', $21
.charmap 'Y', $22
.charmap 'Z', $23
.charmap ' ', $24
.charmap '-', $28
.charmap '+', $29

; Main code segment for the program
.segment "CODE"
Reset:
		sei
		cld
		ldx #$ff
		stx JOY2
		txs
		inx
		stx PPU_CTRL
		stx PPU_MASK
		stx DMC_FREQ
	    bit PPU_STATUS
@vblankwait1:
		bit PPU_STATUS
		bpl @vblankwait1

		txa
@clrmem:
		sta $00,x
		sta $0100,x
		sta $0200,x
		dec $0200,x ; offscreen values
		sta $0300,x
		sta $0400,x
		sta $0500,x
		sta $0600,x
		sta $0700,x
		inx
		bne @clrmem

@vblankwait2:
		bit PPU_STATUS
		bpl @vblankwait2
		
		jsr InitVRAM
		
		lda #%10000000 ; set BG pattern table selection
		sta vram_buffer ; mark buffer as empty (just in case)
		sta PPU_CTRL_MIRROR
		bit PPU_STATUS
		sta PPU_CTRL
Main:
		jsr ProcessHoriTrack
		jsr DrawScreen
		jsr WaitForNMI
		beq Main ; [unconditional branch]

WaitForNMI:
		inc NMIReady
@loop:
		lda NMIReady
		bne @loop
		rts

NMI:
		bit NMISoftDisable
		bmi @skipNMI
		pha
		txa
		pha
		tya
		pha
		
		lda NMIReady
		beq @setScroll
		dec NMIReady
		
		lda #$00
		sta PPU_OAM_ADDR
		lda #>oam
		sta OAM_DMA
		
		jsr TransferVRAM

		lda NeedPPUMask
		beq @setScroll
		
		lda PPU_MASK_MIRROR
		sta PPU_MASK
		dec NeedPPUMask
		
@setScroll:
		lda #$00
		sta PPU_SCROLL
		sta PPU_SCROLL
		lda PPU_CTRL_MIRROR
		sta PPU_CTRL

		pla
		tay
		pla
		tax
		pla
@skipNMI:
IRQ:
		rti

TransferVRAM:
		lda NeedDraw
		beq @skip
		
		ldx #$ff
		bne @readDest
		
@writeStripe:
		pha
		bit PPU_STATUS
		sta PPU_ADDR
		inx
		lda vram_buffer,x ; dest lo byte
		sta PPU_ADDR
		inx
		lda PPU_CTRL_MIRROR
		and #%10111011 ; +1 increment by default
		ldy vram_buffer,x ; length/flags
		bpl @horizontal
		ora #%00000100 ; bit 7 set = +32 increment
@horizontal:
		sta PPU_CTRL
		tya
		and #$7f
		cmp #$40 ; carry will contain bit 6 (fill flag)
		beq :+ ; (if length byte is as 0, treat as 64)
		and #$3f ; otherwise mask length bits to use as counter
:
		tay
		inx
		bcc @writeByte
		
@checkRun:
		bcs @writeByte
		inx
@writeByte:
		lda vram_buffer,x
		sta PPU_DATA
		dey
		bne @checkRun
		
		; if we just wrote to palette RAM, safely move v out of it
		pla
		cmp #$3f
		bne @readDest
		
		sta PPU_ADDR
		lda #$00
		sta PPU_ADDR
		sta PPU_ADDR
		sta PPU_ADDR

@readDest:
		inx
		lda vram_buffer,x ; dest hi byte
		bpl @writeStripe ; bit 7 set = end of data
		sta vram_buffer ; mark buffer as empty (just in case)
		dec NeedDraw
		lda #$00
		sta VRAMBufferIdx
@skip:
		rts

; Similar to above, but load from pointer in YYXX
; clobbers temp+0, temp+1
LoadVRAM:
		stx temp
		sty temp+1
		ldy #$00
		beq @readDest
		
@writeStripe:
		bit PPU_STATUS
		sta PPU_ADDR
		inc temp
		bne :+
		inc temp+1
:
		lda (temp),y ; dest lo byte
		sta PPU_ADDR
		lda PPU_CTRL_MIRROR
		and #%10111011 ; +1 increment by default
		tax
		inc temp
		bne :+
		inc temp+1
:
		lda (temp),y ; length/flags
		pha
		bpl @horizontal
		txa
		ora #%00000100 ; bit 7 set = +32 increment
		tax
@horizontal:
		stx PPU_CTRL
		pla
		and #$7f
		cmp #$40 ; carry will contain bit 6 (fill flag)
		beq :+ ; (if length byte is 0, treat as 64)
		and #$3f ; otherwise mask length bits to use as counter
:
		tax
		bpl @incPtr ; [unconditional branch]

@checkRun:
		bcs @writeByte
@incPtr:
		inc temp
		bne :+
		inc temp+1
:
@writeByte:
		lda (temp),y
		sta PPU_DATA
		dex
		bne @checkRun
		
		inc temp
		bne :+
		inc temp+1
:
@readDest:
		lda (temp),y ; dest hi byte
		bpl @writeStripe ; bit 7 set = end of data
@skip:
		rts

InitVRAM:
		lda #$00
		ldx #$00 ; "CHR-RAM"
		jsr FillVRAM
		lda #' '
		ldx #$20 ; top-left screen

; Fill 1KiB of VRAM at XX00 with the value in A (clobbers Y)
FillVRAM:
		bit PPU_STATUS
		stx PPU_ADDR
		ldy #$00
		sty PPU_ADDR
@fillLoop:
		sta PPU_DATA
		sta PPU_DATA
		sta PPU_DATA
		sta PPU_DATA
		iny
		bne @fillLoop
		rts

; Similar to the FDS BIOS routine
PrepareVRAMString:
		sta temp+2 ; VRAM hi
		stx temp+3 ; VRAM lo
		sty temp+4 ; length
		
		; fetch the return address on the stack
		pla ; lo
		sta temp
		pla ; hi
		sta temp+1
		
		; fix the return address
		lda temp
		clc
		adc #$02
		tay
		lda #$00
		adc temp+1
		pha ; push hi
		tya
		pha ; push low
		
		; fetch the target pointer
		ldy #$01
		lda (temp),y
		tax
		iny
		lda (temp),y
		sta temp+1
		stx temp
		ldy #$00
		
		; now copy the string over
		ldx VRAMBufferIdx
		lda temp+2
		sta vram_buffer,x
		inx
		lda temp+3
		sta vram_buffer,x
		inx
		lda temp+4
		sta vram_buffer,x
		inx
@copyloop:
		lda (temp),y
		sta vram_buffer,x
		inx
		inc temp
		bne :+
		inc temp+1		
:
		dec temp+4
		bne @copyloop
		lda #$ff ; place $FF terminator
		sta vram_buffer,x
		stx VRAMBufferIdx ; save index
		rts

DrawScreen:
		lda Mode
		bne DisplayInputs
		
		; init screen
		ldx #PaletteDataSize
@loop:
		lda PaletteData-1,x
		sta vram_buffer-1,x
		dex
		bne @loop
		inc NeedDraw
		jsr WaitForNMI ; upload palette during vblank
		lda #$80
		sta NMISoftDisable
		
		ldx #<ScreenData
		ldy #>ScreenData
		jsr LoadVRAM
		
		lda #%00001010 ; hide sprites during initial evaluation
		sta PPU_MASK_MIRROR
		inc NeedPPUMask
		asl NMISoftDisable
		jsr WaitForNMI ; let sprite evaluation occur
		lda #%00011110 ; show sprites
		sta PPU_MASK_MIRROR
		inc NeedPPUMask
		inc Mode
		rts

DisplayInputs:
		lda Axis
		jsr SignedDisplay
		vram_addr_string $2000, 17, 10, string_buffer, 2
		
		lda Axis+1
		jsr SignedDisplay
		vram_addr_string $2000, 17, 11, string_buffer, 2
		
		lda Speed
		clc
		adc #$6e ; pick between hi/lo tiles
		sta string_buffer
		vram_addr_string $2000, 18, 13, string_buffer, 1
		
		ldx Rotation
		lda RotationModes,x
		sta string_buffer
		vram_addr_string $2000, 24, 13, string_buffer, 1
		
		vram_addr_string $2000, 12, 13, ID, 1
		vram_addr_string $2000, 18, 15, Unknown, 1
		inc NeedDraw
		rts

RotationModes:
	.byte "RL"

; convert 2's complement(?) to sign/magnitude format
SignedDisplay:
		ldy #'+'
		cmp #%00001000 ; bit 4 is sign
		bcc :+
		eor #%00001111 ; if negative, negate it to get the absolute value
		adc #$00
		dey
:
		cmp #0
		bne :+
		ldy #' ' ; 0 should not have a sign
:
		sty string_buffer
		sta string_buffer+1
		rts

ProcessHoriTrack:
		ldx #$00
		stx JOY1
		inx
		stx JOY1
		stx Buttons
		stx Buttons+1
		stx Buttons+2
		dex
		stx JOY1
		; standard controller report
:
		lda JOY1
		lsr a ; only care about D1
		lsr a
		rol Buttons
		bcc :-
		; inverted axis data
:
		lda JOY1
		lsr a
		lsr a
		rol AXIS_DATA
		bcc :-
		; ID, speed, rotation, etc.
:
		lda JOY1
		lsr a
		lsr a
		rol MISC_DATA
		bcc :-
;		rts

		; start by inverting & splitting the axis data
		lda AXIS_DATA
		eor #$ff
		tay
		lsr a
		lsr a
		lsr a
		lsr a
		sta Axis
		tya
		and #$0f
		sta Axis+1
		
		; Extract unknown data
		lda MISC_DATA
		tay
		and #$0f
		sta Unknown
		; then ID bits
		tya
		lsr a
		lsr a
		lsr a
		lsr a
		and #$03
		sta ID
		; then rotation & speed bits
		tya
		lsr Rotation
		asl a
		rol Rotation
		lsr Speed
		asl a
		rol Speed
		rts

PaletteData:
	.dbyt $3f00
	.byte 32
	.repeat 8
	.byte $0f, $00, $10, $20
	.endrepeat
	encode_terminator
	PaletteDataSize = *-PaletteData

ScreenData:
	encode_static_string $2000, 10, 4, INC1, COPY, "HORI TRACKER"
	encode_static_string $2000, 9, 6, INC1, COPY, "BY TAKUIKANINJA"
	
	encode_static_string $2000, 9, 10, INC1, COPY, "AXIS 1"
	encode_static_string $2000, 9, 11, INC1, COPY, "AXIS 2"
	
	; ID, speed, rotation, etc.
	encode_static_string $2000, 9, 13, INC1, COPY, "ID"
	encode_static_string $2000, 15, 13, INC1, COPY, "\x2a\x2b"
	encode_static_string $2000, 21, 13, INC1, COPY, "\x2c\x2d"
	encode_static_string $2000, 9, 15, INC1, COPY, "UNKNOWN"

; includes terminator
CharData:
	.incbin "chars.chr.out"

.segment "VECTORS"
	.addr NMI
	.addr Reset
	.addr IRQ

