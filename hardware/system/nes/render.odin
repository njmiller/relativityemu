package nes

import "core:fmt"
import "core:log"
import "core:mem"
import "core:slice"

// import rl "vendor:raylib"
import "vendor:sdl3"

NTSC_FRAME_RATE :: 29.97

/*
SYSTEM_PALETTE: [64]rl.Color =  {
	rl.Color{0x80, 0x80, 0x80, 0xFF},
	rl.Color{0x00, 0x3D, 0xA6, 0xFF},
	rl.Color{0x00, 0x12, 0xB0, 0xFF},
	rl.Color{0x44, 0x00, 0x96, 0xFF},
	rl.Color{0xA1, 0x00, 0x5E, 0xFF},
	rl.Color{0xC7, 0x00, 0x28, 0xFF},
	rl.Color{0xBA, 0x06, 0x00, 0xFF},
	rl.Color{0x8C, 0x17, 0x00, 0xFF},
	rl.Color{0x5C, 0x2F, 0x00, 0xFF},
	rl.Color{0x10, 0x45, 0x00, 0xFF},
	rl.Color{0x05, 0x4A, 0x00, 0xFF},
	rl.Color{0x00, 0x47, 0x2E, 0xFF},
	rl.Color{0x00, 0x41, 0x66, 0xFF},
	rl.Color{0x00, 0x00, 0x00, 0xFF},
	rl.Color{0x05, 0x05, 0x05, 0xFF},
	rl.Color{0x05, 0x05, 0x05, 0xFF},
	rl.Color{0xC7, 0xC7, 0xC7, 0xFF},
	rl.Color{0x00, 0x77, 0xFF, 0xFF},
	rl.Color{0x21, 0x55, 0xFF, 0xFF},
	rl.Color{0x82, 0x37, 0xFA, 0xFF},
	rl.Color{0xEB, 0x2F, 0xB5, 0xFF},
	rl.Color{0xFF, 0x29, 0x50, 0xFF},
	rl.Color{0xFF, 0x22, 0x00, 0xFF},
	rl.Color{0xD6, 0x32, 0x00, 0xFF},
	rl.Color{0xC4, 0x62, 0x00, 0xFF},
	rl.Color{0x35, 0x80, 0x00, 0xFF},
	rl.Color{0x05, 0x8F, 0x00, 0xFF},
	rl.Color{0x00, 0x8A, 0x55, 0xFF},
	rl.Color{0x00, 0x99, 0xCC, 0xFF},
	rl.Color{0x21, 0x21, 0x21, 0xFF},
	rl.Color{0x09, 0x09, 0x09, 0xFF},
	rl.Color{0x09, 0x09, 0x09, 0xFF},
	rl.Color{0xFF, 0xFF, 0xFF, 0xFF},
	rl.Color{0x0F, 0xD7, 0xFF, 0xFF},
	rl.Color{0x69, 0xA2, 0xFF, 0xFF},
	rl.Color{0xD4, 0x80, 0xFF, 0xFF},
	rl.Color{0xFF, 0x45, 0xF3, 0xFF},
	rl.Color{0xFF, 0x61, 0x8B, 0xFF},
	rl.Color{0xFF, 0x88, 0x33, 0xFF},
	rl.Color{0xFF, 0x9C, 0x12, 0xFF},
	rl.Color{0xFA, 0xBC, 0x20, 0xFF},
	rl.Color{0x9F, 0xE3, 0x0E, 0xFF},
	rl.Color{0x2B, 0xF0, 0x35, 0xFF},
	rl.Color{0x0C, 0xF0, 0xA4, 0xFF},
	rl.Color{0x05, 0xFB, 0xFF, 0xFF},
	rl.Color{0x5E, 0x5E, 0x5E, 0xFF},
	rl.Color{0x0D, 0x0D, 0x0D, 0xFF},
	rl.Color{0x0D, 0x0D, 0x0D, 0xFF},
	rl.Color{0xFF, 0xFF, 0xFF, 0xFF},
	rl.Color{0xA6, 0xFC, 0xFF, 0xFF},
	rl.Color{0xB3, 0xEC, 0xFF, 0xFF},
	rl.Color{0xDA, 0xAB, 0xEB, 0xFF},
	rl.Color{0xFF, 0xA8, 0xF9, 0xFF},
	rl.Color{0xFF, 0xAB, 0xB3, 0xFF},
	rl.Color{0xFF, 0xD2, 0xB0, 0xFF},
	rl.Color{0xFF, 0xEF, 0xA6, 0xFF},
	rl.Color{0xFF, 0xF7, 0x9C, 0xFF},
	rl.Color{0xD7, 0xE8, 0x95, 0xFF},
	rl.Color{0xA6, 0xED, 0xAF, 0xFF},
	rl.Color{0xA2, 0xF2, 0xDA, 0xFF},
	rl.Color{0x99, 0xFF, 0xFC, 0xFF},
	rl.Color{0xDD, 0xDD, 0xDD, 0xFF},
	rl.Color{0x11, 0x11, 0x11, 0xFF},
	rl.Color{0x11, 0x11, 0x11, 0xFF},
}

SYSTEM_PALETTE2: [64]rl.Color =  {
	rl.Color{24, 124, 124, 255},
	rl.Color{0, 0, 252, 255},
	rl.Color{0, 0, 188, 255},
	rl.Color{68, 40, 188, 255},
	rl.Color{148, 0, 132, 255},
	rl.Color{168, 0, 32, 255},
	rl.Color{168, 16, 0, 255},
	rl.Color{136, 20, 0, 255},
	rl.Color{80, 48, 0, 255},
	rl.Color{0, 120, 0, 255},
	rl.Color{0, 104, 0, 255},
	rl.Color{0, 88, 0, 255},
	rl.Color{0, 64, 88, 255},
	rl.Color{0, 0, 0, 255},
	rl.Color{0, 0, 0, 255},
	rl.Color{0, 0, 0, 255},
	rl.Color{188, 188, 188, 255},
	rl.Color{0, 120, 248, 255},
	rl.Color{0, 88, 248, 255},
	rl.Color{104, 68, 252, 255},
	rl.Color{216, 0, 204, 255},
	rl.Color{228, 0, 88, 255},
	rl.Color{248, 56, 0, 255},
	rl.Color{228, 92, 16, 255},
	rl.Color{172, 124, 0, 255},
	rl.Color{0, 184, 0, 255},
	rl.Color{0, 168, 0, 255},
	rl.Color{0, 168, 68, 255},
	rl.Color{0, 136, 136, 255},
	rl.Color{0, 0, 0, 255},
	rl.Color{0, 0, 0, 255},
	rl.Color{0, 0, 0, 255},
	rl.Color{248, 248, 248, 255},
	rl.Color{60, 188, 252, 255},
	rl.Color{104, 136, 252, 255},
	rl.Color{152, 120, 248, 255},
	rl.Color{248, 120, 248, 255},
	rl.Color{248, 88, 152, 255},
	rl.Color{248, 120, 88, 255},
	rl.Color{252, 160, 68, 255},
	rl.Color{248, 184, 0, 255},
	rl.Color{184, 248, 24, 255},
	rl.Color{88, 216, 84, 255},
	rl.Color{88, 248, 152, 255},
	rl.Color{0, 232, 216, 255},
	rl.Color{120, 120, 120, 255},
	rl.Color{0, 0, 0, 255},
	rl.Color{0, 0, 0, 255},
	rl.Color{252, 252, 252, 255},
	rl.Color{164, 228, 252, 255},
	rl.Color{184, 184, 248, 255},
	rl.Color{216, 184, 248, 255},
	rl.Color{248, 184, 248, 255},
	rl.Color{248, 164, 192, 255},
	rl.Color{240, 208, 176, 255},
	rl.Color{252, 224, 168, 255},
	rl.Color{248, 216, 120, 255},
	rl.Color{216, 248, 120, 255},
	rl.Color{184, 248, 184, 255},
	rl.Color{184, 248, 216, 255},
	rl.Color{0, 252, 252, 255},
	rl.Color{248, 216, 248, 255},
	rl.Color{0, 0, 0, 255},
	rl.Color{0, 0, 0, 255},
}
*/

