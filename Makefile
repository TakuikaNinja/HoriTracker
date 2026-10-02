GAME=horitracker
ASSEMBLER=ca65
LINKER=ld65

OBJ_FILES=$(GAME).o

all: $(GAME).nes

$(GAME).nes: $(OBJ_FILES) nes.cfg
	$(LINKER) -o $(GAME).nes -C nes.cfg $(OBJ_FILES) -m $(GAME).map.txt -Ln $(GAME).labels.txt --dbgfile $(GAME).dbg

.PHONY: clean

clean:
	rm -f *.o *.nes *.dbg *.nl *.map.txt *.labels.txt chars.chr.out

$(OBJ_FILES): $(wildcard *.asm) chars.chr.out

%.o:%.asm
	$(ASSEMBLER) $< -g -o $@

chars.chr.out: chars.chr
	go run vramstruct.go chars.chr 0000 00

