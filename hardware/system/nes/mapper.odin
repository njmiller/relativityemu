package nes

import "core:log"

// Code to implement some "mapper" chips by storing the info needed to determine
// which PRG and CHR blocks are currently accessible to the NES.

// PRG_BANK_SIZE :: 0x4000 // defines in ines.odin

// Mappers to implement order: 9, 10, 69, 4

MapperInfo :: struct {
	num:  int,
	info: [20]int,
}

// Call the different mapper routines implemented in the mapper package.
update_mi :: proc(cart: ^Cartridge, addr: u16, data: u8, prg_val: u8) {
	// delete(bus.prg_rom)

	switch cart.mapper.num {
	case 0:
		update_mapper_0()
	case 1:
		update_mapper_1(cart, addr, data)
	case 2:
		update_mapper_2(cart, data, prg_val)
	case 3:
		update_mapper_3(cart, data, prg_val)
	case 7:
		update_mapper_7(cart, data)
	case 11:
		update_mapper_11(cart, data)
	case:
		log.fatal("Unimplemented mapper:", cart.mapper.num)
	}
}

update_mapper_0 :: proc() {
	log.fatal("Trying to write to PRG ROM in Mapper 0")
}

update_mapper_1 :: proc(cart: ^Cartridge, addr: u16, data: u8) {
	mi := &cart.mapper

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

			// Bits 1:0 select the nametable mirroring
			switch shift_val & 0x03 {
			case 0:
				cart.mirroring = .ONE_SCREEN_LOWER
			case 1:
				cart.mirroring = .ONE_SCREEN_UPPER
			case 2:
				cart.mirroring = .VERTICAL
			case 3:
				cart.mirroring = .HORIZONTAL
			}
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

// UxROM
update_mapper_2 :: proc(cart: ^Cartridge, data: u8, prg_val: u8) {
	latched := data & prg_val
	cart.mapper.info[0] = auto_cast (latched & 0b0000_1111)
}

// CNROM
update_mapper_3 :: proc(cart: ^Cartridge, data: u8, prg_val: u8) {
	latched := data & prg_val
	cart.mapper.info[0] = auto_cast (latched & 0b0000_0011)
}

// MMC3
update_mapper_4 :: proc(cart: ^Cartridge, data: u8, prg_val: u8) {
}

// AxROM
update_mapper_7 :: proc(cart: ^Cartridge, data: u8) {
	/* 7  bit  0
	   ---- ----
	   xxxM xPPP
          |  |||
          |  +++- Select 32 KB PRG ROM bank for CPU $8000-$FFFF
          +------ Select 1 KB VRAM page for all 4 nametables
	*/
	mi := &cart.mapper

	// The cart only decodes as many bank bits as it has 32 KB banks, so a write
	// of a bank past the end of the ROM wraps instead of running off it
	nbanks := mi.info[2] / 2
	if nbanks < 1 do nbanks = 1
	mi.info[0] = int(data & 0b0000_0111) & (nbanks - 1)

	// Set the nametable mirroring from the written bit
	cart.mirroring = data & 0b0001_0000 != 0 ? .ONE_SCREEN_UPPER : .ONE_SCREEN_LOWER
}

update_mapper_10 :: proc(cart: ^Cartridge, addr: u16, data: u8) {
}

update_mapper_11 :: proc(cart: ^Cartridge, data: u8) {
	/* 7  bit  0
	   ---- ----
	   CCCC LLPP
	   |||| ||||
	   |||| ||++- Select 32 KB PRG ROM bank for CPU $8000-$FFFF
	   |||| ++--- Used for lockout defeat
	   ++++------ Select 8 KB CHR ROM bank for PPU $0000-$1FFF
	*/

	cart.mapper.info[0] = int(data & 0b0000_0011)
	cart.mapper.info[1] = int((data & 0b1111_0000) >> 4)
}

init_mapper :: proc(cart: ^Cartridge) {

	cart.mapper.num = cart.mapper_num

	switch cart.mapper_num {
	case 0:
		init_mapper_0(cart)
	case 1:
		init_mapper_1(cart)
	case 2:
		init_mapper_2(cart)
	case 3:
		init_mapper_3(cart)
	case 7:
		init_mapper_7(cart)
	case 11:
		init_mapper_11(cart)
	}
}

init_mapper_0 :: proc(cart: ^Cartridge) {
	// For Mapper 0, just store the number of PRG banks in the
	// first element of the info (either 1 or 2)
	cart.mapper.info[0] = cart.nprg_banks
}

init_mapper_1 :: proc(cart: ^Cartridge) {
	mi := &cart.mapper

	// For Mapper 1 (MMC1), initialize shift register and internal registers
	// info[0]: Shift register accumulated value (initially 0)
	// info[1]: Shift register write count (initially 0)
	// info[2]: Control register (initialize to 0x0C - PRG mode 3)
	// info[3]: CHR Bank 0 register (initially 0)
	// info[4]: CHR Bank 1 register (initially 0)
	// info[5]: PRG Bank register (initially 0)
	// info[6]: Number of PRG banks (for boundary checking)
	// info[7]: Number of CHR banks (0 means the cart has CHR RAM)
	mi.info[0] = 0
	mi.info[1] = 0
	mi.info[2] = 0x0C
	mi.info[3] = 0
	mi.info[4] = 0
	mi.info[5] = 0
	mi.info[6] = cart.nprg_banks
	mi.info[7] = cart.nchr_banks
}

init_mapper_2 :: proc(cart: ^Cartridge) {
	// For Mapper 2, store the current bank in the first element
	// and the number of the last bank in the second element
	cart.mapper.info[0] = 0
	cart.mapper.info[1] = cart.nprg_banks - 1
}

init_mapper_3 :: proc(cart: ^Cartridge) {
	mi := &cart.mapper

	mi.info[0] = 0
	mi.info[1] = cart.nchr_banks - 1
	mi.info[2] = cart.nprg_banks
}

init_mapper_4 :: proc(cart: ^Cartridge) {
	mi := &cart.mapper

	// MMC3 has 2 swappable PRG ROM banks and 6 swappable CHR banks

	// 0-3 record what swappable values, the number of banks for the
	// fixed banks and which banks are swappable
	mi.info[0] = 0
	mi.info[1] = 0
	mi.info[2] = cart.nprg_banks
	mi.info[3] = 0

	// 4-10 record the 6 swappable CHR banks and the total number of
	// CHR banks.
	mi.info[4] = 0
	mi.info[5] = 0
	mi.info[6] = 0
	mi.info[7] = 0
	mi.info[8] = 0
	mi.info[9] = 0
	mi.info[10] = cart.nchr_banks

	// Ignoring PRG RAM protect as I need to map it through here.
}
init_mapper_7 :: proc(cart: ^Cartridge) {
	mi := &cart.mapper

	mi.info[0] = 0
	mi.info[1] = 0
	mi.info[2] = cart.nprg_banks

	// AxROM drives the nametable page from the bank latch, so the mirroring in
	// the header never applies. The latch powers up at 0, selecting the lower page
	cart.mirroring = .ONE_SCREEN_LOWER
}

init_mapper_11 :: proc(cart: ^Cartridge) {
	mi := &cart.mapper

	mi.info[0] = 0
	mi.info[1] = 0
	mi.info[2] = cart.nprg_banks
	mi.info[3] = cart.nchr_banks
}

prg_read :: proc(cart: ^Cartridge, addr: u16) -> u8 {
	data: u8
	switch cart.mapper.num {
	case 0:
		data = read_mapper_0(cart, addr)
	case 1:
		data = read_mapper_1(cart, addr)
	case 2:
		data = read_mapper_2(cart, addr)
	case 3:
		data = read_mapper_3(cart, addr)
	case 7, 11:
		data = read_mapper_7(cart, addr)
	case:
		log.fatal("Unimplemented mapper.")
	}
	return data
}

read_mapper_0 :: proc(cart: ^Cartridge, addr: u16) -> u8 {
	nbanks := cart.mapper.info[0]
	addr := addr - 0x8000
	if nbanks == 1 && addr >= PRG_BANK_SIZE do addr = addr % PRG_BANK_SIZE
	return cart.prg_rom[addr]
}

read_mapper_1 :: proc(cart: ^Cartridge, addr: u16) -> u8 {
	mi := &cart.mapper

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
		return cart.prg_rom[offset % PRG_BANK_SIZE]
	}

	// The PRG bank register is only 4 bits, so it can address at most 256KB.
	// On 512KB carts (SUROM) bit 4 of CHR Bank 0 drives PRG A18 and selects which
	// 256KB block the register indexes into. block_base is the first 16KB bank of
	// that block and banks is how many banks the register can reach inside it.
	block_base := 0
	banks := nprg
	if nprg > 16 {
		block_base = ((mi.info[3] >> 4) & 0x01) * 16
		banks = 16
	}

	rom_addr: int

	switch prg_mode {
	case 0, 1:
		// Mode 0 or 1: 32KB mode
		// Ignore bit 0 of prg_bank, mask to available banks
		bank := block_base + ((prg_bank &~ 1) & (banks - 1))
		rom_addr = bank * PRG_BANK_SIZE + offset
	case 2:
		// Mode 2: Fix first 16KB at $8000, switch 16KB at $C000
		if offset < PRG_BANK_SIZE {
			// $8000-$BFFF: Use the first bank of the current block
			rom_addr = block_base * PRG_BANK_SIZE + offset
		} else {
			// $C000-$FFFF: Use switchable bank (masked to available banks)
			bank := block_base + (prg_bank & (banks - 1))
			rom_addr = bank * PRG_BANK_SIZE + (offset - PRG_BANK_SIZE)
		}
	case 3:
		// Mode 3: Fix last 16KB at $C000, switch 16KB at $8000
		if offset < PRG_BANK_SIZE {
			// $8000-$BFFF: Use switchable bank (masked to available banks)
			bank := block_base + (prg_bank & (banks - 1))
			rom_addr = bank * PRG_BANK_SIZE + offset
		} else {
			// $C000-$FFFF: Use the last bank of the current block
			bank := block_base + banks - 1
			rom_addr = bank * PRG_BANK_SIZE + (offset - PRG_BANK_SIZE)
		}
	}

	return cart.prg_rom[rom_addr]
}

