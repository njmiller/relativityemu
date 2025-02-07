package nes

import "core:fmt"
import "core:log"

Mirroring :: enum {
	VERTICAL,
	HORIZONTAL,
	FOUR_SCREEN,
}

Ricoh2c02 :: struct {
	chr_rom:           []u8,
	palette_table:     [32]u8,
	vram:              [2048]u8,
	oam_data:          [256]u8,
	oam_addr:          u8,
	mirroring:         Mirroring,
	addr:              AddrRegister,
	ctrl:              Controller_Bitset,
	mask:              Mask_Bitset,
	status:            Status_Bitset,
	scroll:            ScrollRegister,
	internal_data_buf: u8,
	w:                 bool,
	x:                 u8,
	v, t:              u16,
	scanline:          u16,
	cycles:            int,
	nmi_interrupt:     bool,
	frame:             Frame,
	is_chr_ram:        bool,
}

// 0x2000 - Controller register (write)
// 0x2001 - Mask register (write) - done
// 0x2002 - Status register (read)
// 0x2003 - OAM address (write)
// 0x2004 - OAM data (read/write)
// 0x2005 - Scroll (write x2) - done
// 0x2006 - Address (write x2)
// 0x2007 - Data (read/write)
// 0x2009 - OAM DMA (write)
// 0x4014 - OAM DMA

// Structure and functions related to the address register
AddrRegister :: struct {
	value: [2]u8,
	// hi_ptr: bool,
	t:     u16,
}

// new_addr_register :: proc() -> AddrRegister {
// addr: AddrRegister
// addr.hi_ptr = true

// return addr
// }

set_addr :: proc(addr: ^AddrRegister, data: u16) {
	// addr.value[0] = auto_cast (data >> 8)
	// addr.value[1] = auto_cast (data & 0xFF)
	addr.t = data
}

get_addr :: proc(addr: ^AddrRegister) -> u16 {
	// return (u16(addr.value[0]) << 8) | u16(addr.value[1])
	return addr.t
	// return ppu.x
}

update_addr :: proc(addr: ^AddrRegister, hi_ptr: bool, data: u8) {
	if hi_ptr {
		// addr.value[0] = data
		addr.t = (addr.t & 0x00FF) | (u16(data) << 8)
	} else {
		// addr.value[1] = data
		addr.t = (addr.t & 0xFF00) | u16(data)
	}

	// Mirror down the address if above 0x3FFF
	// 0x3FFF = 0b00111111_11111111
	// if int(get_addr(addr)) > 0x3FFF do set_addr(addr, get_addr(addr) & 0x3FFF)
	if addr.t > 0x3FFF do addr.t &= 0x3FFF
}

increment_addr :: proc(addr: ^AddrRegister, inc: u8) {

	// Increment the lower bits and if it carries then increment the higher bits by 1 
	// lo := addr.value[1]
	// addr.value[1] += inc
	// if lo > addr.value[1] do addr.value[0] += 1

	addr.t += u16(inc)

	// Mirror down the address if above 0x3FFF
	// 0x3FFF = 0b00111111_11111111
	// if int(get_addr(addr)) > 0x3FFF do set_addr(addr, get_addr(addr) & 0x3FFF)
	if addr.t > 0x3FFF do addr.t &= 0x3FFF
}

reset_latch :: proc(ppu: ^Ricoh2c02) {
	ppu.w = true
}

write_to_addr :: proc(ppu: ^Ricoh2c02, value: u8) {
	update_addr(&ppu.addr, ppu.w, value)
	// if ppu.w {
	// Zeroth 14th bit on first write
	// value := value & 0b1011_1111
	// ppu.t = u16(value) << 8 & (ppu.t & 0x00FF)
	// } else {
	// ppu.t = (ppu.t & 0xFF00) | u16(value)
	// }
	ppu.w = !ppu.w
}

