package cpu

import "core:fmt"

// Can I figure out a way to not need the Bus structure??
import "hardware:memory"

//Instructions for each addressing mode
simpleInstruction :: proc(text: string) -> int {
	fmt.printf("       ")
	fmt.printf(text)
	fmt.printf("                             ")
	// fmt.printf("\n")
	return 1
}

simple_instruction :: proc(text: string) -> int {
	fmt.printf("       ")
	fmt.printf(text)
	fmt.printf("                             ")
	return 1
}

absoluteInstruction :: proc(text: string, register: string, val1: u8, val2: u8) -> int {
	fmt.printf("%02X %02X  ", val2, val1)
	fmt.printf(text)
	fmt.printf(" $%02X%02X", val1, val2)
	fmt.printf("                       ")

	if register == "X" || register == "Y" {
		fmt.printf(",")
		fmt.printf(register)
	}
	// fmt.printf("\n")
	return 3
}

absolute_instruction :: proc(
	text: string,
	register: string,
	cpu: ^MOS6502,
	bus: ^memory.Bus,
) -> int {
	val2 := bus.read(bus, auto_cast cpu.pc + 1)
	val1 := bus.read(bus, auto_cast cpu.pc + 2)

	fmt.printf("%02X %02X  ", val2, val1)
	fmt.printf(text)
	fmt.printf(" $%02X%02X", val1, val2)


	if register == "X" || register == "Y" {
		fmt.printf(",")
		fmt.printf(register)
	}

	addr := getCombined(val1, val2)
	mval := bus.read(bus, auto_cast addr)
	fmt.printf(" = %02X", mval)
	fmt.printf("                  ")

	return 3
}
zeroPageInstruction :: proc(text: string, register: string, value: u8) -> int {
	fmt.printf("%02X     ", value)
	fmt.printf(text)
	fmt.printf(" $%02X", value)

	if register == "X" || register == "Y" {
		fmt.printf(",")
		fmt.printf(register)
	}

	fmt.printf("   ABC    ")
	// fmt.printf("\n")
	return 2
}

zero_page_instruction :: proc(
	text: string,
	register: string,
	cpu: ^MOS6502,
	bus: ^memory.Bus,
) -> int {
	value := bus.read(bus, auto_cast cpu.pc + 1)
	fmt.printf("%02X     ", value)
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
	} else if register == "Y" {
		add_mode = .ZeroPage_Y
	} else {
		add_mode = .ZeroPage
	}

	cpu.pc += 1
	val2 := getValue8(cpu, bus, add_mode)
	cpu.pc -= 2
	fmt.printf(" = %02X", val2)
	fmt.printf("                    ")
	return 2
}

immediateInstruction :: proc(text: string, value: u8) -> int {
	fmt.printf("%02X     ", value)
	fmt.printf(text)
	fmt.printf(" #$%02X", value)
	fmt.printf("                        ")
	// fmt.printf("\n")
	return 2
}

immediate_instruction :: proc(
	text: string,
	cpu: ^MOS6502,
	bus: ^memory.Bus,
	add_mode: AddressingMode,
) -> int {
	cpu.pc += 1
	value := bus.read(bus, auto_cast cpu.pc)
	cpu.pc -= 1

	fmt.printf("%02X     ", value)
	fmt.printf(text)

	if add_mode == .Relative {
		value16: u16 = auto_cast (int(value) + cpu.pc + 2)
		fmt.printf(" $%04X", value16)
		fmt.printf("                       ")
	} else {
		fmt.printf(" #$%02X", value)
		fmt.printf("                        ")
	}
	// fmt.printf("\n")
	return 2
}

indirectInstruction :: proc(text: string, val1: u8, val2: u8) -> int {
	fmt.printf("%02X %02X  ", val2, val1)
	fmt.printf(text)
	fmt.printf(" (")
	fmt.printf("$%02X%02X", val2, val1)
	// fmt.printf(")\n")
	fmt.printf(")")
	return 3
}

