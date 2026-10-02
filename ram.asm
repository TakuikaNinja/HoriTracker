; RAM

; zeropage
.segment "ZEROPAGE"
	temp: .res 16 ; temp memory
	NMISoftDisable: .res 1
	SkipSound: .res 1
	NMIReady: .res 1
	NeedDraw: .res 1
	NeedPPUMask: .res 1
	PPU_MASK_MIRROR: .res 1
	PPU_CTRL_MIRROR: .res 1
	VRAMBufferIdx: .res 1
	Mode: .res 1
	Buttons: .res 3
	Axis: .res 2
	ID: .res 1
	Speed: .res 1
	Rotation: .res 1
	Unknown: .res 1

; rest of memory
.segment "BSS"
	stack: .res 256
	oam: .res 256
	vram_buffer: .res 256
	string_buffer: .res 256

