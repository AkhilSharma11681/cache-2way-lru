# 2-Way Set-Associative Cache with LRU

Modern Computer Architecture - B.Tech (CS&AI) - Project 7

**Team:** Akhil Sharma, Rohan Kumar, Puneet Takhar, Varun, Ayush Kumar

## Project idea
A 1 KB, 2-way set-associative cache with LRU replacement in Verilog,
compared against a direct-mapped cache of the same size.

## Key result
On a two-address conflict trace, the direct-mapped cache hits 0% of the time
(AMAT 13.97 cycles) while the 2-way LRU cache hits 95% (AMAT 3.52 cycles).

## Files
- sa2_cache.v : 2-way cache with LRU
- dm_cache.v : direct-mapped baseline
- memory.v : main memory model
- tb.v : trace-driven testbench
- results.txt, wave.vcd : simulation output
- sa2_synth.txt, dm_synth.txt : Yosys synthesis reports

## How to run
iverilog -o sim tb.v dm_cache.v sa2_cache.v memory.v
vvp sim

## Links
- Report: (add report PDF in this repo)
- Demo video: (add link here)
