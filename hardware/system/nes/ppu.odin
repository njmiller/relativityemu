package nes

import "core:fmt"
import "core:log"
import "core:math/bits"

Mirroring :: enum {
	VERTICAL,
	HORIZONTAL,
	FOUR_SCREEN,
	ONE_SCREEN_LOWER,
	ONE_SCREEN_UPPER,
}

// Bit field internal types are u16 because they are
// used in addressing which is always u16
PpuRegBf :: bit_field u16 {
	coarse_x:    u16 | 5,
	coarse_y:    u16 | 5,
	nametable_x: u16 | 1,
	nametable_y: u16 | 1,
	fine_y:      u16 | 3,
}

PPUReg :: struct #raw_union {
	using bits: PpuRegBf,
	val:        u16,
}

Ricoh2c02 :: struct {
	chr_rom:            []u8,
	mapper:             ^MapperInfo,
	palette_table:      [32]u8,
	vram:               [2048]u8,
	oam_data:           [256]u8,
	oam_addr:           u8,
	mirroring:          Mirroring,
	ctrl:               Controller_Bitset,
	mask:               Mask_Bitset,
	status:             Status_Bitset,
	scroll:             ScrollRegister,
	internal_data_buf:  u8,
	w:                  bool,
	fine_x:             u16,
	v, t:               PPUReg,
	scanline:           int,
	cycles:             int,
	nmi_interrupt:      bool,
	frame:              Frame,
	is_chr_ram:         bool,
	frame_num:          int,

	// For bg tile loading
	tile_number:        u8,
	attr_data:          u8,
	pattern_table_low:  u8,
	pattern_table_high: u8,

	// Background shift register. Two tiles are always loaded
	// because for every 8 cycle period a max of two tiles may
	// be seen due to scrolling
	bg_high_shift:      u16,
	bg_low_shift:       u16,
	attr_low_shift:     u16,
	attr_high_shift:    u16,

	// For sprite rendering
	oam_secondary:      [32]u8, // contains OAM data of sprites on scanline
	sprite_count:       int, // number of sprites on scanline
	sprite_zero:        bool, // whether sprite 0 is one of the sprites on scanline
	sprite_shift_lo:    [8]u8, // low bit of pattern table for sprites
	sprite_shift_hi:    [8]u8, // high bit of pattern table for sprites

	// Rendered image in system palette color numbers
	image:              [FRAME_WIDTH * FRAME_HEIGHT]u8,
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

write_to_addr :: proc(ppu: ^Ricoh2c02, value: u8) {
	if !ppu.w {
		value := value & 0b1011_1111
		ppu.t.val = (ppu.t.val & 0x00FF) | (u16(value) << 8)
	} else {
		ppu.t.val = (ppu.t.val & 0xFF00) | u16(value)

		// On second write t is copied into v
		ppu.v.val = ppu.t.val

		// Ensure v is only 14 bits
		ppu.v.val &= 0x3FFF
	}

	ppu.w = !ppu.w
}

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
	// if !before_nmi_status && generate_vblank_nmi(ppu.ctrl) && is_in_vblank(ppu.status) {
	if !before_nmi_status && generate_vblank_nmi(ppu.ctrl) && .VERTICAL_BLANK in ppu.status {
		ppu.nmi_interrupt = true
	}

	// ppu.t.nametable = u16(value) & 0x3
	ppu.t.nametable_x = u16(value) & 0x1
	ppu.t.nametable_y = (u16(value) >> 1) & 0x1
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


get_mask_bitset :: proc(data: u8) -> Mask_Bitset {
	bitset_tmp := Mask_Bitset{}

	for i in 0 ..< 8 {
		bit_tmp := u8(1) << uint(i)
		if bit_tmp & data != 0 do bitset_tmp += {Mask_Flags(bit_tmp)}
	}

	return bitset_tmp
}

// @(private)
// write_to_mask :: proc(ppu: ^Ricoh2c02, data: u8) {
// ppu.mask = get_mask_bitset(data)
// }


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
	// if context.user_index == 0 do reset_latch(ppu)
	if context.user_index == 0 do ppu.w = false

	if .SPRITE_OVERFLOW in ppu.status do stat_u8 |= u8(Status_Flags.SPRITE_OVERFLOW)
	if .SPRITE_0_HIT in ppu.status do stat_u8 |= u8(Status_Flags.SPRITE_0_HIT)
	if .VERTICAL_BLANK in ppu.status do stat_u8 |= u8(Status_Flags.VERTICAL_BLANK)

	// Reading status clears vertical blank
	ppu.status -= {.VERTICAL_BLANK}

	return stat_u8
}

