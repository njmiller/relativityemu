package cpu

import "core:fmt"
import "core:strings"

// Can I figure out a way to not need the Bus structure??
import "hardware:memory"

//Instructions for each addressing mode

simple_instruction :: proc(text: string, unofficial: bool = false) -> int {
	fmt.printf("      ")
	if unofficial {
		fmt.printf("*")
	} else {
		fmt.printf(" ")
	}
	fmt.printf(text)
	stringblank := strings.repeat(" ", 32 - len(text))
	fmt.printf(stringblank)
	return 1
}

absolute_instruction :: proc(
	text: string,
	register: string,
	cpu: ^MOS6502,
	bus: ^memory.Bus,
	extra: bool = true,
	unofficial: bool = false,
) -> int {
	low := bus.read(bus, auto_cast cpu.pc + 1)
	high := bus.read(bus, auto_cast cpu.pc + 2)

	fmt.printf("%02X %02X ", low, high)
	if unofficial {
		fmt.printf("*")
	} else {
		fmt.printf(" ")
	}
	fmt.printf(text)

	addr := getCombined(high, low)
	fmt.printf(" $%04X", addr)


	if register == "X" {
		addr += auto_cast cpu.ix
	} else if register == "Y" {
		addr += auto_cast cpu.iy
	}

	if register == "X" || register == "Y" {
		fmt.printf(",")
		fmt.printf(register)
		fmt.printf(" @ %04X", addr)
	}

	if extra {
		//addr := getCombined(val1, val2)
		mval := bus.read(bus, auto_cast addr)
		fmt.printf(" = %02X", mval)
	}

	nblank := 32 - len(text) - 6
	if extra do nblank -= 5
	if register == "X" || register == "Y" do nblank -= 9
	blank_string := strings.repeat(" ", nblank)
	fmt.printf(blank_string)
	// fmt.printf("                  ")

	return 3
}

zero_page_instruction :: proc(
	text: string,
	register: string,
	cpu: ^MOS6502,
	bus: ^memory.Bus,
	unofficial: bool = false,
) -> int {
	value := bus.read(bus, auto_cast cpu.pc + 1)
	fmt.printf("%02X    ", value)
	if unofficial {
		fmt.printf("*")
	} else {
		fmt.printf(" ")
	}

	fmt.printf(text)
	fmt.printf(" $%02X", value)

	if register == "X" || register == "Y" {
		fmt.printf(",")
		fmt.printf(register)
	}

	// Display the extra information
	add_mode: AddressingMode
	if register == "X" {
		add_mode = .ZeroPage_X
		fmt.printf(" @ %02X", value + cpu.ix)
	} else if register == "Y" {
		add_mode = .ZeroPage_Y
		fmt.printf(" @ %02X", value + cpu.iy)
	} else {
		add_mode = .ZeroPage
	}

	cpu.pc += 1
	val2 := getValue8(cpu, bus, add_mode)
	cpu.pc -= 2
	fmt.printf(" = %02X", val2)

	nblank := 32 - len(text) - 5 - 4
	if register == "X" || register == "Y" do nblank -= 7
	blank_string := strings.repeat(" ", nblank)
	// fmt.printf("                    ")
	fmt.printf(blank_string)
	return 2
}

immediate_instruction :: proc(
	text: string,
	cpu: ^MOS6502,
	bus: ^memory.Bus,
	add_mode: AddressingMode,
	unofficial: bool = false,
) -> int {
	cpu.pc += 1
	value := bus.read(bus, auto_cast cpu.pc)
	cpu.pc -= 1

	fmt.printf("%02X    ", value)
	if unofficial {
		fmt.printf("*")
	} else {
		fmt.printf(" ")
	}
	fmt.printf(text)

	if add_mode == .Relative {
		val_signed := i8(value)
		value16: u16 = auto_cast (int(val_signed) + cpu.pc + 2)
		fmt.printf(" $%04X", value16)
		fmt.printf("                       ")
	} else {
		fmt.printf(" #$%02X", value)
		fmt.printf("                        ")
	}

	return 2
}

