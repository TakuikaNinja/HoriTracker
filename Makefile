GAME=horitracker
ZIP_NAME=HoriTracker
ASSEMBLER=ca65
LINKER=ld65

OBJ_FILES=$(GAME).o

all: $(GAME).nes

$(GAME).nes: $(OBJ_FILES) nes.cfg
	$(LINKER) -o $(GAME).nes -C nes.cfg $(OBJ_FILES) -m $(GAME).map.txt -Ln $(GAME).labels.txt --dbgfile $(GAME).dbg

dist: zip
zip: $(ZIP_NAME).zip
$(ZIP_NAME).zip: zip.in
	zip -9 -u $@ -@ < $<

zip.in: $(GAME).nes $(GAME).png README.md
	echo $(GAME).nes > $@
	echo $(GAME).png >> $@
	echo README.md >> $@

.PHONY: clean dist zip

clean:
	rm -f *.zip *.o *.nes *.dbg *.nl *.map.txt *.labels.txt

$(OBJ_FILES): $(wildcard *.asm) chars.chr.out

%.o:%.asm
	$(ASSEMBLER) $< -g -o $@

chars.chr.out: chars.chr
	go run vramstruct.go chars.chr 0000 00

