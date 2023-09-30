package cpu

import "core:fmt"

//Instructions for each addressing mode
simpleInstruction :: proc(text: string) -> int {
	fmt.printf(text)
	fmt.printf("\n")
	return 1
}

absoluteInstruction :: proc(text: string, register: string, val1: u8, val2: u8) -> int {
	fmt.printf(text)
	fmt.printf(" $%02x%02x", val2, val1)

	if register == "X" || register == "Y" {
		fmt.printf(",")
		fmt.printf(register)
	}
	fmt.printf("\n")
	return 3
}

zeroPageInstruction :: proc(text: string, register: string, value: u8) -> int {
	fmt.printf(text)
	fmt.printf(" $%02x", value)

	if register == "X" || register == "Y" {
		fmt.printf(",")
		fmt.printf(register)
	}
	fmt.printf("\n")
	return 2
}

immediateInstruction :: proc(text: string, value: u8) -> int {
	fmt.printf(text)
	fmt.printf(" #$%02x", value)
	fmt.printf("\n")
	return 2
}

indirectInstruction :: proc(text: string, val1: u8, val2: u8) -> int {
	fmt.printf(text)
	fmt.printf(" (")
	fmt.printf("$%02x%02x", val2, val1)
	fmt.printf(")\n")
	return 3
}

indirectXInstruction :: proc(text: string, value: u8) -> int {
	fmt.printf(text)
	fmt.printf(" (,$%02x,X)\n", value)
	return 2
}

indirectYInstruction :: proc(text: string, value: u8) -> int {
	fmt.printf(text)
	fmt.printf(" ($%02x),Y\n")
	return 2
}