// Controller Register
// 
// 7  bit  0
// ---- ----
// VPHB SINN
// |||| ||||
// |||| ||++- Base nametable address 
// |||| ||    (0 = $2000; 1 = $2400; 2 = $2800; 3 = $2C00)
// |||| |+--- VRAM address increment per CPU read/write of PPUDATA
// |||| |     (0: add 1, going across; 1: add 32, going down)
// |||| +---- Sprite pattern table address for 8x8 sprites
// ||||       (0: $0000; 1: $1000; ignored in 8x16 mode)
// |||+------ Background pattern table address (0: $0000; 1: $1000)
// ||+------- Sprite size (0: 8x8 pixels; 1: 8x16 pixels – see PPU OAM#Byte 1)
// |+-------- PPU master/slave select
// |          (0: read backdrop from EXT pins; 1: output color on EXT pins)
// +--------- Vblank NMI enable (0: off; 1: on)
//
Controller_Flags :: enum u8 {
	NAMETABLE1              = 0b00000001,
	NAMETABLE2              = 0b00000010,
	VRAM_ADD_INCREMENT      = 0b00000100,
	SPRITE_PATTERN_ADDR     = 0b00001000,
	BACKGROUND_PATTERN_ADDR = 0b00010000,
	SPRITE_SIZE             = 0b00100000,
	MASTER_SLAVE_SELECT     = 0b01000000,
	NMI_ENABLE              = 0b10000000,
}

Controller_Bitset :: bit_set[Controller_Flags]

new_controller_bitset :: proc() -> Controller_Bitset {
	return Controller_Bitset{}
}

vram_addr_increment :: proc(controller: ^Controller_Bitset) -> u8 {
	if .VRAM_ADD_INCREMENT in controller {
		return 32
	} else {
		return 1
	}
}

get_controller_bitset :: proc(data: u8) -> Controller_Bitset {
	bitset_tmp := Controller_Bitset{}

	for i in 0 ..< 8 {
		bit_tmp := u8(1) << uint(i)
		if bit_tmp & data != 0 do bitset_tmp += {Controller_Flags(bit_tmp)}
	}

	return bitset_tmp
}

@(private)
write_to_ctrl :: proc(ppu: ^Ricoh2c02, value: u8) {
	before_nmi_status := generate_vblank_nmi(ppu.ctrl)
	ppu.ctrl = get_controller_bitset(value)
	if !before_nmi_status && generate_vblank_nmi(ppu.ctrl) && is_in_vblank(ppu.status) {
		ppu.nmi_interrupt = true
	}
}

poll_nmi_interrupt :: proc(ppu: ^Ricoh2c02) -> bool {
	// Returns the value of nmi_interrupt and sets it to false
	prev_nmi_interrupt := ppu.nmi_interrupt
	ppu.nmi_interrupt = false

	return prev_nmi_interrupt
}

generate_vblank_nmi :: proc(ctrl: Controller_Bitset) -> bool {
	return .NMI_ENABLE in ctrl
}

get_nametable_addr :: proc(ctrl: Controller_Bitset) -> u16 {
	nametable_num := 0
	nametable_num += 1 if .NAMETABLE1 in ctrl else 0
	nametable_num += 2 if .NAMETABLE2 in ctrl else 0

	nametable_addr: u16
	switch nametable_num {
	case 0:
		nametable_addr = 0x2000
	case 1:
		nametable_addr = 0x2400
	case 2:
		nametable_addr = 0x2800
	case 3:
		nametable_addr = 0x2C00
	case:
		log.fatal("Nametable num is an invalid value.")
	}
	return nametable_addr
}

get_background_pattern_addr :: proc(ctrl: Controller_Bitset) -> u16 {
	addr: u16 = 0x1000 if .BACKGROUND_PATTERN_ADDR in ctrl else 0x0000
	return addr
}

get_sprite_pattern_addr :: proc(ctrl: Controller_Bitset) -> u16 {
	addr: u16 = 0x1000 if .SPRITE_PATTERN_ADDR in ctrl else 0x0000
	return addr
}

// Mask Register ($2001 write)
//
// 7  bit  0
// ---- ----
// BGRs bMmG
// |||| ||||
// |||| |||+- Greyscale (0: normal color, 1: produce a greyscale display)
// |||| ||+-- 1: Show background in leftmost 8 pixels of screen, 0: Hide
// |||| |+--- 1: Show sprites in leftmost 8 pixels of screen, 0: Hide
// |||| +---- 1: Enable background rendering
// |||+------ 1: Enable sprite rendering
// ||+------- Emphasize red (green on PAL/Dendy)
// |+-------- Emphasize green (red on PAL/Dendy)
// +--------- Emphasize blue
//
Mask_Flags :: enum u8 {
	GREYSCALE            = 0b00000001,
	LEFTMOST8_BACKGROUND = 0b00000010,
	LEFTMOST8_SPRITE     = 0b00000100,
	SHOW_BACKGROUND      = 0b00001000,
	SHOW_SPRITES         = 0b00010000,
	EMPHASIZE_RED        = 0b00100000,
	EMPHASIZE_GREEN      = 0b01000000,
	EMPHASIZE_BLUE       = 0b10000000,
}