indirectXInstruction :: proc(text: string, value: u8) -> int {
	fmt.printf("%02X     ", value)
	fmt.printf(text)
	fmt.printf(" (,$%02X,X)", value)
	// fmt.printf("\n")
	return 2
}

indirectYInstruction :: proc(text: string, value: u8) -> int {
	fmt.printf("%02X     ", value)
	fmt.printf(text)
	fmt.printf(" ($%02X),Y")
	// fmt.printf("\n")
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

	fmt.printf("%02X  ", pc)
	fmt.printf("%02X ", u8(opcode))

	switch opcode {
	case .BRK:
		return simpleInstruction("BRK")
	case .ADC_IM:
		return immediateInstruction("ADC", val1)
	case .ADC_ZP:
		return zeroPageInstruction("ADC", "", val1)
	case .ADC_ZPX:
		return zeroPageInstruction("ADC", "X", val1)
	case .ADC_A:
		return absoluteInstruction("ADC", "", val2, val1)
	case .ADC_AX:
		return absoluteInstruction("ADC", "X", val2, val1)
	case .ADC_AY:
		return absoluteInstruction("ADC", "Y", val2, val1)
	case .ADC_IX:
		return indirectXInstruction("ADC", val1)
	case .ADC_IY:
		return indirectYInstruction("ADC", val1)
	case .AND_IM:
		return immediateInstruction("AND", val1)
	case .AND_ZP:
		return zeroPageInstruction("AND", "", val1)
	case .AND_ZPX:
		return zeroPageInstruction("AND", "X", val1)
	case .AND_A:
		return absoluteInstruction("AND", "", val2, val1)
	case .AND_AX:
		return absoluteInstruction("AND", "X", val2, val1)
	case .AND_AY:
		return absoluteInstruction("AND", "Y", val2, val1)
	case .AND_IX:
		return indirectXInstruction("AND", val1)
	case .AND_IY:
		return indirectYInstruction("AND", val1)
	case .ASL_ACC:
		return simpleInstruction("ASL A")
	case .ASL_ZP:
		return zeroPageInstruction("ASL", "", val1)
	case .ASL_ZPX:
		return zeroPageInstruction("ASL", "X", val1)
	case .ASL_A:
		return absoluteInstruction("ASL", "", val2, val1)
	case .ASL_AX:
		return absoluteInstruction("ASL", "X", val2, val1)
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
		return absoluteInstruction("BIT", "", val2, val1)
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
		return simpleInstruction("CLC")
	case .CLD:
		return simpleInstruction("CLD")
	case .CLI:
		return simpleInstruction("CLI")
	case .CLV:
		return simpleInstruction("CLV")
	case .CMP_IM:
		return immediateInstruction("CMP", val1)
	case .CMP_ZP:
		return zeroPageInstruction("CMP", "", val1)
	case .CMP_ZPX:
		return zeroPageInstruction("CMP", "X", val1)
	case .CMP_A:
		return absoluteInstruction("CMP", "", val2, val1)
	case .CMP_AX:
		return absoluteInstruction("CMP", "X", val2, val1)
	case .CMP_AY:
		return absoluteInstruction("CMP", "Y", val2, val1)
	case .CMP_IX:
		return indirectXInstruction("CMP", val1)
	case .CMP_IY:
		return indirectYInstruction("CMP", val1)
	case .CPX_IM:
		return immediateInstruction("CPX", val1)
	case .CPX_ZP:
		return zeroPageInstruction("CPX", "", val1)
	case .CPX_A:
		return absoluteInstruction("CPX", "", val2, val1)
	case .CPY_IM:
		return immediateInstruction("CPY", val1)
	case .CPY_ZP:
		return zeroPageInstruction("CPY", "", val1)
	case .CPY_A:
		return absoluteInstruction("CPY", "", val2, val1)
	case .DEC_ZP:
		return zeroPageInstruction("DEC", "", val1)
	case .DEC_ZPX:
		return zeroPageInstruction("DEC", "X", val1)
	case .DEC_A:
		return absoluteInstruction("DEC", "", val2, val1)
	case .DEC_AX:
		return absoluteInstruction("DEC", "X", val2, val1)
	case .DEX:
		return simpleInstruction("DEX")
	case .DEY:
		return simpleInstruction("DEY")
	case .EOR_IM:
		return immediateInstruction("EOR", val1)
	case .EOR_ZP:
		return zeroPageInstruction("EOR", "", val1)
	case .EOR_ZPX:
		return zeroPageInstruction("EOR", "X", val1)
	case .EOR_A:
		return absoluteInstruction("EOR", "", val2, val1)
	case .EOR_AX:
		return absoluteInstruction("EOR", "X", val2, val1)
	case .EOR_AY:
		return absoluteInstruction("EOR", "Y", val2, val1)
	case .EOR_IX:
		return indirectXInstruction("EOR", val1)
	case .EOR_IY:
		return indirectYInstruction("EOR", val1)
	case .INC_ZP:
		return zeroPageInstruction("INC", "", val1)
	case .INC_ZPX:
		return zeroPageInstruction("INC", "X", val1)
	case .INC_A:
		return absoluteInstruction("INC", "", val2, val1)
	case .INC_AX:
		return absoluteInstruction("INC", "X", val2, val1)
	case .INX:
		return simpleInstruction("INX")
	case .INY:
		return simpleInstruction("INY")
	case .JMP_A:
		return absoluteInstruction("JMP", "", val2, val1)
	case .JMP_I:
		return indirectInstruction("JMP", val2, val1)
	case .JSR:
		return absoluteInstruction("JSR", "", val2, val1)
	case .LDA_IM:
		return immediateInstruction("LDA", val1)
	case .LDA_ZP:
		return zeroPageInstruction("LDA", "", val1)
	case .LDA_ZPX:
		return zeroPageInstruction("LDA", "X", val1)
	case .LDA_A:
		return absoluteInstruction("LDA", "", val2, val1)
	case .LDA_AX:
		return absoluteInstruction("LDA", "X", val2, val1)
	case .LDA_AY:
		return absoluteInstruction("LDA", "Y", val2, val1)
	case .LDA_IX:
		return indirectXInstruction("LDA", val1)
	case .LDA_IY:
		return indirectYInstruction("LDA", val1)
	case .LDX_IM:
		return immediateInstruction("LDX", val1)
	case .LDX_ZP:
		return zeroPageInstruction("LDX", "", val1)
	case .LDX_ZPY:
		return zeroPageInstruction("LDX", "Y", val1)
	case .LDX_A:
		return absoluteInstruction("LDX", "", val2, val1)
	case .LDX_AY:
		return absoluteInstruction("LDX", "Y", val2, val1)
	case .LDY_IM:
		return immediateInstruction("LDY", val1)
	case .LDY_ZP:
		return zeroPageInstruction("LDY", "", val1)
	case .LDY_ZPX:
		return zeroPageInstruction("LDY", "X", val1)
	case .LDY_A:
		return absoluteInstruction("LDY", "", val2, val1)
	case .LDY_AX:
		return absoluteInstruction("LDY", "X", val2, val1)
	case .LSR_ACC:
		return simpleInstruction("LSR A")
	case .LSR_ZP:
		return zeroPageInstruction("LSR", "", val1)
	case .LSR_ZPX:
		return zeroPageInstruction("LSR", "X", val1)
	case .LSR_A:
		return absoluteInstruction("LSR", "", val2, val1)
	case .LSR_AX:
		return absoluteInstruction("LSR", "X", val2, val1)
	case .NOP:
		return simpleInstruction("NOP")
	case .ORA_IM:
		return immediateInstruction("ORA", val1)
	case .ORA_ZP:
		return zeroPageInstruction("ORA", "", val1)
	case .ORA_ZPX:
		return zeroPageInstruction("ORA", "X", val1)
	case .ORA_A:
		return absoluteInstruction("ORA", "", val2, val1)
	case .ORA_AX:
		return absoluteInstruction("ORA", "X", val2, val1)
	case .ORA_AY:
		return absoluteInstruction("ORA", "Y", val2, val1)
	case .ORA_IX:
		return indirectXInstruction("ORA", val1)
	case .ORA_IY:
		return indirectYInstruction("ORA", val1)
	case .PHA:
		return simpleInstruction("PHA")
	case .PHP:
		return simpleInstruction("PHP")
	case .PLA:
		return simpleInstruction("PLA")
	case .PLP:
		return simpleInstruction("PLP")
	case .ROL_ACC:
		return simpleInstruction("ROL A")
	case .ROL_ZP:
		return zeroPageInstruction("ROL", "", val1)
	case .ROL_ZPX:
		return zeroPageInstruction("ROL", "X", val1)
	case .ROL_A:
		return absoluteInstruction("ROL", "", val2, val1)
	case .ROL_AX:
		return absoluteInstruction("ROL", "X", val2, val1)
	case .ROR_ACC:
		return simpleInstruction("ROR A")
	case .ROR_ZP:
		return zeroPageInstruction("ROR", "", val1)
	case .ROR_ZPX:
		return zeroPageInstruction("ROR", "X", val1)
	case .ROR_A:
		return absoluteInstruction("ROR", "", val2, val1)
	case .ROR_AX:
		return absoluteInstruction("ROR", "X", val2, val1)
	case .RTI:
		return simpleInstruction("RTI")
	case .RTS:
		return simpleInstruction("RTS")
	case .SBC_IM:
		return immediateInstruction("SBC", val1)
	case .SBC_ZP:
		return zeroPageInstruction("SBC", "", val1)
	case .SBC_ZPX:
		return zeroPageInstruction("SBC", "X", val1)
	case .SBC_A:
		return absoluteInstruction("SBC", "", val2, val1)
	case .SBC_AX:
		return absoluteInstruction("SBC", "X", val2, val1)
	case .SBC_AY:
		return absoluteInstruction("SBC", "Y", val2, val1)
	case .SBC_IX:
		return indirectXInstruction("SBC", val1)
	case .SBC_IY:
		return indirectYInstruction("SBC", val1)
	case .SEC:
		return simpleInstruction("SEC")
	case .SED:
		return simpleInstruction("SED")
	case .SEI:
		return simpleInstruction("SEI")
	case .STA_ZP:
		// return zeroPageInstruction("STA", "", val1)
		return zero_page_instruction("STA", "", cpu, bus)
	case .STA_ZPX:
		return zeroPageInstruction("STA", "X", val1)
	case .STA_A:
		return absoluteInstruction("STA", "", val2, val1)
	case .STA_AX:
		return absoluteInstruction("STA", "X", val2, val1)
	case .STA_AY:
		return absoluteInstruction("STA", "Y", val2, val1)
	case .STA_IX:
		return indirectXInstruction("STA", val1)
	case .STA_IY:
		return indirectYInstruction("STA", val1)
	case .STX_ZP:
		//return zeroPageInstruction("STX", "", val1)
		return zero_page_instruction("STX", "", cpu, bus)
	case .STX_ZPY:
		return zeroPageInstruction("STX", "Y", val1)
	case .STX_A:
		// return absoluteInstruction("STX", "", val2, val1)
		return absolute_instruction("STX", "", cpu, bus)
	case .STY_ZP:
		return zeroPageInstruction("STY", "", val1)
	case .STY_ZPX:
		return zeroPageInstruction("STY", "X", val1)
	case .STY_A:
		return absoluteInstruction("STY", "", val2, val1)
	case .TAX:
		return simpleInstruction("TAX")
	case .TAY:
		return simpleInstruction("TAY")
	case .TSX:
		return simpleInstruction("TSX")
	case .TXA:
		return simpleInstruction("TXA")
	case .TXS:
		return simpleInstruction("TXS")
	case .TYA:
		return simpleInstruction("TYA")
	}

	return 0
}