indirect_instruction :: proc(text: string, cpu: ^MOS6502, bus: ^memory.Bus) -> int {
	val1 := bus.read(bus, auto_cast cpu.pc + 1)
	val2 := bus.read(bus, auto_cast cpu.pc + 2)
	fmt.printf("%02X %02X  ", val1, val2)
	fmt.printf(text)

	fmt.printf(" ($%02X%02X)", val2, val1)


	addr := getCombined(val2, val1)
	mem_val_low := bus.read(bus, auto_cast addr)

	high_bits := addr & 0xFF00
	high_off := u8(addr & 0x00FF) + 1
	high_addr := high_bits | u16(high_off)
	mem_val_high := bus.read(bus, high_addr)

	fmt.printf(" = %02X%02X", mem_val_high, mem_val_low)

	nblank := 32 - len(text) - 15
	blank_string := strings.repeat(" ", nblank)
	fmt.printf(blank_string)

	return 3
}

indirect_x_instruction :: proc(text: string, cpu: ^MOS6502, bus: ^memory.Bus) -> int {
	value := bus.read(bus, auto_cast cpu.pc + 1)
	fmt.printf("%02X     ", value)
	fmt.printf(text)
	fmt.printf(" ($%02X,X)", value)

	addr := cpu.ix + bus.read(bus, auto_cast cpu.pc + 1)
	low := bus.read(bus, auto_cast addr)
	high := bus.read(bus, auto_cast (addr + 1))
	addr2 := getCombined(high, low)
	val2 := bus.read(bus, auto_cast addr2)
	fmt.printf(" @ %02X = %04X = %02X", addr, addr2, val2)
	nblank := 32 - len(text) - 25
	blank_string := strings.repeat(" ", nblank)
	fmt.printf(blank_string)

	return 2
}

indirect_y_instruction :: proc(text: string, cpu: ^MOS6502, bus: ^memory.Bus) -> int {
	value := bus.read(bus, auto_cast cpu.pc + 1)
	fmt.printf("%02X     ", value)
	fmt.printf(text)
	fmt.printf(" ($%02X),Y", value)

	low := bus.read(bus, auto_cast value)
	high := bus.read(bus, auto_cast (value + 1))
	addr0 := getCombined(high, low)
	addr := addr0 + u16(cpu.iy)
	mem_val := bus.read(bus, addr)

	fmt.printf(" = %04X @ %04X = %02X", addr0, addr, mem_val)
	nblank := 32 - len(text) - 8 - 19
	blank_string := strings.repeat(" ", nblank)
	fmt.printf(blank_string)

	return 2
}

display_registers :: proc(cpu: ^MOS6502) {
	fmt.printf("A:%02X X:%02X Y:%02X P:%02X ", cpu.a, cpu.ix, cpu.iy, cpu.status)
	fmt.printf("SP:%02X", cpu.sp)
}

display_cycles :: proc(cpu: ^MOS6502, ncycles: int) {
	fmt.printf("CYC:%i", ncycles)
}

