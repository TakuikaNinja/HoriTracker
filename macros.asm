; macros

; place bytes + define a string label with length variable
.macro define_string label, str
	.ident(.string(label)): .byte str
	.ident(.concat(.string(label), "Length")) = .sizeof(label)
.endmacro

; call PrepareVRAMString with *constant* PPU address, source CPU address, and length values
.macro vram_string ppu16, addr16, length
	.assert length > 0, error, "invalid string size"
	.assert length <= BUFFER_SIZE, warning, "string size exceeds buffer"
	lda #>(ppu16)
	ldx #<(ppu16)
	ldy #(length)
	jsr PrepareVRAMString
	.addr addr16
.endmacro

; same as vram_string, but with tile coordinates
.macro vram_addr_string base, tileX, tileY, addr16, length
	.assert base >= $2000 && base < $3000, error, "invalid base address"
	.assert tileX >= 0 && tileX < 32, error, "invalid tileX"
	.assert tileY >= 0 && tileY < 30, error, "invalid tileY"
	.assert length > 0, error, "invalid string size"
	.assert length <= BUFFER_SIZE, warning, "string size exceeds buffer"
	lda #>((base + (tileY << 5) + tileX))
	ldx #<((base + (tileY << 5) + tileX))
	ldy #(length)
	jsr PrepareVRAMString
	.addr addr16
.endmacro

; macros for use with the FDS BIOS VRAM struct format

; convert X/Y tile coordinates to PPU nametable address
.macro vram_addr base, tileX, tileY
	.assert base >= $2000 && base < $3000, error, "invalid base address"
	.assert tileX >= 0 && tileX < 32, error, "invalid tileX"
	.assert tileY >= 0 && tileY < 30, error, "invalid tileY"
	.dbyt (base + (tileY << 5) + tileX)
.endmacro

.macro encode_length inc32, fill, len
	.assert len > 0 && len <= 64, error, "cannot encode length"
	.byte (inc32 << 7) | (fill << 6) | (len & 63)
.endmacro

.macro encode_string inc32, fill, arg
	.assert .strlen(arg) > 0 && .strlen(arg) <= 64, error, "cannot encode string"
	.byte (inc32 << 7) | (fill << 6) | (.strlen(arg) & 63), arg
.endmacro

; combines vram_addr & encode_string
.macro encode_static_string base, tileX, tileY, inc32, fill, arg
	vram_addr base, tileX, tileY
	encode_string inc32, fill, arg
.endmacro

.macro encode_call addr16
	.byte $4c
	.addr addr16
.endmacro

.macro encode_return
	.byte $60
.endmacro

.macro encode_terminator
	.byte $ff
.endmacro

; convert pallete selections into a single constant attribute byte
.define ATTRIBUTE(topleft,topright,bottomleft,bottomright) ((bottomright << 6) | (bottomleft << 4) | (topright << 2) | (topleft << 0))