rgb :: [3]u8

SYSTEM_PALETTE: [64]rgb = {
	{124, 124, 124},
	{0, 0, 252},
	{0, 0, 188},
	{68, 40, 188},
	{148, 0, 132},
	{168, 0, 32},
	{168, 16, 0},
	{136, 20, 0},
	{80, 48, 0},
	{0, 120, 0},
	{0, 104, 0},
	{0, 88, 0},
	{0, 64, 88},
	{0, 0, 0},
	{0, 0, 0},
	{0, 0, 0},
	{188, 188, 188},
	{0, 120, 248},
	{0, 88, 248},
	{104, 68, 252},
	{216, 0, 204},
	{228, 0, 88},
	{248, 56, 0},
	{228, 92, 16},
	{172, 124, 0},
	{0, 184, 0},
	{0, 168, 0},
	{0, 168, 68},
	{0, 136, 136},
	{0, 0, 0},
	{0, 0, 0},
	{0, 0, 0},
	{248, 248, 248},
	{60, 188, 252},
	{104, 136, 252},
	{152, 120, 248},
	{248, 120, 248},
	{248, 88, 152},
	{248, 120, 88},
	{252, 160, 68},
	{248, 184, 0},
	{184, 248, 24},
	{88, 216, 84},
	{88, 248, 152},
	{0, 232, 216},
	{120, 120, 120},
	{0, 0, 0},
	{0, 0, 0},
	{252, 252, 252},
	{164, 228, 252},
	{184, 184, 248},
	{216, 184, 248},
	{248, 184, 248},
	{248, 164, 192},
	{240, 208, 176},
	{252, 224, 168},
	{248, 216, 120},
	{216, 248, 120},
	{184, 248, 184},
	{184, 248, 216},
	{0, 252, 252},
	{248, 216, 248},
	{0, 0, 0},
	{0, 0, 0},
}