// Try to match the output of the nestest log
disassemble6502p :: proc(cpu: ^MOS6502, bus: ^memory.Bus) -> int {
	// opcode: OpCode = auto_cast memory[pc]
	pc := cpu.pc

	opcode: OpCode = auto_cast bus.read(bus, auto_cast pc)

	// Values are ignored if opcode doesn't require it
	val1 := bus.read(bus, auto_cast pc + 1)
	val2 := bus.read(bus, auto_cast pc + 2)

	fmt.printf("%04X  ", pc)
	fmt.printf("%02X ", u8(opcode))

	switch opcode {
	case .BRK:
		// return simpleInstruction("BRK")
		return simple_instruction("BRK")
	case .ADC_IM:
		//return immediateInstruction("ADC", val1)
		return immediate_instruction("ADC", cpu, bus, AddressingMode.Immediate)
	case .ADC_ZP:
		// return zeroPageInstruction("ADC", "", val1)
		return zero_page_instruction("ADC", "", cpu, bus)
	case .ADC_ZPX:
		// return zeroPageInstruction("ADC", "X", val1)
		return zero_page_instruction("ADC", "X", cpu, bus)
	case .ADC_A:
		// return absoluteInstruction("ADC", "", val2, val1)
		return absolute_instruction("ADC", "", cpu, bus)
	case .ADC_AX:
		// return absoluteInstruction("ADC", "X", val2, val1)
		return absolute_instruction("ADC", "X", cpu, bus)
	case .ADC_AY:
		// return absoluteInstruction("ADC", "Y", val2, val1)
		return absolute_instruction("ADC", "Y", cpu, bus)
	case .ADC_IX:
		// return indirectXInstruction("ADC", val1)
		return indirect_x_instruction("ADC", cpu, bus)
	case .ADC_IY:
		// return indirectYInstruction("ADC", val1)
		return indirect_y_instruction("ADC", cpu, bus)
	case .AND_IM:
		// return immediateInstruction("AND", val1)
		return immediate_instruction("AND", cpu, bus, AddressingMode.Immediate)
	case .AND_ZP:
		// return zeroPageInstruction("AND", "", val1)
		return zero_page_instruction("AND", "", cpu, bus)
	case .AND_ZPX:
		// return zeroPageInstruction("AND", "X", val1)
		return zero_page_instruction("AND", "X", cpu, bus)
	case .AND_A:
		// return absoluteInstruction("AND", "", val2, val1)
		return absolute_instruction("AND", "", cpu, bus)
	case .AND_AX:
		// return absoluteInstruction("AND", "X", val2, val1)
		return absolute_instruction("AND", "X", cpu, bus)
	case .AND_AY:
		// return absoluteInstruction("AND", "Y", val2, val1)
		return absolute_instruction("AND", "Y", cpu, bus)
	case .AND_IX:
		// return indirectXInstruction("AND", val1)
		return indirect_x_instruction("AND", cpu, bus)
	case .AND_IY:
		// return indirectYInstruction("AND", val1)
		return indirect_y_instruction("AND", cpu, bus)
	case .ASL_ACC:
		// return simpleInstruction("ASL A")
		return simple_instruction("ASL A")
	case .ASL_ZP:
		// return zeroPageInstruction("ASL", "", val1)
		return zero_page_instruction("ASL", "", cpu, bus)
	case .ASL_ZPX:
		// return zeroPageInstruction("ASL", "X", val1)
		return zero_page_instruction("ASL", "X", cpu, bus)
	case .ASL_A:
		// return absoluteInstruction("ASL", "", val2, val1)
		return absolute_instruction("ASL", "", cpu, bus)
	case .ASL_AX:
		// return absoluteInstruction("ASL", "X", val2, val1)
		return absolute_instruction("ASL", "X", cpu, bus)
	case .BCC:
		// return immediateInstruction("BCC", val1)
		return immediate_instruction("BCC", cpu, bus, AddressingMode.Relative)
	case .BCS:
		//val1 = auto_cast (int(val1) + cpu.pc + 2)
		//return immediateInstruction("BCS", val1)
		return immediate_instruction("BCS", cpu, bus, AddressingMode.Relative)
	case .BEQ:
		// return immediateInstruction("BEQ", val1)
		return immediate_instruction("BEQ", cpu, bus, AddressingMode.Relative)
	case .BIT_A:
		// return absoluteInstruction("BIT", "", val2, val1)
		return absolute_instruction("BIT", "", cpu, bus)
	case .BIT_ZP:
		// return zeroPageInstruction("BIT", "", val1)
		return zero_page_instruction("BIT", "", cpu, bus)
	case .BMI:
		// return immediateInstruction("BMI", val1)
		return immediate_instruction("BMI", cpu, bus, AddressingMode.Relative)
	case .BNE:
		// return immediateInstruction("BNE", val1)
		return immediate_instruction("BNE", cpu, bus, AddressingMode.Relative)
	case .BPL:
		// return immediateInstruction("BPL", val1)
		return immediate_instruction("BPL", cpu, bus, AddressingMode.Relative)
	case .BVC:
		// return immediateInstruction("BVC", val1)
		return immediate_instruction("BVC", cpu, bus, AddressingMode.Relative)
	case .BVS:
		// return immediateInstruction("BVS", val1)
		return immediate_instruction("BVS", cpu, bus, AddressingMode.Relative)
	case .CLC:
		// return simpleInstruction("CLC")
		return simple_instruction("CLC")
	case .CLD:
		// return simpleInstruction("CLD")
		return simple_instruction("CLD")
	case .CLI:
		// return simpleInstruction("CLI")
		return simple_instruction("CLI")
	case .CLV:
		// return simpleInstruction("CLV")
		return simple_instruction("CLV")
	case .CMP_IM:
		// return immediateInstruction("CMP", val1)
		return immediate_instruction("CMP", cpu, bus, AddressingMode.Immediate)
	case .CMP_ZP:
		// return zeroPageInstruction("CMP", "", val1)
		return zero_page_instruction("CMP", "", cpu, bus)
	case .CMP_ZPX:
		// return zeroPageInstruction("CMP", "X", val1)
		return zero_page_instruction("CMP", "X", cpu, bus)
	case .CMP_A:
		// return absoluteInstruction("CMP", "", val2, val1)
		return absolute_instruction("CMP", "", cpu, bus)
	case .CMP_AX:
		// return absoluteInstruction("CMP", "X", val2, val1)
		return absolute_instruction("CMP", "X", cpu, bus)
	case .CMP_AY:
		// return absoluteInstruction("CMP", "Y", val2, val1)
		return absolute_instruction("CMP", "Y", cpu, bus)
	case .CMP_IX:
		// return indirectXInstruction("CMP", val1)
		return indirect_x_instruction("CMP", cpu, bus)
	case .CMP_IY:
		// return indirectYInstruction("CMP", val1)
		return indirect_y_instruction("CMP", cpu, bus)
	case .CPX_IM:
		// return immediateInstruction("CPX", val1)
		return immediate_instruction("CPX", cpu, bus, AddressingMode.Immediate)
	case .CPX_ZP:
		// return zeroPageInstruction("CPX", "", val1)
		return zero_page_instruction("CPX", "", cpu, bus)
	case .CPX_A:
		// return absoluteInstruction("CPX", "", val2, val1)
		return absolute_instruction("CPX", "", cpu, bus)
	case .CPY_IM:
		// return immediateInstruction("CPY", val1)
		return immediate_instruction("CPY", cpu, bus, AddressingMode.Immediate)
	case .CPY_ZP:
		// return zeroPageInstruction("CPY", "", val1)
		return zero_page_instruction("CPY", "", cpu, bus)
	case .CPY_A:
		// return absoluteInstruction("CPY", "", val2, val1)
		return absolute_instruction("CPY", "", cpu, bus)
	case .DEC_ZP:
		// return zeroPageInstruction("DEC", "", val1)
		return zero_page_instruction("DEC", "", cpu, bus)
	case .DEC_ZPX:
		// return zeroPageInstruction("DEC", "X", val1)
		return zero_page_instruction("DEC", "X", cpu, bus)
	case .DEC_A:
		// return absoluteInstruction("DEC", "", val2, val1)
		return absolute_instruction("DEC", "", cpu, bus)
	case .DEC_AX:
		// return absoluteInstruction("DEC", "X", val2, val1)
		return absolute_instruction("DEC", "X", cpu, bus)
	case .DEX:
		// return simpleInstruction("DEX")
		return simple_instruction("DEX")
	case .DEY:
		// return simpleInstruction("DEY")
		return simple_instruction("DEY")
	case .EOR_IM:
		// return immediateInstruction("EOR", val1)
		return immediate_instruction("EOR", cpu, bus, AddressingMode.Immediate)
	case .EOR_ZP:
		// return zeroPageInstruction("EOR", "", val1)
		return zero_page_instruction("EOR", "", cpu, bus)
	case .EOR_ZPX:
		// return zeroPageInstruction("EOR", "X", val1)
		return zero_page_instruction("EOR", "X", cpu, bus)
	case .EOR_A:
		// return absoluteInstruction("EOR", "", val2, val1)
		return absolute_instruction("EOR", "", cpu, bus)
	case .EOR_AX:
		// return absoluteInstruction("EOR", "X", val2, val1)
		return absolute_instruction("EOR", "X", cpu, bus)
	case .EOR_AY:
		// return absoluteInstruction("EOR", "Y", val2, val1)
		return absolute_instruction("EOR", "Y", cpu, bus)
	case .EOR_IX:
		// return indirectXInstruction("EOR", val1)
		return indirect_x_instruction("EOR", cpu, bus)
	case .EOR_IY:
		// return indirectYInstruction("EOR", val1)
		return indirect_y_instruction("EOR", cpu, bus)
	case .INC_ZP:
		// return zeroPageInstruction("INC", "", val1)
		return zero_page_instruction("INC", "", cpu, bus)
	case .INC_ZPX:
		// return zeroPageInstruction("INC", "X", val1)
		return zero_page_instruction("INC", "X", cpu, bus)
	case .INC_A:
		// return absoluteInstruction("INC", "", val2, val1)
		return absolute_instruction("INC", "", cpu, bus)
	case .INC_AX:
		// return absoluteInstruction("INC", "X", val2, val1)
		return absolute_instruction("INC", "X", cpu, bus)
	case .INX:
		// return simpleInstruction("INX")
		return simple_instruction("INX")
	case .INY:
		// return simpleInstruction("INY")
		return simple_instruction("INY")
	case .JMP_A:
		// return absoluteInstruction("JMP", "", val2, val1)
		return absolute_instruction("JMP", "", cpu, bus, false)
	case .JMP_I:
		// return indirectInstruction("JMP", val2, val1)
		return indirect_instruction("JMP", cpu, bus)
	case .JSR:
		// return absoluteInstruction("JSR", "", val2, val1)
		return absolute_instruction("JSR", "", cpu, bus, false)
	case .LDA_IM:
		// return immediateInstruction("LDA", val1)
		return immediate_instruction("LDA", cpu, bus, AddressingMode.Immediate)
	case .LDA_ZP:
		// return zeroPageInstruction("LDA", "", val1)
		return zero_page_instruction("LDA", "", cpu, bus)
	case .LDA_ZPX:
		// return zeroPageInstruction("LDA", "X", val1)
		return zero_page_instruction("LDA", "X", cpu, bus)
	case .LDA_A:
		// return absoluteInstruction("LDA", "", val2, val1)
		return absolute_instruction("LDA", "", cpu, bus)
	case .LDA_AX:
		// return absoluteInstruction("LDA", "X", val2, val1)
		return absolute_instruction("LDA", "X", cpu, bus)
	case .LDA_AY:
		// return absoluteInstruction("LDA", "Y", val2, val1)
		return absolute_instruction("LDA", "Y", cpu, bus)
	case .LDA_IX:
		// return indirectXInstruction("LDA", val1)
		return indirect_x_instruction("LDA", cpu, bus)
	case .LDA_IY:
		// return indirectYInstruction("LDA", val1)
		return indirect_y_instruction("LDA", cpu, bus)
	case .LDX_IM:
		// return immediateInstruction("LDX", val1)
		return immediate_instruction("LDX", cpu, bus, AddressingMode.Immediate)
	case .LDX_ZP:
		// return zeroPageInstruction("LDX", "", val1)
		return zero_page_instruction("LDX", "", cpu, bus)
	case .LDX_ZPY:
		// return zeroPageInstruction("LDX", "Y", val1)
		return zero_page_instruction("LDX", "Y", cpu, bus)
	case .LDX_A:
		// return absoluteInstruction("LDX", "", val2, val1)
		return absolute_instruction("LDX", "", cpu, bus)
	case .LDX_AY:
		// return absoluteInstruction("LDX", "Y", val2, val1)
		return absolute_instruction("LDX", "Y", cpu, bus)
	case .LDY_IM:
		// return immediateInstruction("LDY", val1)
		return immediate_instruction("LDY", cpu, bus, AddressingMode.Immediate)
	case .LDY_ZP:
		// return zeroPageInstruction("LDY", "", val1)
		return zero_page_instruction("LDY", "", cpu, bus)
	case .LDY_ZPX:
		// return zeroPageInstruction("LDY", "X", val1)
		return zero_page_instruction("LDY", "X", cpu, bus)
	case .LDY_A:
		// return absoluteInstruction("LDY", "", val2, val1)
		return absolute_instruction("LDY", "", cpu, bus)
	case .LDY_AX:
		// return absoluteInstruction("LDY", "X", val2, val1)
		return absolute_instruction("LDY", "X", cpu, bus)
	case .LSR_ACC:
		// return simpleInstruction("LSR A")
		return simple_instruction("LSR A")
	case .LSR_ZP:
		// return zeroPageInstruction("LSR", "", val1)
		return zero_page_instruction("LSR", "", cpu, bus)
	case .LSR_ZPX:
		// return zeroPageInstruction("LSR", "X", val1)
		return zero_page_instruction("LSR", "X", cpu, bus)
	case .LSR_A:
		// return absoluteInstruction("LSR", "", val2, val1)
		return absolute_instruction("LSR", "", cpu, bus)
	case .LSR_AX:
		// return absoluteInstruction("LSR", "X", val2, val1)
		return absolute_instruction("LSR", "X", cpu, bus)
	case .NOP:
		// return simpleInstruction("NOP")
		return simple_instruction("NOP")
	case .NOP_U1, .NOP_U2, .NOP_U3, .NOP_U4, .NOP_U5, .NOP_U6:
		return simple_instruction("NOP", true)
	case .NOP_A:
		return absolute_instruction("NOP", "", cpu, bus, unofficial = true)
	case .NOP_AX, .NOP_AX2, .NOP_AX3, .NOP_AX4, .NOP_AX5, .NOP_AX6:
		return absolute_instruction("NOP", "X", cpu, bus, unofficial = true)
	case .NOP_ZP, .NOP_ZP2, .NOP_ZP3:
		return zero_page_instruction("NOP", "", cpu, bus, true)
	case .NOP_ZPX, .NOP_ZPX2, .NOP_ZPX3, .NOP_ZPX4, .NOP_ZPX5, .NOP_ZPX6:
		return zero_page_instruction("NOP", "X", cpu, bus, true)
	case .NOP_I, .NOP_I2, .NOP_I3, .NOP_I4, .NOP_I5:
		return immediate_instruction("NOP", cpu, bus, AddressingMode.Immediate, true)
	case .ORA_IM:
		// return immediateInstruction("ORA", val1)
		return immediate_instruction("ORA", cpu, bus, AddressingMode.Immediate)
	case .ORA_ZP:
		// return zeroPageInstruction("ORA", "", val1)
		return zero_page_instruction("ORA", "", cpu, bus)
	case .ORA_ZPX:
		// return zeroPageInstruction("ORA", "X", val1)
		return zero_page_instruction("ORA", "X", cpu, bus)
	case .ORA_A:
		// return absoluteInstruction("ORA", "", val2, val1)
		return absolute_instruction("ORA", "", cpu, bus)
	case .ORA_AX:
		// return absoluteInstruction("ORA", "X", val2, val1)
		return absolute_instruction("ORA", "X", cpu, bus)
	case .ORA_AY:
		// return absoluteInstruction("ORA", "Y", val2, val1)
		return absolute_instruction("ORA", "Y", cpu, bus)
	case .ORA_IX:
		// return indirectXInstruction("ORA", val1)
		return indirect_x_instruction("ORA", cpu, bus)
	case .ORA_IY:
		// return indirectYInstruction("ORA", val1)
		return indirect_y_instruction("ORA", cpu, bus)
	case .PHA:
		// return simpleInstruction("PHA")
		return simple_instruction("PHA")
	case .PHP:
		// return simpleInstruction("PHP")
		return simple_instruction("PHP")
	case .PLA:
		// return simpleInstruction("PLA")
		return simple_instruction("PLA")
	case .PLP:
		// return simpleInstruction("PLP")
		return simple_instruction("PLP")
	case .ROL_ACC:
		// return simpleInstruction("ROL A")
		return simple_instruction("ROL A")
	case .ROL_ZP:
		// return zeroPageInstruction("ROL", "", val1)
		return zero_page_instruction("ROL", "", cpu, bus)
	case .ROL_ZPX:
		// return zeroPageInstruction("ROL", "X", val1)
		return zero_page_instruction("ROL", "X", cpu, bus)
	case .ROL_A:
		// return absoluteInstruction("ROL", "", val2, val1)
		return absolute_instruction("ROL", "", cpu, bus)
	case .ROL_AX:
		// return absoluteInstruction("ROL", "X", val2, val1)
		return absolute_instruction("ROL", "X", cpu, bus)
	case .ROR_ACC:
		// return simpleInstruction("ROR A")
		return simple_instruction("ROR A")
	case .ROR_ZP:
		// return zeroPageInstruction("ROR", "", val1)
		return zero_page_instruction("ROR", "", cpu, bus)
	case .ROR_ZPX:
		// return zeroPageInstruction("ROR", "X", val1)
		return zero_page_instruction("ROR", "X", cpu, bus)
	case .ROR_A:
		// return absoluteInstruction("ROR", "", val2, val1)
		return absolute_instruction("ROR", "", cpu, bus)
	case .ROR_AX:
		// return absoluteInstruction("ROR", "X", val2, val1)
		return absolute_instruction("ROR", "X", cpu, bus)
	case .RTI:
		// return simpleInstruction("RTI")
		return simple_instruction("RTI")
	case .RTS:
		// return simpleInstruction("RTS")
		return simple_instruction("RTS")
	case .SBC_IM:
		// return immediateInstruction("SBC", val1)
		return immediate_instruction("SBC", cpu, bus, AddressingMode.Immediate)
	case .SBC_ZP:
		// return zeroPageInstruction("SBC", "", val1)
		return zero_page_instruction("SBC", "", cpu, bus)
	case .SBC_ZPX:
		// return zeroPageInstruction("SBC", "X", val1)
		return zero_page_instruction("SBC", "X", cpu, bus)
	case .SBC_A:
		// return absoluteInstruction("SBC", "", val2, val1)
		return absolute_instruction("SBC", "", cpu, bus)
	case .SBC_AX:
		// return absoluteInstruction("SBC", "X", val2, val1)
		return absolute_instruction("SBC", "X", cpu, bus)
	case .SBC_AY:
		// return absoluteInstruction("SBC", "Y", val2, val1)
		return absolute_instruction("SBC", "Y", cpu, bus)
	case .SBC_IX:
		// return indirectXInstruction("SBC", val1)
		return indirect_x_instruction("SBC", cpu, bus)
	case .SBC_IY:
		// return indirectYInstruction("SBC", val1)
		return indirect_y_instruction("SBC", cpu, bus)
	case .SEC:
		// return simpleInstruction("SEC")
		return simple_instruction("SEC")
	case .SED:
		// return simpleInstruction("SED")
		return simple_instruction("SED")
	case .SEI:
		// return simpleInstruction("SEI")
		return simple_instruction("SEI")
	case .STA_ZP:
		// return zeroPageInstruction("STA", "", val1)
		return zero_page_instruction("STA", "", cpu, bus)
	case .STA_ZPX:
		// return zeroPageInstruction("STA", "X", val1)
		return zero_page_instruction("STA", "X", cpu, bus)
	case .STA_A:
		// return absoluteInstruction("STA", "", val2, val1)
		return absolute_instruction("STA", "", cpu, bus)
	case .STA_AX:
		// return absoluteInstruction("STA", "X", val2, val1)
		return absolute_instruction("STA", "X", cpu, bus)
	case .STA_AY:
		// return absoluteInstruction("STA", "Y", val2, val1)
		return absolute_instruction("STA", "Y", cpu, bus)
	case .STA_IX:
		// return indirectXInstruction("STA", val1)
		return indirect_x_instruction("STA", cpu, bus)
	case .STA_IY:
		// return indirectYInstruction("STA", val1)
		return indirect_y_instruction("STA", cpu, bus)
	case .STX_ZP:
		//return zeroPageInstruction("STX", "", val1)
		return zero_page_instruction("STX", "", cpu, bus)
	case .STX_ZPY:
		// return zeroPageInstruction("STX", "Y", val1)
		return zero_page_instruction("STX", "Y", cpu, bus)
	case .STX_A:
		// return absoluteInstruction("STX", "", val2, val1)
		return absolute_instruction("STX", "", cpu, bus)
	case .STY_ZP:
		// return zeroPageInstruction("STY", "", val1)
		return zero_page_instruction("STY", "", cpu, bus)
	case .STY_ZPX:
		// return zeroPageInstruction("STY", "X", val1)
		return zero_page_instruction("STY", "X", cpu, bus)
	case .STY_A:
		// return absoluteInstruction("STY", "", val2, val1)
		return absolute_instruction("STY", "", cpu, bus)
	case .TAX:
		// return simpleInstruction("TAX")
		return simple_instruction("TAX")
	case .TAY:
		// return simpleInstruction("TAY")
		return simple_instruction("TAY")
	case .TSX:
		// return simpleInstruction("TSX")
		return simple_instruction("TSX")
	case .TXA:
		// return simpleInstruction("TXA")
		return simple_instruction("TXA")
	case .TXS:
		// return simpleInstruction("TXS")
		return simple_instruction("TXS")
	case .TYA:
		// return simpleInstruction("TYA")
		return simple_instruction("TYA")
	}

	return 0
}