disassemble6502p :: proc(memory: []u8, pc: int) -> int {
	opcode: OpCode = auto_cast memory[pc]

	switch opcode {
	case .BRK:
		return simpleInstruction("BRK")
	case .ADC_IM:
		return immediateInstruction("ADC", memory[pc + 1])
	case .ADC_ZP:
		return zeroPageInstruction("ADC", "", memory[pc + 1])
	case .ADC_ZPX:
		return zeroPageInstruction("ADC", "X", memory[pc + 1])
	case .ADC_A:
		return absoluteInstruction("ADC", "", memory[pc + 2], memory[pc + 1])
	case .ADC_AX:
		return absoluteInstruction("ADC", "X", memory[pc + 2], memory[pc + 1])
	case .ADC_AY:
		return absoluteInstruction("ADC", "Y", memory[pc + 2], memory[pc + 1])
	case .ADC_IX:
		return indirectXInstruction("ADC", memory[pc + 1])
	case .ADC_IY:
		return indirectYInstruction("ADC", memory[pc + 1])
	case .AND_IM:
		return immediateInstruction("AND", memory[pc + 1])
	case .AND_ZP:
		return zeroPageInstruction("AND", "", memory[pc + 1])
	case .AND_ZPX:
		return zeroPageInstruction("AND", "X", memory[pc + 1])
	case .AND_A:
		return absoluteInstruction("AND", "", memory[pc + 2], memory[pc + 1])
	case .AND_AX:
		return absoluteInstruction("AND", "X", memory[pc + 2], memory[pc + 1])
	case .AND_AY:
		return absoluteInstruction("AND", "Y", memory[pc + 2], memory[pc + 1])
	case .AND_IX:
		return indirectXInstruction("AND", memory[pc + 1])
	case .AND_IY:
		return indirectYInstruction("AND", memory[pc + 1])
	case .ASL_ACC:
		return simpleInstruction("ASL A")
	case .ASL_ZP:
		return zeroPageInstruction("ASL", "", memory[pc + 1])
	case .ASL_ZPX:
		return zeroPageInstruction("ASL", "X", memory[pc + 1])
	case .ASL_A:
		return absoluteInstruction("ASL", "", memory[pc + 2], memory[pc + 1])
	case .ASL_AX:
		return absoluteInstruction("ASL", "X", memory[pc + 2], memory[pc + 1])
	case .BCC:
		return immediateInstruction("BCC", memory[pc + 1])
	case .BCS:
		return immediateInstruction("BCS", memory[pc + 1])
	case .BEQ:
		return immediateInstruction("BEQ", memory[pc + 1])
	case .BIT_A:
		return absoluteInstruction("BIT", "", memory[pc + 2], memory[pc + 1])
	case .BIT_ZP:
		return zeroPageInstruction("BIT", "", memory[pc + 1])
	case .BMI:
		return immediateInstruction("BMI", memory[pc + 1])
	case .BNE:
		return immediateInstruction("BNE", memory[pc + 1])
	case .BPL:
		return immediateInstruction("BPL", memory[pc + 1])
	case .BVC:
		return immediateInstruction("BVC", memory[pc + 1])
	case .BVS:
		return immediateInstruction("BVS", memory[pc + 1])
	case .CLC:
		return simpleInstruction("CLC")
	case .CLD:
		return simpleInstruction("CLD")
	case .CLI:
		return simpleInstruction("CLI")
	case .CLV:
		return simpleInstruction("CLV")
	case .CMP_IM:
		return immediateInstruction("CMP", memory[pc + 1])
	case .CMP_ZP:
		return zeroPageInstruction("CMP", "", memory[pc + 1])
	case .CMP_ZPX:
		return zeroPageInstruction("CMP", "X", memory[pc + 1])
	case .CMP_A:
		return absoluteInstruction("CMP", "", memory[pc + 2], memory[pc + 1])
	case .CMP_AX:
		return absoluteInstruction("CMP", "X", memory[pc + 2], memory[pc + 1])
	case .CMP_AY:
		return absoluteInstruction("CMP", "Y", memory[pc + 2], memory[pc + 1])
	case .CMP_IX:
		return indirectXInstruction("CMP", memory[pc + 1])
	case .CMP_IY:
		return indirectYInstruction("CMP", memory[pc + 1])
	case .CPX_IM:
		return immediateInstruction("CPX", memory[pc + 1])
	case .CPX_ZP:
		return zeroPageInstruction("CPX", "", memory[pc + 1])
	case .CPX_A:
		return absoluteInstruction("CPX", "", memory[pc + 2], memory[pc + 1])
	case .CPY_IM:
		return immediateInstruction("CPY", memory[pc + 1])
	case .CPY_ZP:
		return zeroPageInstruction("CPY", "", memory[pc + 1])
	case .CPY_A:
		return absoluteInstruction("CPY", "", memory[pc + 2], memory[pc + 1])
	case .DEC_ZP:
		return zeroPageInstruction("DEC", "", memory[pc + 1])
	case .DEC_ZPX:
		return zeroPageInstruction("DEC", "X", memory[pc + 1])
	case .DEC_A:
		return absoluteInstruction("DEC", "", memory[pc + 2], memory[pc + 1])
	case .DEC_AX:
		return absoluteInstruction("DEC", "X", memory[pc + 2], memory[pc + 1])
	case .DEX:
		return simpleInstruction("DEX")
	case .DEY:
		return simpleInstruction("DEY")
	case .EOR_IM:
		return immediateInstruction("EOR", memory[pc + 1])
	case .EOR_ZP:
		return zeroPageInstruction("EOR", "", memory[pc + 1])
	case .EOR_ZPX:
		return zeroPageInstruction("EOR", "X", memory[pc + 1])
	case .EOR_A:
		return absoluteInstruction("EOR", "", memory[pc + 2], memory[pc + 1])
	case .EOR_AX:
		return absoluteInstruction("EOR", "X", memory[pc + 2], memory[pc + 1])
	case .EOR_AY:
		return absoluteInstruction("EOR", "Y", memory[pc + 2], memory[pc + 1])
	case .EOR_IX:
		return indirectXInstruction("EOR", memory[pc + 1])
	case .EOR_IY:
		return indirectYInstruction("EOR", memory[pc + 1])
	case .INC_ZP:
		return zeroPageInstruction("INC", "", memory[pc + 1])
	case .INC_ZPX:
		return zeroPageInstruction("INC", "X", memory[pc + 1])
	case .INC_A:
		return absoluteInstruction("INC", "", memory[pc + 2], memory[pc + 1])
	case .INC_AX:
		return absoluteInstruction("INC", "X", memory[pc + 2], memory[pc + 1])
	case .INX:
		return simpleInstruction("INX")
	case .INY:
		return simpleInstruction("INY")
	case .JMP_A:
		return absoluteInstruction("JMP", "", memory[pc + 2], memory[pc + 1])
	case .JMP_I:
		return indirectInstruction("JMP", memory[pc + 2], memory[pc + 1])
	case .JSR:
		return absoluteInstruction("JSR", "", memory[pc + 2], memory[pc + 1])
	case .LDA_IM:
		return immediateInstruction("LDA", memory[pc + 1])
	case .LDA_ZP:
		return zeroPageInstruction("LDA", "", memory[pc + 1])
	case .LDA_ZPX:
		return zeroPageInstruction("LDA", "X", memory[pc + 1])
	case .LDA_A:
		return absoluteInstruction("LDA", "", memory[pc + 2], memory[pc + 1])
	case .LDA_AX:
		return absoluteInstruction("LDA", "X", memory[pc + 2], memory[pc + 1])
	case .LDA_AY:
		return absoluteInstruction("LDA", "Y", memory[pc + 2], memory[pc + 1])
	case .LDA_IX:
		return indirectXInstruction("LDA", memory[pc + 1])
	case .LDA_IY:
		return indirectYInstruction("LDA", memory[pc + 1])
	case .LDX_IM:
		return immediateInstruction("LDX", memory[pc + 1])
	case .LDX_ZP:
		return zeroPageInstruction("LDX", "", memory[pc + 1])
	case .LDX_ZPY:
		return zeroPageInstruction("LDX", "Y", memory[pc + 1])
	case .LDX_A:
		return absoluteInstruction("LDX", "", memory[pc + 2], memory[pc + 1])
	case .LDX_AY:
		return absoluteInstruction("LDX", "Y", memory[pc + 2], memory[pc + 1])
	case .LDY_IM:
		return immediateInstruction("LDY", memory[pc + 1])
	case .LDY_ZP:
		return zeroPageInstruction("LDY", "", memory[pc + 1])
	case .LDY_ZPX:
		return zeroPageInstruction("LDY", "X", memory[pc + 1])
	case .LDY_A:
		return absoluteInstruction("LDY", "", memory[pc + 2], memory[pc + 1])
	case .LDY_AX:
		return absoluteInstruction("LDY", "X", memory[pc + 2], memory[pc + 1])
	case .LSR_ACC:
		return simpleInstruction("LSR A")
	case .LSR_ZP:
		return zeroPageInstruction("LSR", "", memory[pc + 1])
	case .LSR_ZPX:
		return zeroPageInstruction("LSR", "X", memory[pc + 1])
	case .LSR_A:
		return absoluteInstruction("LSR", "", memory[pc + 2], memory[pc + 1])
	case .LSR_AX:
		return absoluteInstruction("LSR", "X", memory[pc + 2], memory[pc + 1])
	case .NOP:
		return simpleInstruction("NOP")
	case .ORA_IM:
		return immediateInstruction("ORA", memory[pc + 1])
	case .ORA_ZP:
		return zeroPageInstruction("ORA", "", memory[pc + 1])
	case .ORA_ZPX:
		return zeroPageInstruction("ORA", "X", memory[pc + 1])
	case .ORA_A:
		return absoluteInstruction("ORA", "", memory[pc + 2], memory[pc + 1])
	case .ORA_AX:
		return absoluteInstruction("ORA", "X", memory[pc + 2], memory[pc + 1])
	case .ORA_AY:
		return absoluteInstruction("ORA", "Y", memory[pc + 2], memory[pc + 1])
	case .ORA_IX:
		return indirectXInstruction("ORA", memory[pc + 1])
	case .ORA_IY:
		return indirectYInstruction("ORA", memory[pc + 1])
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
		return zeroPageInstruction("ROL", "", memory[pc + 1])
	case .ROL_ZPX:
		return zeroPageInstruction("ROL", "X", memory[pc + 1])
	case .ROL_A:
		return absoluteInstruction("ROL", "", memory[pc + 2], memory[pc + 1])
	case .ROL_AX:
		return absoluteInstruction("ROL", "X", memory[pc + 2], memory[pc + 1])
	case .ROR_ACC:
		return simpleInstruction("ROR A")
	case .ROR_ZP:
		return zeroPageInstruction("ROR", "", memory[pc + 1])
	case .ROR_ZPX:
		return zeroPageInstruction("ROR", "X", memory[pc + 1])
	case .ROR_A:
		return absoluteInstruction("ROR", "", memory[pc + 2], memory[pc + 1])
	case .ROR_AX:
		return absoluteInstruction("ROR", "X", memory[pc + 2], memory[pc + 1])
	case .RTI:
		return simpleInstruction("RTI")
	case .RTS:
		return simpleInstruction("RTS")
	case .SBC_IM:
		return immediateInstruction("SBC", memory[pc + 1])
	case .SBC_ZP:
		return zeroPageInstruction("SBC", "", memory[pc + 1])
	case .SBC_ZPX:
		return zeroPageInstruction("SBC", "X", memory[pc + 1])
	case .SBC_A:
		return absoluteInstruction("SBC", "", memory[pc + 2], memory[pc + 1])
	case .SBC_AX:
		return absoluteInstruction("SBC", "X", memory[pc + 2], memory[pc + 1])
	case .SBC_AY:
		return absoluteInstruction("SBC", "Y", memory[pc + 2], memory[pc + 1])
	case .SBC_IX:
		return indirectXInstruction("SBC", memory[pc + 1])
	case .SBC_IY:
		return indirectYInstruction("SBC", memory[pc + 1])
	case .SEC:
		return simpleInstruction("SEC")
	case .SED:
		return simpleInstruction("SED")
	case .SEI:
		return simpleInstruction("SEI")
	case .STA_ZP:
		return zeroPageInstruction("STA", "", memory[pc + 1])
	case .STA_ZPX:
		return zeroPageInstruction("STA", "X", memory[pc + 1])
	case .STA_A:
		return absoluteInstruction("STA", "", memory[pc + 2], memory[pc + 1])
	case .STA_AX:
		return absoluteInstruction("STA", "X", memory[pc + 2], memory[pc + 1])
	case .STA_AY:
		return absoluteInstruction("STA", "Y", memory[pc + 2], memory[pc + 1])
	case .STA_IX:
		return indirectXInstruction("STA", memory[pc + 1])
	case .STA_IY:
		return indirectYInstruction("STA", memory[pc + 1])
	case .STX_ZP:
		return zeroPageInstruction("STX", "", memory[pc + 1])
	case .STX_ZPY:
		return zeroPageInstruction("STX", "Y", memory[pc + 1])
	case .STX_A:
		return absoluteInstruction("STX", "", memory[pc + 2], memory[pc + 1])
	case .STY_ZP:
		return zeroPageInstruction("STY", "", memory[pc + 1])
	case .STY_ZPX:
		return zeroPageInstruction("STY", "X", memory[pc + 1])
	case .STY_A:
		return absoluteInstruction("STY", "", memory[pc + 2], memory[pc + 1])
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