ScrollRegister :: struct {
	x_scroll: u8,
	y_scroll: u8,
}

@(private)
write_to_scroll :: proc(ppu: ^Ricoh2c02, data: u8) {

	if !ppu.w {
		ppu.scroll.x_scroll = data
		ppu.t.coarse_x = u16(data) >> 3
		ppu.fine_x = u16(data) & 0x7
	} else {
		ppu.scroll.y_scroll = data
		ppu.t.coarse_y = u16(data) >> 3
		ppu.t.fine_y = u16(data) & 0x7

	}

	ppu.w = !ppu.w
}

@(private)
read_ppu_data :: proc(ppu: ^Ricoh2c02, mem_addr: u16) -> u8 {
	// mem_addr := ppu.v.val

	// Because for debugging output we don't want to increment addr on read
	// if context.user_index == 0 do increment_vram_addr(ppu)

	result: u8
	switch mem_addr {
	case 0 ..= 0x1FFF:
		// result = ppu.internal_data_buf
		// ppu.internal_data_buf = ppu.chr_rom[mem_addr]
		result = ppu.chr_rom[chr_offset(ppu.chr_rom, ppu.mapper, mem_addr)]
	case 0x2000 ..= 0x2FFF:
		// result = ppu.internal_data_buf
		// ppu.internal_data_buf = ppu.vram[mirror_vram_addr(mem_addr, ppu.mirroring)]
		result = ppu.vram[mirror_vram_addr(mem_addr, ppu.mirroring)]
	case 0x3000 ..= 0x3EFF:
		// $3000-3EFF is usually a mirror of the 2kB region from $2000-2EFF. 
		// The PPU does not render from this address range, so this space has negligible utility.
		// result = ppu.internal_data_buf
		// ppu.internal_data_buf = ppu.vram[mirror_vram_addr(mem_addr - 0x1000, ppu.mirroring)]
		result = ppu.vram[mirror_vram_addr(mem_addr - 0x1000, ppu.mirroring)]
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
write_to_ppu_data :: proc(ppu: ^Ricoh2c02, mem_addr: u16, data: u8) {
	// mem_addr := ppu.v.val

	// increment_vram_addr(ppu)

	switch mem_addr {
	case 0 ..= 0x1FFF:
		if ppu.is_chr_ram do ppu.chr_rom[chr_offset(ppu.chr_rom, ppu.mapper, mem_addr)] = data
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
	// Palette RAM is only 6 bits wide, so the top two bits of the written value
	// are discarded. Masking here keeps every entry a valid SYSTEM_PALETTE index
	case 0x3F10, 0x3F14, 0x3F18, 0x3F1C:
		add_mirror := mem_addr - 0x10
		ppu.palette_table[(add_mirror - 0x3F00)] = data & 0x3F
	case 0x3F00 ..= 0x3FFF:
		// palette table data goes from 0x3F00 to 0x3F1F and then is mirrored all the way to 0x3FFF
		add_mirror := (mem_addr - 0x3F00) % 0x20
		ppu.palette_table[add_mirror] = data & 0x3F
	case:
		log.panic("Unexpected access to mirrored space:", mem_addr)
	}

}

increment_vram_addr :: proc(ppu: ^Ricoh2c02) {
	inc := vram_addr_increment(&ppu.ctrl)

	ppu.v.val += u16(inc)

	// Mirror down the address if above 0x3FFF
	// since it the address is only 14 bits
	if ppu.v.val > 0x3FFF do ppu.v.val &= 0x3FFF
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
	case .ONE_SCREEN_LOWER:
		mem_addr_out = vram_idx % 0x400
	case .ONE_SCREEN_UPPER:
		mem_addr_out = 0x400 + (vram_idx % 0x400)
	}

	return mem_addr_out
}

// Code to tick once so that we can guarantee we hit every cycle in a scanline
// https://www.nesdev.org/wiki/PPU_rendering
// Evaluate everything we need to do for the cycle and then increment the value
tick_once :: proc(ppu: ^Ricoh2c02) {
	// TODO: Clean up background tile loading and move stuff around to make
	//       render and shifting in more natural places

	// While this rends before loading new shifter. The pixel on these dots will not
	// be rendered from the unloaded tile
	if ppu.scanline >= 0 && ppu.scanline < 240 && ppu.cycles > 0 && ppu.cycles <= 256 {
		render_pixel(ppu)
	}

	// Do the stuff unique to the pre-render scanline
	if ppu.scanline == -1 {
		// At first dot of prerender scanline status is cleared
		if ppu.cycles == 1 {
			ppu.status -= {.SPRITE_0_HIT}
			ppu.status -= {.SPRITE_OVERFLOW}
			ppu.status -= {.VERTICAL_BLANK}
		}

		// During pixels 280 through 304 of this scanline, the vertical scroll bits are reloaded if rendering is enabled
		// Nametable bit mentioned at https://www.nesdev.org/wiki/PPU_scrolling
		if ppu.cycles >= 280 && ppu.cycles <= 304 {
			// TODO: reload vertical scroll bits
			if rendering_enabled(ppu) do copy_vertical_scroll(ppu)
		}

		// TODO: Skip last cycle if on odd frame
		if ppu.frame_num % 2 == 1 && ppu.cycles == 339 do ppu.cycles += 1
	}

	// Do the tile and sprite loading that is done during each scanline
	if ppu.scanline >= -1 && ppu.scanline <= 239 {
		// The data for each tile is fetched during this phase.
		if (ppu.cycles >= 1 && ppu.cycles <= 256) || (ppu.cycles >= 321 && ppu.cycles <= 336) {
			switch ppu.cycles % 8 {
			case 1:
				// The shifters are reloaded during ticks 9, 17, etc.
				if ppu.cycles > 1 do load_bg_shifter_registers(ppu)

				// https://www.nesdev.org/wiki/PPU_scrolling#Tile_and_attribute_fetching
				tile_addr := 0x2000 | (ppu.v.val & 0x0FFF)
				ppu.tile_number = read_ppu_data(ppu, tile_addr)
			// if ppu.scanline == 90 && ppu.cycles > 90 && ppu.cycles < 120 {
			// fmt.printf("TILES: %04d %04x %04d\n", ppu.cycles, tile_addr, ppu.tile_number)
			// mem_addr: u16 = 0x216E
			// fmt.println("MIRRORING:", ppu.mirroring)
			// tmp := read_ppu_data(ppu, mem_addr)
			// fmt.printf("ERT %04d\n", tmp)
			// tmp2 := mirror_vram_addr(mem_addr, ppu.mirroring)
			// fmt.println("MIRROR AAA", mem_addr, tmp2)
			// result := ppu.vram[tmp2]
			// fmt.println("RES: ", result)
			// }
			case 3:
				// https://www.nesdev.org/wiki/PPU_scrolling#Tile_and_attribute_fetching
				//  Low 12 bits (1111 is from the 0x23C0) 
				//  NN 1111 YYY XXX
				//  || |||| ||| +++-- high 3 bits of coarse X (x/4)
				//  || |||| +++------ high 3 bits of coarse Y (y/4)
				//  || ++++---------- attribute offset (960 bytes)
				//  ++--------------- nametable select
				coarse_x_3 := ppu.v.coarse_x >> 2
				coarse_y_3 := (ppu.v.coarse_y >> 2) << 3
				nametable_y := ppu.v.nametable_y << 11
				nametable_x := ppu.v.nametable_x << 10
				attr_addr := 0x23C0 | nametable_y | nametable_x | coarse_y_3 | coarse_x_3
				ppu.attr_data = read_ppu_data(ppu, attr_addr)

				// TODO: Need to understand this. Picking out 2 bits
				// of the 8 bit number
				// See this comment of nesdev forum:
				//     Yes. When the attribute byte comes back, the PPU feeds the
				//     bits through a multiplexer selected by coarse Y bit 1 and coarse X bit 1.
				if ppu.v.coarse_y & 0x02 != 0 do ppu.attr_data >>= 4
				if ppu.v.coarse_x & 0x02 != 0 do ppu.attr_data >>= 2
				ppu.attr_data &= 0x03

			case 5:
				// https://www.nesdev.org/wiki/PPU_pattern_tables (Addressing)
				bg_base: u16 = 0x1000 if .BACKGROUND_PATTERN_ADDR in ppu.ctrl else 0x0000
				patt_addr := bg_base | (u16(ppu.tile_number) << 4) | ppu.v.fine_y
				ppu.pattern_table_low = read_ppu_data(ppu, patt_addr)
			case 7:
				// https://www.nesdev.org/wiki/PPU_pattern_tables (Addressing)
				// offset by 8 for high pattern byte
				bg_base: u16 = 0x1000 if .BACKGROUND_PATTERN_ADDR in ppu.ctrl else 0x0000
				patt_addr := bg_base | (u16(ppu.tile_number) << 4) | ppu.v.fine_y + 0x8 // (also +8)
				ppu.pattern_table_high = read_ppu_data(ppu, patt_addr)
			// if ppu.scanline == 90 && ppu.cycles > 90 && ppu.cycles < 160 {
			// fmt.printf("ABC: %04d %04d %04X\n", ppu.cycles, ppu.tile_number, patt_addr)
			// }
			case 0:
				if rendering_enabled(ppu) do inc_horizontal_scroll(ppu)

			}

			// Since we are loading on first cycle of 8 we want to shift after loading
			shift_bg_shifters(ppu)
		}

		if ppu.cycles == 256 && rendering_enabled(ppu) do inc_vertical_scroll(ppu)

		if ppu.cycles == 257 {
			if rendering_enabled(ppu) do copy_horizontal_scroll(ppu)
			load_bg_shifter_registers(ppu)
		}

		if ppu.cycles == 337 {
			load_bg_shifter_registers(ppu)
		}

		// Can just shift sprites here. Stuff is always only shifted
		// on correct cycles and once it is shifted out we always
		// skip the sprite
		if ppu.cycles <= 300 do shift_sprite_shifters(ppu)

		// Sprite loading is done between cycles 257 and 320 but will do it
		// all within a single cycle
		if ppu.cycles == 337 {
			get_sprites_scanline(ppu)
			load_sprite_shifters(ppu)
			// if ppu.scanline == 179 {
			// fmt.printf(
			// "AFTER LOAD %08b %08b\n",
			// ppu.sprite_shift_lo[0],
			// ppu.sprite_shift_lo[1],
			// )
			// }
		}

		// if ppu.scanline == 179 && ppu.cycles > 337 {
		// fmt.printf("POP %08b %08b\n", ppu.sprite_shift_lo[0], ppu.sprite_shift_lo[1])
		// }

		// if ppu.scanline == 180 && ppu.cycles < 3 {
		// fmt.printf("POP2 %08b %08b\n", ppu.sprite_shift_lo[0], ppu.sprite_shift_lo[1])
		// }

	}

	// Scanlines 241-260 are vertical blanking lines. The only thing
	// that happens is VBlank and NMI occur on cycle 1 of scanline 241
	if ppu.scanline == 241 {
		if ppu.cycles == 1 {
			ppu.status += {.VERTICAL_BLANK}
			// ppu.status -= {.SPRITE_0_HIT}
			if generate_vblank_nmi(ppu.ctrl) do ppu.nmi_interrupt = true
		}
	}

	// Update cycle count and increment scanline
	ppu.cycles += 1

	if ppu.cycles >= 341 {
		ppu.cycles -= 341
		ppu.scanline += 1
	}

	if ppu.scanline >= 261 {
		ppu.scanline = -1
		ppu.frame_num += 1
	}

	// Just so it doesn't overflow, though it probably could happen fine.
	if ppu.frame_num >= 1000 do ppu.frame_num %= 1000

}

tick_ppu :: proc(ppu: ^Ricoh2c02, ncycles: int) -> bool {
	ppu.cycles += ncycles

	if ppu.cycles >= 341 {
		if is_sprite_0_hit(ppu, ppu.cycles) do ppu.status += {.SPRITE_0_HIT}

		ppu.cycles -= 341
		ppu.scanline += 1

		if ppu.scanline == 241 {
			ppu.status += {.VERTICAL_BLANK}
			ppu.status -= {.SPRITE_0_HIT}
			if generate_vblank_nmi(ppu.ctrl) do ppu.nmi_interrupt = true
		}

		if ppu.scanline >= 262 {
			ppu.scanline = 0
			ppu.nmi_interrupt = false
			ppu.status -= {.SPRITE_0_HIT}
			ppu.status -= {.VERTICAL_BLANK}
			return true
		}
	}
	return false
}

is_sprite_0_hit :: proc(ppu: ^Ricoh2c02, cycle: int) -> bool {
	y := int(ppu.oam_data[0])
	x := int(ppu.oam_data[3])

	return .SHOW_SPRITES in ppu.mask && y == ppu.scanline && x <= cycle
}

write_ppu_register :: proc(ppu: ^Ricoh2c02, addr: u16, data: u8) {
	switch addr {
	case 0x2000:
		write_to_ctrl(ppu, data)
	case 0x2001:
		ppu.mask = get_mask_bitset(data)
	// write_to_mask(ppu, data)
	case 0x2002:
		log.panic("Attempting to write to status which is read only")
	case 0x2003:
		ppu.oam_addr = data
	case 0x2004:
		ppu.oam_data[ppu.oam_addr] = data
		ppu.oam_addr += 1
	case 0x2005:
		write_to_scroll(ppu, data)
	case 0x2006:
		write_to_addr(ppu, data)
	case 0x2007:
		mem_addr := ppu.v.val
		write_to_ppu_data(ppu, mem_addr, data)
		increment_vram_addr(ppu)
	case 0x2008 ..= PPU_REGISTERS_MIRRORS_END:
		// Calculate what address this address mirrors and write
		// to that address
		mirror_down_addr := addr & 0b00100000_00000111
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
		// mem_val = read_oamdata(ppu)
		mem_val = ppu.oam_data[ppu.oam_addr]
	case 0x2007:
		// mem_addr := ppu.v.val
		mem_val = ppu.internal_data_buf
		ppu.internal_data_buf = read_ppu_data(ppu, ppu.v.val)
		// mem_val = read_ppu_data(ppu, mem_addr)
		if context.user_index == 0 do increment_vram_addr(ppu)
	case 0x2008 ..= PPU_REGISTERS_MIRRORS_END:
		// Calculate what address this address mirrors and then
		// read from that address instead
		mirror_down_addr := addr & 0b00100000_00000111
		// fmt.printf("Reading %04X %04x\n", addr, mirror_down_addr)
		mem_val = read_ppu_register(ppu, mirror_down_addr)
	}
	return mem_val
}

rendering_enabled :: proc(ppu: ^Ricoh2c02) -> bool {
	return (.SHOW_BACKGROUND in ppu.mask) || (.SHOW_SPRITES in ppu.mask)
}

copy_horizontal_scroll :: proc(ppu: ^Ricoh2c02) {
	if !rendering_enabled(ppu) do return

	ppu.v.coarse_x = ppu.t.coarse_x
	ppu.v.nametable_x = ppu.t.nametable_x
}

copy_vertical_scroll :: proc(ppu: ^Ricoh2c02) {
	if !rendering_enabled(ppu) do return

	ppu.v.coarse_y = ppu.t.coarse_y
	ppu.v.fine_y = ppu.t.fine_y
	ppu.v.nametable_y = ppu.t.nametable_y
}

// This is for incrementing the coarse values in v
// The coarse values go from 0-31 and if we carry
// we change the nametable bit
// Discussed in "Wrapping around" section in https://www.nesdev.org/wiki/PPU_scrolling
inc_horizontal_scroll :: proc(ppu: ^Ricoh2c02) {
	if !rendering_enabled(ppu) do return

	if ppu.v.coarse_x == 31 {
		ppu.v.coarse_x = 0
		ppu.v.nametable_x = ~ppu.v.nametable_x
	} else do ppu.v.coarse_x += 1
}

inc_vertical_scroll :: proc(ppu: ^Ricoh2c02) {
	if !rendering_enabled(ppu) do return

	if ppu.v.fine_y < 7 do ppu.v.fine_y += 1
	else {
		ppu.v.fine_y = 0
		if ppu.v.coarse_y == 29 {
			ppu.v.coarse_y = 0
			ppu.v.nametable_y = ~ppu.v.nametable_y
		} else if ppu.v.coarse_y == 31 {
			ppu.v.coarse_y = 0
		} else do ppu.v.coarse_y += 1
	}
}

// Add into low bits and shift to left because left most
// bit in u8 is first to be rendered. When I see random comments
// it says new values put into high bits and everything is shifted
// lower, but both emulators whose code I have looked at 
// do it the other way around which would seem correct
// for rendering from left to right
load_bg_shifter_registers :: proc(ppu: ^Ricoh2c02) {
	ppu.bg_low_shift |= u16(ppu.pattern_table_low)
	ppu.bg_high_shift |= u16(ppu.pattern_table_high)

	// Attributes is 2 bits that is used for a whole tile
	// We expand the current two bits into separate shifters
	// that have the same value for the whole 8 bits so
	// everything can be shifted every cycle
	ppu.attr_low_shift |= 0xFF if ppu.attr_data & 0b01 != 0 else 0x00
	ppu.attr_high_shift |= 0xFF if ppu.attr_data & 0b10 != 0 else 0x00

}

shift_bg_shifters :: proc(ppu: ^Ricoh2c02) {
	if !rendering_enabled(ppu) do return

	// Shift once per cycle so we always access the same bit each cycle for
	// determining the color of the pixel to render.
	ppu.bg_low_shift <<= 1
	ppu.bg_high_shift <<= 1
	ppu.attr_low_shift <<= 1
	ppu.attr_high_shift <<= 1
}

render_pixel :: proc(ppu: ^Ricoh2c02) {
	// if ppu.scanline == 180 && ppu.cycles % 10 == 0 {
	// fmt.printf(
	// "TEST %04d %08b %08b\n",
	// ppu.cycles,
	// ppu.sprite_shift_lo[0],
	// ppu.sprite_shift_lo[1],
	// )
	// }

	// Get the background pixel color
	// bit_mux: u16 = (1 << (15 - ppu.fine_x))
	bit_mux: u16 = 0x8000 >> ppu.fine_x

	bg_color: u8 = 1 if ppu.bg_low_shift & bit_mux != 0 else 0
	bg_color += 2 if ppu.bg_high_shift & bit_mux != 0 else 0

	bg_pal: u8 = 1 if ppu.attr_low_shift & bit_mux != 0 else 0
	bg_pal |= 2 if ppu.attr_high_shift & bit_mux != 0 else 0

	// If we are not showing the background, set it to transparent
	if .SHOW_BACKGROUND not_in ppu.mask do bg_color = 0

	// If we are in the left most 8 pixels and not showing it, set it to transparent
	if .LEFTMOST8_BACKGROUND not_in ppu.mask && ppu.cycles <= 8 do bg_color = 0

	// Get the foreground pixel OAM data
	// sprite_oam: [4]u8

	sprite_color: u8 = 0
	sprite_pal: u8 = 4
	sprite_priority := false
	sprite_0_render := false
	// if ppu.scanline == 180 && ppu.cycles == 1 {
	// fmt.println("SPRITE COUNT RENDER:", ppu.sprite_count)
	// fmt.println("OAM SECONDARY:", ppu.oam_secondary[0:8])
	// fmt.printf("ATTRIBUTES %08b %08b\n", ppu.oam_secondary[2], ppu.oam_secondary[6])
	// fmt.printf("SPR SHIFT HI 1: %08b %08b\n", ppu.sprite_shift_hi[0], ppu.sprite_shift_hi[1])
	// fmt.printf("SPR SHIFT LO 1: %08b %08b\n", ppu.sprite_shift_lo[0], ppu.sprite_shift_lo[1])
	// }
	// if ppu.scanline == 180 && ppu.cycles == 53 {
	// fmt.println("SPRITE COUNT RENDER:", ppu.sprite_count)
	// fmt.println("OAM SECONDARY:", ppu.oam_secondary[0:8])
	// fmt.printf("ATTRIBUTES %08b %08b\n", ppu.oam_secondary[2], ppu.oam_secondary[6])
	// fmt.printf("SPR SHIFT HI 2: %08b %08b\n", ppu.sprite_shift_hi[0], ppu.sprite_shift_hi[1])
	// fmt.printf("SPR SHIFT LO 2: %08b %08b\n", ppu.sprite_shift_lo[0], ppu.sprite_shift_lo[1])
	// }
	// Determine first sprite that is not transparent
	for i in 0 ..< ppu.sprite_count {
		sprite_x := ppu.oam_secondary[4 * i + 3]

		// Skip if we haven't passed the x position of this sprite
		if sprite_x > u8(ppu.cycles) - 1 do continue

		pattern: u8 = 2 if ppu.sprite_shift_hi[i] & 0b1000_0000 != 0 else 0
		pattern |= 1 if ppu.sprite_shift_lo[i] & 0b1000_0000 != 0 else 0

		// If transparent go on to the next sprite
		if pattern == 0 do continue

		attr := ppu.oam_secondary[4 * i + 2]

		sprite_pal |= attr & 0x3
		sprite_color = pattern
		sprite_priority = attr & 0b0010_0000 == 0

		// First of the eight sprites is being rendered
		if i == 0 do sprite_0_render = true

		// if ppu.scanline == 180 && ppu.cycles == 53 {
		// fmt.println("SPRITES:", ppu.sprite_count, i)
		// }

		// if ppu.scanline == 180 && ppu.cycles == 126 {
		// fmt.println("SPRITES2:", ppu.sprite_count, i)
		// }
		break
	}

	if .SHOW_SPRITES not_in ppu.mask do sprite_color = 0
	if .LEFTMOST8_SPRITE not_in ppu.mask && ppu.cycles <= 8 do sprite_color = 0

	color: u8
	palette: u8

	rendering_sprite := false

	// Choose to render sprite or background
	// If either is transparent, render the other
	// If neither is transparent, render based on the sprite attribute
	if bg_color == 0 && sprite_color == 0 {
		color = 0
		palette = 0
	} else if bg_color == 0 {
		color = sprite_color
		palette = sprite_pal
		rendering_sprite = true
	} else if sprite_color == 0 {
		color = bg_color
		palette = bg_pal
	} else {
		if sprite_priority {
			color = sprite_color
			palette = sprite_pal
			rendering_sprite = true
		} else {
			color = bg_color
			palette = bg_pal
		}
	}

	// We need to be rendering both the background and sprites, have chosen
	// the sprite to render of the two, it is the first sprite in the secondary OAM, 
	// and the secondary OAM contains sprite 0
	render_both: Mask_Bitset : {.SHOW_BACKGROUND, .SHOW_SPRITES}
	if sprite_0_render && ppu.sprite_zero && render_both <= ppu.mask && rendering_sprite {
		show_left8: Mask_Bitset : {.LEFTMOST8_BACKGROUND, .LEFTMOST8_SPRITE}
		min_cycle := 2 if show_left8 <= ppu.mask else 9
		max_cycle := 255 // TODO: Check why 255 and not 256

		if min_cycle <= ppu.cycles && ppu.cycles <= max_cycle do ppu.status += {.SPRITE_0_HIT}

	}

	// Color index in the system palette
	color_render := ppu.palette_table[4 * palette + color]

	x_pos := ppu.cycles - 1
	y_pos := ppu.scanline
	idx := FRAME_WIDTH * y_pos + x_pos
	ppu.image[idx] = color_render

	// if ppu.cycles == 33 && ppu.scanline == 97 {
	// fmt.println("TMP:", palette, color, color_render)
	// }

	// if ppu.scanline == 120 {
	// fmt.println(ppu.cycles, ppu.bg_high_shift, ppu.bg_low_shift)
	// }
}

get_sprites_scanline :: proc(ppu: ^Ricoh2c02) {
	// Getting sprites for next scanline

	// Initialize
	ppu.oam_secondary = 0xFF
	ppu.sprite_count = 0
	ppu.sprite_zero = false

	next_scanline := u8(ppu.scanline + 1)

	sc := 0
	// if next_scanline == 180 do fmt.printf("YVALS ")
	for i in 0 ..< 64 {
		y := ppu.oam_data[4 * i]
		x := ppu.oam_data[4 * i + 3]

		// if next_scanline == 180 {
		// fmt.printf("%04d ", y)
		// }

		tile_id := ppu.oam_data[4 * i + 1]
		attr := ppu.oam_data[4 * i + 2]

		y_size: u8 = 16 if .SPRITE_SIZE in ppu.ctrl else 8

		if sc < 8 && next_scanline >= y && next_scanline < y + y_size {
			// TODO: See how to copy multiple bytes at once
			for j in 0 ..< 4 {
				ppu.oam_secondary[4 * sc + j] = ppu.oam_data[4 * i + j]
			}
			sc += 1

			// Sprite 0 is in the sprites to render on the next scanline
			if i == 0 do ppu.sprite_zero = true
		} else if sc == 8 {
			// 
			ppu.status += {.SPRITE_OVERFLOW}
		}

	}

	// if next_scanline == 180 do fmt.printf("\n")
	ppu.sprite_count = sc

	// if next_scanline == 180 do fmt.println("SPRITE COUNT:", sc)

}

load_sprite_shifters :: proc(ppu: ^Ricoh2c02) {
	// Load the secondary OAM data into the foreground shifters

	new_scanline := u8(ppu.scanline + 1)

	for i in 0 ..< ppu.sprite_count {
		sprite_y := ppu.oam_secondary[4 * i]
		sprite_tile := ppu.oam_secondary[4 * i + 1]
		sprite_attr := ppu.oam_secondary[4 * i + 2]

		flip_vertical := sprite_attr & 0b1000_0000 != 0
		flip_horizontal := sprite_attr & 0b0100_0000 != 0

		// We must now figure out the pattern for the sprite given the
		// scanline, y value, and whether it is flipped horizontal or vertical

		addr_lo: u16

		del_y := u16(new_scanline - sprite_y)

		if .SPRITE_SIZE not_in ppu.ctrl {
			// 8x8 sprites

			if flip_vertical do del_y = 7 - del_y

			sprite_base: u16 = 0x1000 if .SPRITE_PATTERN_ADDR in ppu.ctrl else 0x0000
			addr_lo = sprite_base | (u16(sprite_tile) << 4) | del_y

		} else {
			// 8x16 sprites

			sprite_base := (u16(sprite_tile) & 1) << 12
			tile_id_16 := sprite_tile & 0xFE

			if flip_vertical {
				del_y = 15 - del_y
				if del_y >= 8 {
					del_y -= 8
				} else {
					tile_id_16 += 1
				}
			} else {
				if del_y >= 8 {
					tile_id_16 += 1
					del_y -= 8
				}
			}

			addr_lo = sprite_base | (u16(tile_id_16) << 4) | del_y
		}

		// High address is offset by 8
		ppu.sprite_shift_lo[i] = read_ppu_data(ppu, addr_lo)
		ppu.sprite_shift_hi[i] = read_ppu_data(ppu, addr_lo + 8)

		if flip_horizontal {
			ppu.sprite_shift_lo[i] = bits.reverse_bits(ppu.sprite_shift_lo[i])
			ppu.sprite_shift_hi[i] = bits.reverse_bits(ppu.sprite_shift_hi[i])
		}
	}

	// if new_scanline == 180 {
	// fmt.printf("LOAD: %08b %08b\n", ppu.sprite_shift_lo[0], ppu.sprite_shift_lo[1])
	// }
}

// We only shift the sprite values once we would start rendering the sprite
// Once we have fully passed the sprite, the pattern would always show
// transparent and we would move onto the next sprite when determining
// a sprite to render
shift_sprite_shifters :: proc(ppu: ^Ricoh2c02) {
	if !rendering_enabled(ppu) do return

	for i in 0 ..< ppu.sprite_count {
		sprite_x := int(ppu.oam_secondary[4 * i + 3])
		if sprite_x + 1 < ppu.cycles {
			// if ppu.scanline == 179 do fmt.println("ABC", ppu.cycles, int(sprite_x) + 1)
			ppu.sprite_shift_lo[i] <<= 1
			ppu.sprite_shift_hi[i] <<= 1
		}
	}
}

// TODO: Use this function call instead of switch statement in tick_once
//       Should be called once every 8 ticks.
load_next_background_tile :: proc(ppu: ^Ricoh2c02) {
	// https://www.nesdev.org/wiki/PPU_scrolling#Tile_and_attribute_fetching
	tile_addr := 0x2000 | (ppu.v.val & 0x0FFF)
	ppu.tile_number = read_ppu_data(ppu, tile_addr)

	// https://www.nesdev.org/wiki/PPU_scrolling#Tile_and_attribute_fetching
	//  Low 12 bits (1111 is from the 0x23C0) 
	//  NN 1111 YYY XXX
	//  || |||| ||| +++-- high 3 bits of coarse X (x/4)
	//  || |||| +++------ high 3 bits of coarse Y (y/4)
	//  || ++++---------- attribute offset (960 bytes)
	//  ++--------------- nametable select
	coarse_x_3 := ppu.v.coarse_x >> 2
	coarse_y_3 := (ppu.v.coarse_y >> 2) << 3
	nametable_y := ppu.v.nametable_y << 11
	nametable_x := ppu.v.nametable_x << 10
	attr_addr := 0x23C0 | nametable_y | nametable_x | coarse_y_3 | coarse_x_3
	ppu.attr_data = read_ppu_data(ppu, attr_addr)

	// TODO: Need to understand this. Picking out 2 bits
	// of the 8 bit number
	// See this comment of nesdev forum:
	//     Yes. When the attribute byte comes back, the PPU feeds the
	//     bits through a multiplexer selected by coarse Y bit 1 and coarse X bit 1.
	if ppu.v.coarse_y & 0x02 != 0 do ppu.attr_data >>= 4
	if ppu.v.coarse_x & 0x02 != 0 do ppu.attr_data >>= 2
	ppu.attr_data &= 0x03

	// https://www.nesdev.org/wiki/PPU_pattern_tables (Addressing)
	bg_base: u16 = 0x1000 if .BACKGROUND_PATTERN_ADDR in ppu.ctrl else 0x0000
	patt_addr := bg_base | (u16(ppu.tile_number) << 4) | ppu.v.fine_y
	ppu.pattern_table_low = read_ppu_data(ppu, patt_addr)
	ppu.pattern_table_high = read_ppu_data(ppu, patt_addr + 8)

	load_bg_shifter_registers(ppu)
	inc_horizontal_scroll(ppu)
}
