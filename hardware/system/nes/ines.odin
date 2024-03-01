package nes

import "core:fmt"
import "core:log"
import "core:os"
import "core:slice"

PRG_BANK_SIZE :: 16384 // 2**14 16kB
CHR_BANK_SIZE :: 8192 // 2**13 8kB

// Implement the NES ROM struct because we only store what is currently accessible in the Bus
// and can then use this for the different mapper routines
ROM :: struct {
	prg_rom:    []u8,
	chr_rom:    []u8,
	mapper:     int,
	mirroring:  Mirroring,
	nprg_banks: int,
	nchr_banks: int,
}

// read_ines :: proc(fn: string) -> ([]u8, []u8, u8, u8) {
read_ines :: proc(fn: string) -> ROM {
	data, success := os.read_entire_file_from_filename(fn)
	defer delete(data)

	// Process the header
	NES_TAG: [4]u8 = {0x4e, 0x45, 0x53, 0x1a}
	ZEROS: [6]u8 = {0, 0, 0, 0, 0, 0}
	INES1: u8 = 0b0000_0000
	INES2: u8 = 0b0000_1000 //TODO: check last two bits

	header := data[:16]
	if !slice.equal(data[0:4], NES_TAG[:]) {
		log.fatal("BAD HEADER")
	}

	if !slice.equal(data[10:16], ZEROS[:]) {
		log.warn("BAD HEADER")
	}

	num_16: int = auto_cast data[4]
	num_8: int = auto_cast data[5]
	control1 := data[6]
	control2 := data[7]
	prg_ram_size_8 := data[8]
	// Is data[9] parts of the zeroes????

	// Get mapper from relevent bits of control1 and control2
	mapper: int = auto_cast ((control2 & 0b1111_0000) | (control1 >> 4))

	// Check for valid INES 1.0 bits and complain if it is a valid
	// INES 2.0 file
	if (control2 & 0b0000_1111) == INES2 {
		log.error("INES 2.0 is not supported")
	}

	if (control2 & 0b0000_1111) != INES1 {
		log.error("Correct INES 1.0 control bits not present")
	}

	// Final 4 bits of control1 specify whether trainers is present, whether
	// there is a battery-backed RAM, the mirroring, and whether a 4-screen VRAM layout
	has_trainer := (0b0000_0100 & control1) != 0
	has_battery := (0b0000_0010 & control1) != 0

	mirroring := 0b0000_0001 & control1
	vram_layout := 0b0000_1000 & control1

	// If 4-screen VRAM layout, output that as mirroring
	if vram_layout != 0 {
		mirroring = 2
	}

	//TODO: Can I just return a slice of the input data or do I need to copy
	// the data to a new array and delete the input data when function goes
	// out of scope?
	prg_rom_size := num_16 * PRG_BANK_SIZE
	chr_rom_size := num_8 * CHR_BANK_SIZE
	prg_rom := make([]u8, prg_rom_size)
	chr_rom := make([]u8, chr_rom_size)

	prg_start := 16
	if has_trainer do prg_start += 512
	prg_end := prg_start + prg_rom_size
	chr_start := prg_end
	chr_end := chr_start + chr_rom_size

	copy_slice(prg_rom, data[prg_start:prg_end])
	copy_slice(chr_rom, data[chr_start:chr_end])

	fmt.println("LEN PRG:", len(prg_rom), num_16)

	mirroring2: Mirroring

	if mirroring == 0 do mirroring2 = .HORIZONTAL
	if mirroring == 1 do mirroring2 = .VERTICAL
	if mirroring == 2 do mirroring2 = .FOUR_SCREEN

	rom := ROM{prg_rom, chr_rom, mapper, mirroring2, num_16, num_8}

	return rom
	// return prg_rom, chr_rom, mapper, mirroring
}