// Hard code in the NES resolution
FRAME_WIDTH :: 256
FRAME_HEIGHT :: 240

Frame :: struct {
	data:  [FRAME_WIDTH * FRAME_HEIGHT]rgb,
	data2: [FRAME_HEIGHT * FRAME_WIDTH * 3]u8,
	// data:  []rgb,
	// data2: []u8,
}

render_image :: proc(colors: []u8, ri: ^RenderInfo) {
	renderer := ri.renderer
	texture := ri.texture

	sdl3.RenderClear(renderer)

	pitch: i32 = FRAME_WIDTH * 3

	// LockTexture hands back the texture's own pixel memory, so there is
	// nothing to allocate here
	raw_pixels: rawptr
	succt := sdl3.LockTexture(texture, nil, &raw_pixels, &pitch)

	pixels := slice.from_ptr(cast(^u8)raw_pixels, int(pitch) * FRAME_HEIGHT)

	// copy frame.data to pixels
	for i in 0 ..< FRAME_HEIGHT {
		for j in 0 ..< FRAME_WIDTH {
			idx_orig := FRAME_WIDTH * i + j
			idx_dest := int(pitch) * i + 3 * j
			idx_palette := colors[idx_orig]
			// if i == 180 || j == 50 || j == 129 do idx_palette = 0
			// idx_palette := i % 64
			rgb_val := SYSTEM_PALETTE[idx_palette]
			pixels[idx_dest] = rgb_val[0]
			pixels[idx_dest + 1] = rgb_val[1]
			pixels[idx_dest + 2] = rgb_val[2]
		}
	}

	sdl3.UnlockTexture(texture)

	frect := sdl3.FRect{0, 0, FRAME_WIDTH, FRAME_HEIGHT}

	succc := sdl3.RenderTexture(renderer, texture, nil, &frect)

	sdl3.RenderPresent(renderer)
}

// Set the color in one pixel in the frame
set_frame_pixel :: proc(frame: ^Frame, x: int, y: int, color: rgb) {
	base := y * FRAME_WIDTH + x
	if base < (FRAME_HEIGHT * FRAME_WIDTH) {
		frame.data[base] = color
		idx := 3 * base
		frame.data2[idx] = color[0]
		frame.data2[idx + 1] = color[1]
		frame.data2[idx + 2] = color[2]
	}
}

render_frame_texture :: proc(frame: ^Frame, ri: ^RenderInfo) {
	renderer := ri.renderer
	texture := ri.texture

	sdl3.RenderClear(renderer)

	pitch: i32 = FRAME_WIDTH * 3
	// pixels: []u8

	npix :: FRAME_HEIGHT * FRAME_WIDTH * 3
	pixels := make([]u8, npix)
	// defer delete(pixels)

	succt := sdl3.LockTexture(texture, nil, auto_cast &pixels, &pitch)

	// copy frame.data to pixels
	copy(pixels, frame.data2[:])

	sdl3.UnlockTexture(texture)

	rect := sdl3.Rect{0, 0, FRAME_WIDTH, FRAME_HEIGHT}

	// succc := sdl3.RenderCopy(renderer, texture, nil, &rect)

	sdl3.RenderPresent(renderer)

	// delete(pixels)
}

/*
render_frame :: proc(frame: ^Frame, ri: ^RenderInfo) {

	renderer := ri.renderer
	texture := ri.texture

	sdl3.RenderClear(renderer)

	for x in 0 ..< FRAME_WIDTH {
		for y in 0 ..< FRAME_HEIGHT {
			pix_x: i32 = auto_cast x
			pix_y: i32 = auto_cast y
			off := y * FRAME_WIDTH + x
			color := frame.data[off]
			sdl3.SetRenderDrawColor(renderer, color[0], color[1], color[2], 255)
			sdl3.RenderDrawPoint(renderer, pix_x, pix_y)
		}
	}

	sdl3.RenderPresent(renderer)
}
*/

