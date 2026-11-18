# Build and run the Game Boy graphics examples with RGBDS.
#   make tiles_demo.gb       build one example
#   make run-tiles_demo      build it and open it in mGBA
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

# The colour demos are marked as Game Boy Color compatible
cgb_demo.gb hdma_demo.gb: %.gb: %.o
	$(LINK) -n $*.sym -o $@ $<
	$(FIX) -v -c -p 0xFF -t $(shell echo $* | tr a-z A-Z | cut -c1-11) $@

run-%: %.gb
	$(EMU) $<

clean:
	rm -f *.o *.gb *.sym *.map

.PHONY: all clean
.PRECIOUS: %.o