read_mapper_2 :: proc(cart: ^Cartridge, addr: u16) -> u8 {
	mi := &cart.mapper
	addr: int = auto_cast addr - 0x8000

	if addr < PRG_BANK_SIZE {
		return cart.prg_rom[PRG_BANK_SIZE * mi.info[0] + addr]
	} else {
		addr = addr % PRG_BANK_SIZE
		return cart.prg_rom[PRG_BANK_SIZE * mi.info[1] + addr]
	}
}

read_mapper_3 :: proc(cart: ^Cartridge, addr: u16) -> u8 {
	nbanks := cart.mapper.info[2]
	addr := addr - 0x8000
	if nbanks == 1 && addr >= PRG_BANK_SIZE do addr = addr % PRG_BANK_SIZE
	return cart.prg_rom[addr]
}

read_mapper_7 :: proc(cart: ^Cartridge, addr: u16) -> u8 {
	// PRG_BANK_SIZE is defined as 16 KB, however for this mapper
	// it is a full 32 KB switch
	addr : int = auto_cast addr - 0x8000
	return cart.prg_rom[2 * PRG_BANK_SIZE * cart.mapper.info[0] + addr]
}

// Read a byte of the cartridge's CHR data. The PPU only ever sees a flat 8 KB
// pattern table window, so the mapper decides which byte of CHR that really is
chr_read :: proc(cart: ^Cartridge, addr: u16) -> u8 {
	return cart.chr_rom[chr_offset(cart, addr)]
}