render_background :: proc(ppu: ^Ricoh2c02, frame: ^Frame) {
	scroll_x := int(ppu.scroll.x_scroll)
	scroll_y := int(ppu.scroll.y_scroll)

	main_nametable: []u8
	second_nametable: []u8
	// ppu.mirroring = .HORIZONTAL
	switch ppu.mirroring {
	case .HORIZONTAL:
		switch get_nametable_addr(ppu.ctrl) {
		case 0x2000, 0x2400:
			main_nametable = ppu.vram[0:0x400]
			second_nametable = ppu.vram[0x400:0x800]
		case 0x2800, 0x2C00:
			main_nametable = ppu.vram[0x400:0x800]
			second_nametable = ppu.vram[0:0x400]
		}
	// log.panic("Not supported mirroring type:", ppu.mirroring)
	case .VERTICAL:
		switch get_nametable_addr(ppu.ctrl) {
		case 0x2000, 0x2800:
			main_nametable = ppu.vram[0:0x400]
			second_nametable = ppu.vram[0x400:0x800]
		case 0x2400, 0x2C00:
			main_nametable = ppu.vram[0x400:0x800]
			second_nametable = ppu.vram[0:0x400]
		}
	case .FOUR_SCREEN, .ONE_SCREEN_LOWER, .ONE_SCREEN_UPPER:
		log.panic("Not supported mirroring type:", ppu.mirroring)
	}

	// name_table := ppu.vram[0:0x400]

	vp1 := Rect{scroll_x, scroll_y, 256, 240}
	vp2x := Rect{0, 0, scroll_x, 240}
	vp2y := Rect{0, 0, 256, scroll_y}

	render_name_table(ppu, frame, main_nametable, vp1, -scroll_x, -scroll_y)

	if scroll_x > 0 && scroll_y > 0 {
		log.panic("Don't know what to do with both scroll_x/y > 0.")
	} else if scroll_x > 0 {
		render_name_table(ppu, frame, second_nametable, vp2x, 256 - scroll_x, 0)
	} else if scroll_y > 0 {
		render_name_table(ppu, frame, second_nametable, vp2y, 0, 240 - scroll_y)
	}
}

render_name_table :: proc(
	ppu: ^Ricoh2c02,
	frame: ^Frame,
	name_table: []u8,
	view_port: Rect,
	shift_x: int,
	shift_y: int,
) {
	bank := get_background_pattern_addr(ppu.ctrl)
	attribute_table := name_table[0x3c0:0x400]

	for i in 0 ..< 0x03C0 {
		// tile_num := ppu.vram[i]
		tile_num := name_table[i]
		tile_x := i % 32
		tile_y := i / 32
		idx := bank + u16(tile_num) * 16
		tile := ppu.chr_rom[idx:idx + 16]
		// pallette := bg_pallette(ppu, tile_x, tile_y)
		pallette := bg_pallette2(ppu, attribute_table, tile_x, tile_y)

		for y in 0 ..< 8 {
			lower := tile[y]
			upper := tile[y + 8]

			for x := 7; x >= 0; x -= 1 {
				value := (1 & upper) << 1 | (1 & lower)
				upper = upper >> 1
				lower = lower >> 1

				color := SYSTEM_PALETTE[pallette[value]]
				if value == 0 do color = SYSTEM_PALETTE[ppu.palette_table[0]]

				pixel_x := tile_x * 8 + x
				pixel_y := tile_y * 8 + y
				if pixel_x >= view_port.x1 &&
				   pixel_x < view_port.x2 &&
				   pixel_y >= view_port.y1 &&
				   pixel_y < view_port.y2 {
					set_frame_pixel(frame, shift_x + pixel_x, shift_y + pixel_y, color)
					// if pixel_y == 90 && pixel_x % 8 == 0 && pixel_x > 100 && pixel_x < 150 {
					// fmt.println(pixel_y, pixel_x, tile_num)
					// fmt.printf("PPP: %04x\n", i)
					// mem_addr: u16 = 0x216E
					// tmp := read_ppu_data(ppu, mem_addr)
					// fmt.printf("ERT %04d\n", tmp)
					// tmp2 := mirror_vram_addr(mem_addr, ppu.mirroring)
					// fmt.println("MIRROR AAA", mem_addr, tmp2)
					// result := ppu.vram[tmp2]
					// fmt.println("RES: ", result)
					// }
				}
			}
		}
	}
}