Mask_Bitset :: bit_set[Mask_Flags]

get_mask_bitset :: proc(data: u8) -> Mask_Bitset {
	bitset_tmp := Mask_Bitset{}

	for i in 0 ..< 8 {
		bit_tmp := u8(1) << uint(i)
		if bit_tmp & data != 0 do bitset_tmp += {Mask_Flags(bit_tmp)}
	}

	return bitset_tmp
}

show_sprites :: proc(ppu: ^Ricoh2c02) -> bool {
	return .SHOW_SPRITES in ppu.mask
}

show_background :: proc(ppu: ^Ricoh2c02) -> bool {
	return .SHOW_BACKGROUND in ppu.mask
}

@(private)
write_to_mask :: proc(ppu: ^Ricoh2c02, data: u8) {
	ppu.mask = get_mask_bitset(data)
}

// Status Register
// 
// 7  bit  0
// ---- ----
// VSO. ....
// |||| ||||
// |||+-++++- PPU open bus. Returns stale PPU bus contents.
// ||+------- Sprite overflow. The intent was for this flag to be set
// ||         whenever more than eight sprites appear on a scanline, but a
// ||         hardware bug causes the actual behavior to be more complicated
// ||         and generate false positives as well as false negatives; see
// ||         PPU sprite evaluation. This flag is set during sprite
// ||         evaluation and cleared at dot 1 (the second dot) of the
// ||         pre-render line.
// |+-------- Sprite 0 Hit.  Set when a nonzero pixel of sprite 0 overlaps
// |          a nonzero background pixel; cleared at dot 1 of the pre-render
// |          line.  Used for raster timing.
// +--------- Vertical blank has started (0: not in vblank; 1: in vblank).
//    		  Set at dot 1 of line 241 (the line *after* the post-render
//    		  line); cleared after reading $2002 and at dot 1 of the
//    		  pre-render line.
//
Status_Flags :: enum u8 {
	SPRITE_OVERFLOW = 0b00100000,
	SPRITE_0_HIT    = 0b01000000,
	VERTICAL_BLANK  = 0b10000000,
}

Status_Bitset :: bit_set[Status_Flags]

/*
set_sprite_overflow :: proc(status: Status_Bitset, set: bool) -> Status_Bitset {
	if set {
		return status + {.SPRITE_OVERFLOW}
	} else {
		return status - {.SPRITE_OVERFLOW}
	}
}
*/

set_sprite_overflow :: proc(ppu: ^Ricoh2c02, set: bool) {
	if set {
		ppu.status += {.SPRITE_OVERFLOW}
	} else {
		ppu.status -= {.SPRITE_OVERFLOW}
	}
}

set_sprite_0_hit :: proc(ppu: ^Ricoh2c02, set: bool) {
	if set {
		ppu.status += {.SPRITE_0_HIT}
	} else {
		ppu.status -= {.SPRITE_0_HIT}
	}
}

set_vertical_blank :: proc(ppu: ^Ricoh2c02, set: bool) {
	if set {
		ppu.status += {.VERTICAL_BLANK}
	} else {
		ppu.status -= {.VERTICAL_BLANK}
	}
}

is_in_vblank :: proc(status: Status_Bitset) -> bool {
	return .VERTICAL_BLANK in status
}

get_status_bitset :: proc(data: u8) -> Status_Bitset {
	bitset_tmp := Status_Bitset{}

	for i in 5 ..< 8 {
		bit_tmp := u8(1) << uint(i)
		if bit_tmp & data != 0 do bitset_tmp += {Status_Flags(bit_tmp)}
	}

	return bitset_tmp
}

@(private)
read_ppu_status :: proc(ppu: ^Ricoh2c02) -> u8 {

	stat_u8: u8 = 0

	// Reading status resets the w register.
	if context.user_index == 0 do reset_latch(ppu)

	if .SPRITE_OVERFLOW in ppu.status do stat_u8 |= u8(Status_Flags.SPRITE_OVERFLOW)
	if .SPRITE_0_HIT in ppu.status do stat_u8 |= u8(Status_Flags.SPRITE_0_HIT)
	if .VERTICAL_BLANK in ppu.status do stat_u8 |= u8(Status_Flags.VERTICAL_BLANK)

	return stat_u8
}

write_oamaddr :: proc(ppu: ^Ricoh2c02, mem_addr: u8) {
	ppu.oam_addr = mem_addr
}

