package nes

import "core:log"

// Code to implement some "mapper" chips by storing the info needed to determine
// which PRG and CHR blocks are currently accessible to the NES.

// PRG_BANK_SIZE :: 0x4000 // defines in ines.odin

MapperInfo :: struct {
	num:  int,
	info: [10]int,
}

// Call the different mapper routines implemented in the mapper package.
update_mi :: proc(mi: ^MapperInfo, addr: u16, data: u8) {
	// delete(bus.prg_rom)

	switch mi.num {
	case 0:
		update_mapper_0()
	case 1:
		update_mapper_1(mi, addr, data)
	case 2:
		update_mapper_2(mi, data)
	case:
		log.fatal("Unimplemented mapper:", mi.num)
	}
}

update_mapper_0 :: proc() {
	log.fatal("Trying to write to PRG RAM in Mapper 0")
}

update_mapper_1 :: proc(mi: ^MapperInfo, addr: u16, data: u8) {
	// MMC1 shift register protocol only applies to $8000-$FFFF
	// Ignore writes to $6000-$7FFF (PRG RAM)
	if addr < 0x8000 do return

	// Check if bit 7 is set (reset)
	if data & 0x80 != 0 {
		// Reset shift register
		mi.info[0] = 0
		mi.info[1] = 0
		// Force PRG mode 3 (control register |= 0x0C)
		mi.info[2] = mi.info[2] | 0x0C
		return
	}

	// Serial write - shift bit 0 into shift register
	shift_val := mi.info[0]
	write_count := mi.info[1]

	// Shift bit 0 of data into the shift register
	shift_val = shift_val >> 1
	shift_val = shift_val | (int(data & 0x01) << 4)
	write_count += 1

	mi.info[0] = shift_val
	mi.info[1] = write_count

	// Check if we've received 5 writes
	if write_count == 5 {
		// Determine target register based on address bits A14:A13
		addr_bits := addr & 0x6000

		switch addr_bits {
		case 0x0000:
			// $8000-$9FFF - Control register (5 bits)
			mi.info[2] = shift_val & 0x1F
		case 0x2000:
			// $A000-$BFFF - CHR Bank 0 (5 bits)
			mi.info[3] = shift_val & 0x1F
		case 0x4000:
			// $C000-$DFFF - CHR Bank 1 (5 bits)
			mi.info[4] = shift_val & 0x1F
		case 0x6000:
			// $E000-$FFFF - PRG Bank (4 bits)
			mi.info[5] = shift_val & 0x0F
		}

		// Reset shift register
		mi.info[0] = 0
		mi.info[1] = 0
	}
}

update_mapper_2 :: proc(mi: ^MapperInfo, data: u8) {
	mi.info[0] = auto_cast (data & 0b0000_1111)
}

init_mapper :: proc(mapper_num: int, mi: ^MapperInfo, nprg: int, nchr: int) {

	mi.num = mapper_num

	switch mapper_num {
	case 0:
		init_mapper_0(mi, nprg)
	case 1:
		init_mapper_1(mi, nprg)
	case 2:
		init_mapper_2(mi, nprg)
	}
}

init_mapper_0 :: proc(mi: ^MapperInfo, nprg: int) {
	// For Mapper 0, just store the number of PRG banks in the
	// first element of the info (either 1 or 2)
	mi.info[0] = nprg
}

init_mapper_1 :: proc(mi: ^MapperInfo, nprg: int) {
	// For Mapper 1 (MMC1), initialize shift register and internal registers
	// info[0]: Shift register accumulated value (initially 0)
	// info[1]: Shift register write count (initially 0)
	// info[2]: Control register (initialize to 0x0C - PRG mode 3)
	// info[3]: CHR Bank 0 register (initially 0)
	// info[4]: CHR Bank 1 register (initially 0)
	// info[5]: PRG Bank register (initially 0)
	// info[6]: Number of PRG banks (for boundary checking)
	mi.info[0] = 0
	mi.info[1] = 0
	mi.info[2] = 0x0C
	mi.info[3] = 0
	mi.info[4] = 0
	mi.info[5] = 0
	mi.info[6] = nprg
}

init_mapper_2 :: proc(mi: ^MapperInfo, nprg: int) {
	// FOr Mapper 2, store the current bank in the first element
	// and the number of the last bank in the second element
	mi.info[0] = 0
	mi.info[1] = nprg - 1
}

prg_read :: proc(prg_rom: []u8, mi: ^MapperInfo, addr: u16) -> u8 {
	data: u8
	switch mi.num {
	case 0:
		data = read_mapper_0(prg_rom, mi, addr)
	case 1:
		data = read_mapper_1(prg_rom, mi, addr)
	case 2:
		data = read_mapper_2(prg_rom, mi, addr)
	case:
		log.fatal("Unimplemented mapper.")
	}
	return data
}

read_mapper_0 :: proc(prg_rom: []u8, mi: ^MapperInfo, addr: u16) -> u8 {
	nbanks := mi.info[0]
	addr := addr - 0x8000
	if nbanks == 1 && addr >= PRG_BANK_SIZE do addr = addr % PRG_BANK_SIZE
	return prg_rom[addr]
}

