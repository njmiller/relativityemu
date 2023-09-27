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
	case .INX:
		return simpleInstruction("INX")
	case .TAX:
		return simpleInstruction("TAX")
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
	case .CMP_I:
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
	case .CPX_I:
		return immediateInstruction("CPX", memory[pc + 1])
	case .CPX_ZP:
		return zeroPageInstruction("CPX", "", memory[pc + 1])
	case .CPX_A:
		return absoluteInstruction("CPX", "", memory[pc + 2], memory[pc + 1])
	case .CPY_I:
		return immediateInstruction("CPY", memory[pc + 1])
	case .CPY_ZP:
		return zeroPageInstruction("CPY", "", memory[pc + 1])
	case .CPY_A:
		return absoluteInstruction("CPY", "", memory[pc + 2], memory[pc + 1])
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
	}

	return 0
}