render_sprites :: proc(ppu: ^Ricoh2c02, frame: ^Frame) {
	// Render the sprites
	ndata := len(ppu.oam_data)
	for i := ndata - 4; i >= 0; i -= 4 {
		tile_idx := ppu.oam_data[i + 1]
		tile_x: int = auto_cast ppu.oam_data[i + 3]
		tile_y: int = auto_cast ppu.oam_data[i]

		flip_horizontal := true if (ppu.oam_data[i + 2] >> 6) & 1 == 1 else false
		flip_vertical := true if (ppu.oam_data[i + 2] >> 7) & 1 == 1 else false

		pallette_idx := ppu.oam_data[i + 2] & 0b11
		pallette := sprite_pallette(ppu, pallette_idx)

		bank := get_sprite_pattern_addr(ppu.ctrl)

		idx := bank + u16(tile_idx) * 16
		tile := ppu.chr_rom[idx:idx + 16]

		for y in 0 ..= 7 {
			upper := tile[y]
			lower := tile[y + 8]
			for x := 7; x >= 0; x -= 1 {
				value := (1 & lower) << 1 | (1 & upper)
				upper = upper >> 1
				lower = lower >> 1

				if value == 0 do continue
				color := SYSTEM_PALETTE[pallette[value]]

				xpos := tile_x + x if !flip_horizontal else tile_x + 7 - x
				ypos := tile_y + y if !flip_vertical else tile_y + 7 - y
				set_frame_pixel(frame, xpos, ypos, color)
			}
		}
	}
}

bg_pallette :: proc(ppu: ^Ricoh2c02, column: int, row: int) -> (res: [4]u8) {

	attr_table_idx := row / 4 * 8 + column / 4
	attr_byte := ppu.vram[0x3C0 + attr_table_idx]

	idx_col, idx_row := column % 4 / 2, row % 4 / 2

	pallette_idx: int
	if idx_col == 0 && idx_row == 0 {
		pallette_idx = auto_cast (attr_byte & 0b11)
	} else if idx_col == 1 && idx_row == 0 {
		pallette_idx = auto_cast ((attr_byte >> 2) & 0b11)
	} else if idx_col == 0 && idx_row == 1 {
		pallette_idx = auto_cast ((attr_byte >> 4) & 0b11)
	} else if idx_col == 1 && idx_row == 1 {
		pallette_idx = auto_cast ((attr_byte >> 6) & 0b11)
	} else {
		log.fatal("Issue with pallette retrieval.")
	}

	pallette_start := 4 * pallette_idx + 1

	res = {
		ppu.palette_table[0],
		ppu.palette_table[pallette_start],
		ppu.palette_table[pallette_start + 1],
		ppu.palette_table[pallette_start + 2],
	}

	return
}

bg_pallette2 :: proc(ppu: ^Ricoh2c02, attr_table: []u8, column: int, row: int) -> (res: [4]u8) {

	attr_table_idx := row / 4 * 8 + column / 4
	attr_byte := attr_table[attr_table_idx]

	idx_col, idx_row := column % 4 / 2, row % 4 / 2

	pallette_idx: int
	if idx_col == 0 && idx_row == 0 {
		pallette_idx = auto_cast (attr_byte & 0b11)
	} else if idx_col == 1 && idx_row == 0 {
		pallette_idx = auto_cast ((attr_byte >> 2) & 0b11)
	} else if idx_col == 0 && idx_row == 1 {
		pallette_idx = auto_cast ((attr_byte >> 4) & 0b11)
	} else if idx_col == 1 && idx_row == 1 {
		pallette_idx = auto_cast ((attr_byte >> 6) & 0b11)
	} else {
		log.fatal("Issue with pallette retrieval.")
	}

	pallette_start := 4 * pallette_idx + 1

	res = {
		ppu.palette_table[0],
		ppu.palette_table[pallette_start],
		ppu.palette_table[pallette_start + 1],
		ppu.palette_table[pallette_start + 2],
	}

	return
}
sprite_pallette :: proc(ppu: ^Ricoh2c02, pallette_idx: u8) -> (res: [4]u8) {
	start := 4 * pallette_idx + 0x11 // first 16 are bg pallettes

	res[0] = 0
	res[1] = ppu.palette_table[start]
	res[2] = ppu.palette_table[start + 1]
	res[3] = ppu.palette_table[start + 2]

	return

}

Rect :: struct {
	x1, y1, x2, y2: int,
}
