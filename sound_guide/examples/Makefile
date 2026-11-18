# Build and run the Game Boy sound examples with RGBDS.
#   make beep_demo.gb        build one example
#   make run-beep_demo       build it and open it in mGBA (turn the volume up)
#   make                     build them all
# RGBDS is taken from ../tools/rgbds if it is there, otherwise from your PATH.
RGBDS := $(shell test -d ../tools/rgbds && echo ../tools/rgbds/)
ASM   := $(RGBDS)rgbasm
LINK  := $(RGBDS)rgblink
FIX   := $(RGBDS)rgbfix
EMU   ?= mgba

PROGRAMS := $(basename $(wildcard *.asm))

all: $(addsuffix .gb,$(PROGRAMS))

%.o: %.asm $(wildcard ../lib/*)
	$(ASM) -I ../lib/ -I . -o $@ $<

%.gb: %.o
	$(LINK) -n $*.sym -o $@ $<
	$(FIX) -v -p 0xFF -t $(shell echo $* | tr a-z A-Z | cut -c1-11) $@

run-%: %.gb
	$(EMU) $<

clean:
	rm -f *.o *.gb *.sym *.map

.PHONY: all clean
.PRECIOUS: %.o
