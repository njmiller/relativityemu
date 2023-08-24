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
    opcode : OpCode = auto_cast memory[pc]

    switch opcode {
        case .BRK:
            return simpleInstruction("BRK")
        case .INX:
            return simpleInstruction("INX")
        case .TAX:
            return simpleInstruction("TAX")
        case .ADC_IM:
            return immediateInstruction("ADC", memory[pc+1])
        case .ADC_ZP:
            return zeroPageInstruction("ADC", "", memory[pc+1])
        case .ADC_ZPX:
            return zeroPageInstruction("ADC", "X", memory[pc+1])
        case .ADC_A:
            return absoluteInstruction("ADC", "", memory[pc+2], memory[pc+1])
        case .ADC_AX:
            return absoluteInstruction("ADC", "X", memory[pc+2], memory[pc+1])
        case .ADC_AY:
            return absoluteInstruction("ADC", "Y", memory[pc+2], memory[pc+1])
        case .ADC_IX:
            return indirectXInstruction("ADC", memory[pc+1])
        case .ADC_IY:
            return indirectYInstruction("ADC", memory[pc+1])
        case .LDA_IM:
            return immediateInstruction("LDA", memory[pc+1])
        case .LDA_ZP:
            return zeroPageInstruction("LDA", "", memory[pc+1])
        case .LDA_ZPX:
            return zeroPageInstruction("LDA", "X", memory[pc+1])
        case .LDA_A:
            return absoluteInstruction("LDA", "", memory[pc+2], memory[pc+1])
        case .LDA_AX:
            return absoluteInstruction("LDA", "X", memory[pc+2], memory[pc+1])
        case .LDA_AY:
            return absoluteInstruction("LDA", "Y", memory[pc+2], memory[pc+1])
        case .LDA_IX:
            return indirectXInstruction("LDA", memory[pc+1])
        case .LDA_IY:
            return indirectYInstruction("LDA", memory[pc+1])
    }

    return 0
}