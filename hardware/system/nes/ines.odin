package nes

import "core:fmt"
import "core:log"
import "core:os"
import "core:slice"

PRG_BANK_SIZE :: 16384 // 2**14 16kB
CHR_BANK_SIZE :: 8192 // 2**13 8kB
PRG_RAM_BANK_SIZE :: 8192

// Everything the cartridge holds: the data read out of the iNES file, the cart's own
// RAM, and the mapper's runtime state. The whole struct is handed to the mapper routines
// so each one can reach whichever of those parts it needs.
Cartridge :: struct {
	// Read out of the iNES file, fixed after load
	prg_rom:       []u8,
	chr_rom:       []u8,
	mapper_num:    int,
	mirroring:     Mirroring,
	nprg_banks:    int,
	nchr_banks:    int,
	is_chr_ram:    bool,
	has_battery:   bool,
	prg_ram_size:  int,

	// Cart RAM at CPU 0x6000 to 0x7FFF and its save file backing
	prg_ram:       []u8,
	save_path:     string, // "" when the cart has no battery; disables all save I/O
	prg_ram_dirty: bool,

	// Runtime latches owned by the mapper
	mapper:        MapperInfo,
}

// read_ines :: proc(fn: string) -> ([]u8, []u8, u8, u8) {
read_ines :: proc(fn: string) -> Cartridge {
	data, err := os.read_entire_file(fn, context.allocator)
	if err != nil {
		log.fatalf("Could not read ROM file %v: %v", fn, err)
	}
	defer delete(data)

	// Process the header
	NES_TAG: [4]u8 = {0x4e, 0x45, 0x53, 0x1a}
	ZEROS: [6]u8 = {0, 0, 0, 0, 0, 0}
	INES1: u8 = 0b0000_0000
	INES2: u8 = 0b0000_1000 //TODO: check last two bits

	if !slice.equal(data[0:4], NES_TAG[:]) {
		log.fatal("BAD HEADER")
	}

	if !slice.equal(data[10:16], ZEROS[:]) {
		log.warn("BAD HEADER")
	}

	num_16: int = auto_cast data[4]
	num_8: int = auto_cast data[5]

	is_chr_ram := false
	if num_8 == 0 do is_chr_ram = true

	control1 := data[6]
	control2 := data[7]
	prg_ram_size_8 := data[8]
	// Is data[9] parts of the zeroes????

	// Get mapper from relevent bits of control1 and control2
	mapper: int = auto_cast ((control2 & 0b1111_0000) | (control1 >> 4))
	fmt.println("ROM has mapper:", mapper)

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

	chr_rom: []u8
	if num_8 > 0 do chr_rom = make([]u8, chr_rom_size)
	else do chr_rom = make([]u8, CHR_BANK_SIZE)

	prg_start := 16
	if has_trainer do prg_start += 512
	prg_end := prg_start + prg_rom_size
	chr_start := prg_end
	chr_end := chr_start + chr_rom_size

	copy_slice(prg_rom, data[prg_start:prg_end])
	if num_8 > 0 do copy_slice(chr_rom, data[chr_start:chr_end])

	fmt.println("LEN PRG:", len(prg_rom), num_16)
	fmt.println("LEN CHR:", len(chr_rom), num_8)

	mirroring2: Mirroring

	if mirroring == 0 do mirroring2 = .HORIZONTAL
	if mirroring == 1 do mirroring2 = .VERTICAL
	if mirroring == 2 do mirroring2 = .FOUR_SCREEN

	// Header byte 8 counts the PRG RAM in 8kB units, and a 0 there means 8kB by
	// the iNES 1.0 convention rather than none at all
	prg_ram_size := max(1, int(prg_ram_size_8)) * PRG_RAM_BANK_SIZE

	// The MMC1 boards that bank their PRG RAM (SOROM with 16kB, SXROM with 32kB)
	// almost always still report 0 in byte 8, so the header alone would leave the
	// banking nowhere to bank to. Give those carts the full 32kB up front.
	//
	// The bank is selected by bits of the CHR Bank 0 register, so this can only be
	// done when the cart has CHR RAM. On a cart with CHR ROM those same bits are
	// real CHR bank selects and reading them as a RAM bank would scramble the RAM
	if mapper == 1 && has_battery && is_chr_ram && prg_ram_size < 4 * PRG_RAM_BANK_SIZE {
		prg_ram_size = 4 * PRG_RAM_BANK_SIZE
	}

	fmt.println("LEN PRG RAM:", prg_ram_size)

	rom := Cartridge {
		prg_rom      = prg_rom,
		chr_rom      = chr_rom,
		mapper_num   = mapper,
		mirroring    = mirroring2,
		nprg_banks   = num_16,
		nchr_banks   = num_8,
		is_chr_ram   = is_chr_ram,
		has_battery  = has_battery,
		prg_ram_size = prg_ram_size,
	}

	return rom
	// return prg_rom, chr_rom, mapper, mirroring
}