read_oamdata :: proc(ppu: ^Ricoh2c02) -> u8 {
	return ppu.oam_data[ppu.oam_addr]
}

write_oamdata :: proc(ppu: ^Ricoh2c02, data: u8) {
	ppu.oam_data[ppu.oam_addr] = data
	ppu.oam_addr += 1
}

ScrollRegister :: struct {
	x_scroll: u8,
	y_scroll: u8,
}

@(private)
write_to_scroll :: proc(ppu: ^Ricoh2c02, data: u8) {

	if ppu.w {
		ppu.scroll.x_scroll = data
	} else {
		ppu.scroll.y_scroll = data
	}

	ppu.w = !ppu.w
}

@(private)
read_ppu_data :: proc(ppu: ^Ricoh2c02) -> u8 {
	// mem_addr := get_addr(&ppu.addr)
	mem_addr := ppu.addr.t

	// Because for debugging output we don't want to increment addr on read
	if context.user_index == 0 do increment_vram_addr(ppu)

	result: u8
	switch mem_addr {
	case 0 ..= 0x1FFF:
		result = ppu.internal_data_buf
		ppu.internal_data_buf = ppu.chr_rom[mem_addr]
	case 0x2000 ..= 0x2FFF:
		result = ppu.internal_data_buf
		ppu.internal_data_buf = ppu.vram[mirror_vram_addr(mem_addr, ppu.mirroring)]
	case 0x3000 ..= 0x3EFF:
		// $3000-3EFF is usually a mirror of the 2kB region from $2000-2EFF. 
		// The PPU does not render from this address range, so this space has negligible utility.
		result = ppu.internal_data_buf
		ppu.internal_data_buf = ppu.vram[mirror_vram_addr(mem_addr - 0x1000, ppu.mirroring)]
	// log.error("Address space 0x3000..0x3EFF is not expected to be used:", mem_addr)
	// Addresses $3F10/$3F14/$3F18/$3F1C are mirrors of $3F00/$3F04/$3F08/$3F0C. 
	// Note that this goes for writing as well as reading. A symptom of not having implemented
	//  this correctly in an emulator is the sky being black in Super Mario Bros., which writes
	//  the backdrop color through $3F10.
	case 0x3F10, 0x3F14, 0x3F18, 0x3F1C:
		add_mirror := mem_addr - 0x10
		result = ppu.palette_table[(add_mirror - 0x3F00)]
	case 0x3F00 ..= 0x3FFF:
		// Don't need a dummy read for palette table
		add_mirror := (mem_addr - 0x3F00) % 0x20
		result = ppu.palette_table[add_mirror]
	}

	return result
}

@(private)
write_to_ppu_data :: proc(ppu: ^Ricoh2c02, data: u8) {
	// mem_addr := get_addr(&ppu.addr)
	mem_addr := ppu.addr.t
	increment_vram_addr(ppu)

	switch mem_addr {
	case 0 ..= 0x1FFF:
		if ppu.is_chr_ram do ppu.chr_rom[mem_addr] = data
		else do log.warn("Trying to write to CHR Rom")
	case 0x2000 ..= 0x2FFF:
		mem_addr_mirror := mirror_vram_addr(mem_addr, ppu.mirroring)
		ppu.vram[mem_addr_mirror] = data
	case 0x3000 ..= 0x3EFF:
		// $3000-3EFF is usually a mirror of the 2kB region from $2000-2EFF. 
		// The PPU does not render from this address range, so this space has negligible utility.
		mem_addr_mirror := mirror_vram_addr(mem_addr - 0x1000, ppu.mirroring)
		ppu.vram[mem_addr_mirror] = data
	// log.error("Address space 0x3000..0x3EFF is not expected to be used:", mem_addr)
	// Addresses $3F10/$3F14/$3F18/$3F1C are mirrors of $3F00/$3F04/$3F08/$3F0C. 
	// Note that this goes for writing as well as reading. A symptom of not having implemented
	//  this correctly in an emulator is the sky being black in Super Mario Bros., which writes
	//  the backdrop color through $3F10.
	case 0x3F10, 0x3F14, 0x3F18, 0x3F1C:
		add_mirror := mem_addr - 0x10
		ppu.palette_table[(add_mirror - 0x3F00)] = data
	case 0x3F00 ..= 0x3FFF:
		// palette table data goes from 0x3F00 to 0x3F1F and then is mirrored all the way to 0x3FFF
		add_mirror := (mem_addr - 0x3F00) % 0x20
		ppu.palette_table[add_mirror] = data
	case:
		log.panic("Unexpected access to mirrored space:", mem_addr)
	}

}

