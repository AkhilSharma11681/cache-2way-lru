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
- tb_memory.v, tb_dm_cache.v : unit testbenches for memory and direct-mapped cache
- results.txt, wave.vcd : simulation output
- sa2_synth.txt, dm_synth.txt : Yosys synthesis reports
- Makefile : build and run targets

## Main memory model (memory.v)
- 16 KB, 4096 32-bit words; word i is initialised to the value i.
- Every request (block read or word write) takes `LAT` cycles (default 10),
  then `ready` pulses high for one cycle.
- Reads return the whole 16-byte block containing the address.
- `LAT` must be between 1 and 256 (checked in simulation).

## Direct-mapped cache (dm_cache.v)
- 1 KB: 64 lines of 16-byte blocks (4 words each).
- Address split: tag = [31:10], index = [9:4], word = [3:2], byte = [1:0].
- FSM: IDLE -> LOOKUP -> (REFILL | WTHRU) -> DONE -> IDLE.
- Read miss: fetch the block from memory, fill the line, return the word.
- Write policy: write-through, no-write-allocate. A write hit updates the
  cached word and memory; a write miss only updates memory.

## How to run
iverilog -o sim tb.v dm_cache.v sa2_cache.v memory.v
vvp sim

Or with make:

    make sim     # full trace comparison
    make test    # unit tests for memory.v and dm_cache.v
    make clean

## Links
-  Report: [Project Report IEEE.pdf](Project%20Report%20IEEE.pdf)
- Demo video: https://drive.google.com/file/d/14VPOMg-hgQg2BR5IkKwQtdCi_lR4F0JE/view?usp=sharing