read_mapper_1 :: proc(prg_rom: []u8, mi: ^MapperInfo, addr: u16) -> u8 {
	// Get number of PRG banks for masking
	nprg := mi.info[6]
	// Extract PRG mode from Control register (bits 3:2)
	prg_mode := (mi.info[2] >> 2) & 0b11
	// Extract PRG bank number from PRG Bank register (bits 3:0)
	prg_bank := mi.info[5] & 0x0F
	// Convert CPU address to offset
	offset := int(addr - 0x8000)

	// Fast path: handle 1-bank PRG edge case in 32KB mode
	if nprg == 1 && prg_mode <= 1 {
		return prg_rom[offset % PRG_BANK_SIZE]
	}

	rom_addr: int

	switch prg_mode {
	case 0, 1:
		// Mode 0 or 1: 32KB mode
		// Ignore bit 0 of prg_bank, mask to available banks
		prg_bank_u32: u32 = auto_cast prg_bank
		not1: u32 = auto_cast ~u32(1)
		base := (prg_bank_u32 & not1) & u32(nprg - 1)
		rom_addr = int(base) * PRG_BANK_SIZE + offset
	case 2:
		// Mode 2: Fix first 16KB at $8000, switch 16KB at $C000
		if offset < PRG_BANK_SIZE {
			// $8000-$BFFF: Use bank 0
			rom_addr = offset
		} else {
			// $C000-$FFFF: Use switchable bank (masked to available banks)
			bank := prg_bank & (nprg - 1)
			rom_addr = bank * PRG_BANK_SIZE + (offset - PRG_BANK_SIZE)
		}
	case 3:
		// Mode 3: Fix last 16KB at $C000, switch 16KB at $8000
		if offset < PRG_BANK_SIZE {
			// $8000-$BFFF: Use switchable bank (masked to available banks)
			bank := prg_bank & (nprg - 1)
			rom_addr = bank * PRG_BANK_SIZE + offset
		} else {
			// $C000-$FFFF: Use last bank
			rom_addr = (nprg - 1) * PRG_BANK_SIZE + (offset - PRG_BANK_SIZE)
		}
	}

	return prg_rom[rom_addr]
}

read_mapper_2 :: proc(prg_rom: []u8, mi: ^MapperInfo, addr: u16) -> u8 {
	addr: int = auto_cast addr - 0x8000

	if addr < PRG_BANK_SIZE {
		return prg_rom[PRG_BANK_SIZE * mi.info[0] + addr]
	} else {
		addr = addr % PRG_BANK_SIZE
		return prg_rom[PRG_BANK_SIZE * mi.info[1] + addr]
	}
}

chr_read :: proc(chr_rom: []u8, mi: ^MapperInfo, addr: u16) -> u8 {
	data: u8
	switch mi.num {
	case 0:
		data = read_mapper_0_chr(chr_rom, mi, addr)
	case 1:
		data = read_mapper_1_chr(chr_rom, mi, addr)
	case 2:
		data = read_mapper_2_chr(chr_rom, mi, addr)
	case:
		log.fatal("Unimplemented mapper.")
	}
	return data
}

read_mapper_0_chr :: proc(chr_rom: []u8, mi: ^MapperInfo, addr: u16) -> u8 {
	return chr_rom[addr]
}

read_mapper_1_chr :: proc(chr_rom: []u8, mi: ^MapperInfo, addr: u16) -> u8 {
	// Extract CHR mode from Control register (bit 4)
	chr_mode := (mi.info[2] >> 4) & 0x01

	// Compute number of 8KB and 4KB banks available
	n8k := len(chr_rom) / CHR_BANK_SIZE
	n4k := len(chr_rom) / 0x1000
	// Guard to at least 1
	if n8k < 1 do n8k = 1
	if n4k < 1 do n4k = 1

	rom_addr: int

	if chr_mode == 0 {
		// 8KB mode: Use CHR Bank 0 with bit 0 masked
		// Extract base 4KB bank index (ignore bit 0, use bits 4:1 directly)
		base4k := mi.info[3] & 0x1E
		// Constrain to available banks (mask to valid 8KB bank range in 4KB units)
		base4k = base4k % (n8k * 2)
		rom_addr = base4k * 0x1000 + int(addr)
	} else {
		// 4KB mode: Two independent 4KB banks
		// Mask banks to available CHR size
		b0 := mi.info[3] % n4k
		b1 := mi.info[4] % n4k

		if addr < 0x1000 {
			// $0000-$0FFF: Use CHR Bank 0
			rom_addr = b0 * 0x1000 + int(addr)
		} else {
			// $1000-$1FFF: Use CHR Bank 1
			rom_addr = b1 * 0x1000 + int(addr - 0x1000)
		}
	}

	return chr_rom[rom_addr]
}

read_mapper_2_chr :: proc(chr_rom: []u8, mi: ^MapperInfo, addr: u16) -> u8 {
	return chr_rom[addr]
}