increment_vram_addr :: proc(ppu: ^Ricoh2c02) {
	increment_addr(&ppu.addr, vram_addr_increment(&ppu.ctrl))

	// inc := vram_addr_increment(&ppu.ctrl)
	// ppu.t += u16(inc)

	// Mirror down the address if above 0x3FFF
	// 0x3FFF = 0b00111111_11111111
	// if ppu.t > 0x3FFF do ppu.t &= 0x3FFF
}

// TODO: Mirroring
mirror_vram_addr :: proc(mem_addr: u16, mirroring: Mirroring) -> u16 {
	mirrored_vram := mem_addr & 0b10111111111111
	vram_idx := mirrored_vram - 0x2000
	name_table := vram_idx / 0x400

	mem_addr_out := vram_idx
	switch mirroring {
	case .VERTICAL:
		if name_table == 2 || name_table == 3 do mem_addr_out = vram_idx - 0x800
	case .HORIZONTAL:
		if name_table == 1 || name_table == 2 {
			mem_addr_out = vram_idx - 0x400
		} else if name_table == 3 {
			mem_addr_out = vram_idx - 0x800
		}
	case .FOUR_SCREEN:
		log.warn("FOUR SCREEN Mirroring not implemented yet.")
	}

	return mem_addr_out
}

tick_ppu :: proc(ppu: ^Ricoh2c02, ncycles: int) -> bool {
	ppu.cycles += ncycles
	if ppu.cycles >= 341 {
		ppu.cycles -= 341
		ppu.scanline += 1

		if ppu.scanline == 241 {
			set_vertical_blank(ppu, true)
			set_sprite_0_hit(ppu, false)
			if generate_vblank_nmi(ppu.ctrl) do ppu.nmi_interrupt = true
		}

		if ppu.scanline >= 262 {
			ppu.scanline = 0
			ppu.nmi_interrupt = false
			set_sprite_0_hit(ppu, false)
			set_vertical_blank(ppu, false)
			return true
		}
	}
	return false
}

is_sprite_0_hit :: proc(ppu: ^Ricoh2c02, cycle: int) -> bool {
	y := u16(ppu.oam_data[0])
	x := int(ppu.oam_data[3])

	return y == ppu.scanline && x <= cycle && show_sprites(ppu)
}

write_ppu_register :: proc(ppu: ^Ricoh2c02, addr: u16, data: u8) {
	switch addr {
	case 0x2000:
		write_to_ctrl(ppu, data)
	case 0x2001:
		write_to_mask(ppu, data)
	case 0x2002:
		log.panic("Attempting to write to status which is read only")
	case 0x2003:
		write_oamaddr(ppu, data)
	case 0x2004:
		write_oamdata(ppu, data)
	case 0x2005:
		write_to_scroll(ppu, data)
	case 0x2006:
		write_to_addr(ppu, data)
	case 0x2007:
		write_to_ppu_data(ppu, data)
	case 0x2008 ..= PPU_REGISTERS_MIRRORS_END:
		// Calculate what address this address mirrors and write
		// to that address
		mirror_down_addr := addr & 0b00100000_00000111
		// fmt.printf("Writing %04X %04x\n", addr, mirror_down_addr)
		write_ppu_register(ppu, mirror_down_addr, data)
	}
}

read_ppu_register :: proc(ppu: ^Ricoh2c02, addr: u16) -> u8 {
	mem_val: u8
	switch addr {
	case 0x2000, 0x2001, 0x2003, 0x2005, 0x2006:
		when ODIN_DEBUG {
			mem_val = 0 // because I might be disassembling instruction
		} else {
			log.warn("Attempt to read from write-only PPU address:", addr)
			fmt.printf("%04X\n", addr)
		}
	case 0x2002:
		mem_val = read_ppu_status(ppu)
	case 0x2004:
		mem_val = read_oamdata(ppu)
	case 0x2007:
		mem_val = read_ppu_data(ppu)
	case 0x2008 ..= PPU_REGISTERS_MIRRORS_END:
		// Calculate what address this address mirrors and then
		// read from that address instead
		mirror_down_addr := addr & 0b00100000_00000111
		// fmt.printf("Reading %04X %04x\n", addr, mirror_down_addr)
		mem_val = read_ppu_register(ppu, mirror_down_addr)
	}
	return mem_val
}
