; constants

; buttons
	AXIS_DATA     = Buttons+1
	MISC_DATA     = Buttons+2
	
.enum
	BUTTON_A      = 1 << 7
	BUTTON_B      = 1 << 6
	BUTTON_SELECT = 1 << 5
	BUTTON_START  = 1 << 4
	BUTTON_UP     = 1 << 3
	BUTTON_DOWN   = 1 << 2
	BUTTON_LEFT   = 1 << 1
	BUTTON_RIGHT  = 1 << 0
.endenum

; VRAM struct/buffer
.enum
	COPY = 0
	FILL = 1
	INC1 = 0
	INC32 = 1
	
	BUFFER_SIZE = 256
.endenum

