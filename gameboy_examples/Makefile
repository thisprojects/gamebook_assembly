# Build and run the Game Boy examples with RGBDS.
#   make first.gb       build one example
#   make run-first      build it and open it in mGBA
#   make                build them all
# RGBDS is taken from ../tools/rgbds if it is there, otherwise from your PATH.
RGBDS := $(shell test -d ../tools/rgbds && echo ../tools/rgbds/)
ASM   := $(RGBDS)rgbasm
LINK  := $(RGBDS)rgblink
FIX   := $(RGBDS)rgbfix
EMU   ?= mgba

# debug_output.asm is a library (it is INCLUDEd by the programs), not a program of its own
PROGRAMS := $(filter-out debug_output,$(basename $(wildcard *.asm)))

all: $(addsuffix .gb,$(PROGRAMS))

%.o: %.asm ../gameboy_lib/hardware.inc ../gameboy_lib/font.inc debug_output.asm
	$(ASM) -I ../gameboy_lib/ -I . -o $@ $<

%.gb: %.o
	$(LINK) -n $*.sym -o $@ $<
	$(FIX) -v -p 0xFF -t $(shell echo $* | tr a-z A-Z | cut -c1-11) $@

run-%: %.gb
	$(EMU) $<

clean:
	rm -f *.o *.gb *.sym *.map

.PHONY: all clean
.PRECIOUS: %.o
