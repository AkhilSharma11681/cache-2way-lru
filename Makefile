# Build and run the simulations with Icarus Verilog.
# Everything is built in build/, so the committed wave.vcd and
# results.txt are never overwritten.

IVERILOG ?= iverilog
VVP      ?= vvp
BUILD    := build

.PHONY: all sim test test_memory test_dm_cache wave clean

all: test sim

$(BUILD):
	mkdir -p $(BUILD)

# Full trace-driven comparison (direct-mapped vs 2-way LRU)
sim: | $(BUILD)
	$(IVERILOG) -o $(BUILD)/sim tb.v dm_cache.v sa2_cache.v memory.v
	cd $(BUILD) && $(VVP) sim

# Unit tests
test: test_memory test_dm_cache

test_memory: | $(BUILD)
	$(IVERILOG) -o $(BUILD)/tb_memory tb_memory.v memory.v
	$(VVP) $(BUILD)/tb_memory

test_dm_cache: | $(BUILD)
	$(IVERILOG) -o $(BUILD)/tb_dm_cache tb_dm_cache.v dm_cache.v memory.v
	$(VVP) $(BUILD)/tb_dm_cache

# Open the waveform from the last `make sim`
wave: sim
	gtkwave $(BUILD)/wave.vcd

clean:
	rm -rf $(BUILD)
