package nes

import rl "vendor:raylib"

Buttons :: enum u8 {
	RIGHT,
	LEFT,
	DOWN,
	UP,
	START,
	SELECT,
	BUTTON_B,
	BUTTON_A,
}

JoyPad :: struct {
	strobe:        bool,
	button_index:  int,
	button_status: bit_set[Buttons],
}

ButtonOrder: []Buttons = {.BUTTON_A, .BUTTON_B, .SELECT, .START, .UP, .DOWN, .LEFT, .RIGHT}

write_joypad :: proc(jp: ^JoyPad, data: u8) {
	jp.strobe = data & 1 == 1

	if jp.strobe do jp.button_index = 0
}

read_joypad :: proc(jp: ^JoyPad) -> u8 {

	if jp.button_index > 7 do return 1

	// Always report button A if strobe is on otherwise return the
	// current button index and index will be incremented
	button := ButtonOrder[jp.button_index] if !jp.strobe else .BUTTON_A

	res: u8 = 1 if button in jp.button_status else 0

	if !jp.strobe && jp.button_index <= 7 do jp.button_index += 1

	return res
}

check_input1 :: proc(jp: ^JoyPad) {

	// Check if keys are pressed and update the structure
	if rl.IsKeyPressed(rl.KeyboardKey.UP) do jp.button_status += {.UP}
	if rl.IsKeyPressed(rl.KeyboardKey.DOWN) do jp.button_status += {.DOWN}
	if rl.IsKeyPressed(rl.KeyboardKey.LEFT) do jp.button_status += {.LEFT}
	if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) do jp.button_status += {.RIGHT}
	if rl.IsKeyPressed(rl.KeyboardKey.A) do jp.button_status += {.BUTTON_A}
	if rl.IsKeyPressed(rl.KeyboardKey.S) do jp.button_status += {.BUTTON_B}
	if rl.IsKeyPressed(rl.KeyboardKey.SPACE) do jp.button_status += {.SELECT}
	if rl.IsKeyPressed(rl.KeyboardKey.ENTER) do jp.button_status += {.START}

	// Check if keys are not pressed and update the structure
	if rl.IsKeyReleased(rl.KeyboardKey.UP) do jp.button_status -= {.UP}
	if rl.IsKeyReleased(rl.KeyboardKey.DOWN) do jp.button_status -= {.DOWN}
	if rl.IsKeyReleased(rl.KeyboardKey.LEFT) do jp.button_status -= {.LEFT}
	if rl.IsKeyReleased(rl.KeyboardKey.RIGHT) do jp.button_status -= {.RIGHT}
	if rl.IsKeyReleased(rl.KeyboardKey.A) do jp.button_status -= {.BUTTON_A}
	if rl.IsKeyReleased(rl.KeyboardKey.S) do jp.button_status -= {.BUTTON_B}
	if rl.IsKeyReleased(rl.KeyboardKey.SPACE) do jp.button_status -= {.SELECT}
	if rl.IsKeyReleased(rl.KeyboardKey.ENTER) do jp.button_status -= {.START}

}

// Just mapping joypad 1 and 2 to same inputs right now
check_input2 := check_input1