// Write a byte of CHR data. Only carts that shipped RAM in place of CHR ROM can
// be written, and the write is dropped on the ones that did not
chr_write :: proc(cart: ^Cartridge, addr: u16, data: u8) {
	if !cart.is_chr_ram {
		log.warn("Trying to write to CHR Rom")
		return
	}

	cart.chr_rom[chr_offset(cart, addr)] = data
}

// Convert a PPU pattern table address into an index into the CHR data. Used by
// both the reads and the CHR RAM writes so they always agree on the banking.
// All the calculations are done here because both chr_read and chr_write use
// the same logic whereas reading and writing to the PRG data use different
// logic
chr_offset :: proc(cart: ^Cartridge, addr: u16) -> int {
	switch cart.mapper.num {
	case 1:
		return offset_mapper_1_chr(cart, addr)
	case 3:
		return offset_mapper_3_chr(cart, addr)
	case 11:
		return offset_mapper_11_chr(cart, addr)
	case:
		// Mappers 0, 2, and 7 have no CHR banking
		return int(addr)
	}
}

offset_mapper_1_chr :: proc(cart: ^Cartridge, addr: u16) -> int {
	mi := &cart.mapper

	// Carts with CHR RAM only ever have 8KB of it and the MMC1 CHR outputs are not
	// wired to it, so the PPU addresses it directly. On 512KB PRG carts bit 4 of the
	// CHR register drives PRG A18 instead, so it must not shift the CHR window here.
	if mi.info[7] == 0 do return int(addr)

	// Extract CHR mode from Control register (bit 4)
	chr_mode := (mi.info[2] >> 4) & 0x01

	// Compute number of 8KB and 4KB banks available
	n8k := len(cart.chr_rom) / CHR_BANK_SIZE
	n4k := len(cart.chr_rom) / 0x1000
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

	return rom_addr
}

offset_mapper_3_chr :: proc(cart: ^Cartridge, addr: u16) -> int {
	chr_byte := cart.mapper.info[0] * 0x2000 + int(addr)
	return int(chr_byte)
}

offset_mapper_11_chr :: proc(cart: ^Cartridge, addr: u16) -> int {
	chr_byte := cart.mapper.info[1] * 0x2000 + int(addr)
	return int(chr_byte)
}
