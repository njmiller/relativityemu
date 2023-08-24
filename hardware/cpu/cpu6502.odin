package cpu

import "core:fmt"
import "core:math/bits"
import "core:log"

OpCode :: enum u8 {
    BRK = 0x00,
    ADC_IX = 0x61,
    ADC_ZP = 0x65,
    ADC_IM = 0x69,
    ADC_A = 0x6D,
    ADC_IY = 0x71,
    ADC_ZPX = 0x75,
    ADC_AY = 0x79,
    ADC_AX = 0x7D,
    LDA_IX = 0xA1,
    LDA_ZP = 0xA5,
    LDA_IM = 0xA9,
    TAX = 0xAA,
    LDA_A = 0xAD,
    LDA_IY = 0xB1,
    LDA_ZPX = 0xB5,
    LDA_AY = 0xB9,
    LDA_AX = 0xBD,
    INX = 0xE8,
}

AddModeMap := map[OpCode]OpCodeInfo {
    .BRK = {7, .NoneAddressing},
    .LDA_IM = {2, .Immediate},
    .LDA_ZP = {3, .ZeroPage},
    .LDA_ZPX = {4, .ZeroPage_X},
    .LDA_A = {4, .Absolute},
    .LDA_AX = {4, .Absolute_X},
    .LDA_AY = {4, .Absolute_Y},
    .LDA_IX = {6, .Indirect_X},
    .LDA_IY = {5, .Indirect_Y},
    .TAX = {2, .NoneAddressing},
    .INX = {2, .NoneAddressing},
    .ADC_IM = {2, .Immediate},
    .ADC_ZP = {3, .ZeroPage},
    .ADC_ZPX = {4, .ZeroPage_X},
    .ADC_A = {4, .Absolute},
    .ADC_AX = {4, .Absolute_X},
    .ADC_AY = {4, .Absolute_Y},
    .ADC_IX = {6, .Indirect_X},
    .ADC_IY = {5, .Indirect_Y},
}

OpCodeInfo :: struct {
    nCycles : int,
    addMode : AddressingMode,
}

AddressingMode :: enum u8 {
    Immediate,
    ZeroPage,
    ZeroPage_X,
    ZeroPage_Y,
    Absolute,
    Absolute_X,
    Absolute_Y,
    Indirect_X,
    Indirect_Y,
    NoneAddressing,
}
 
MOS6502 :: struct {
    a : u8,
    status: u8,
    pc: int,
    sp: u8,
    ix: u8,
    iy: u8,
}

setFlags :: proc(value: u8, flagsIn: u8) -> u8 {
    return 1
} 

setZeroFlag :: proc(value: u8, flagsIn: u8) -> u8 {
    zeroFlag : u8 : 0b0000_0010
    flagsOut := value == 0 ? flagsIn | zeroFlag : flagsIn &~ zeroFlag

    return flagsOut
}

setNegativeFlag :: proc(value: u8, flagsIn: u8) -> u8 {
    negativeFlag : u8 : 0b1000_0000
    negativeBit : u8 : 0b1000_0000

    flagsOut := value & negativeBit != 0 ? flagsIn | negativeFlag : flagsIn &~ negativeFlag

    return flagsOut
}

setOverflowFlag :: proc(val1: u8, val2: u8, flagsIn: u8) -> u8 {
    overflowFlag : u8 : 0b0100_0000
    isOverflow := (val1 & 0x80) != (val2 & 0x80)
    flagsOut := isOverflow ? flagsIn | overflowFlag : flagsIn &~ overflowFlag
    return flagsOut
}

brk :: proc() {}

adc :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) {
    
    m := getValue8(state, memory, addMode)

    value, cy := bits.overflowing_add(state.a, m)
    value2, cy2 := bits.overflowing_add(state.a, state.status & 1) 
    
    state.status = setNegativeFlag(value2, state.status)
    state.status = setZeroFlag(value2, state.status)
    state.status = setOverflowFlag(state.a, value2, state.status)
    state.status = cy | cy2 ? state.status | 1 : state.status &~ 1

    state.a = value2
}

lda :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) {
    state.a = getValue8(state, memory, addMode)
    state.status = setZeroFlag(state.a, state.status)
    state.status = setNegativeFlag(state.a, state.status)
}

ldx :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) {
    state.ix = getValue8(state, memory, addMode)
    state.status = setZeroFlag(state.a, state.status)
    state.status = setNegativeFlag(state.a, state.status)
}

ldy :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) {
    state.iy = getValue8(state, memory, addMode)
    state.status = setZeroFlag(state.a, state.status)
    state.status = setNegativeFlag(state.a, state.status)
}

tax :: proc(state: ^MOS6502) {
    state.ix = state.a
    state.status = setZeroFlag(state.ix, state.status)
    state.status = setNegativeFlag(state.ix, state.status)
}

inx :: proc(state: ^MOS6502) {
    state.ix += 1
    state.status = setZeroFlag(state.ix, state.status)
    state.status = setNegativeFlag(state.ix, state.status)
}

getValue8 :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) -> u8 {
    
    switch addMode {
        case .Immediate:
            return readImmediate8(state, memory)
        case .Absolute:
            return memory[readImmediate16(state, memory)]
        case .Absolute_X:
            offset := readImmediate16(state, memory)
            return memory[u16(state.ix)+offset]
        case .Absolute_Y:
            offset := readImmediate16(state, memory)
            return memory[u16(state.iy)+offset]
        case .ZeroPage:
            return memory[readImmediate8(state, memory)]
        case .ZeroPage_X:
            return memory[readImmediate8(state, memory) + state.ix]
        case .ZeroPage_Y:
            return memory[readImmediate8(state, memory) + state.iy]
        case .Indirect_X:
            addr := state.ix + readImmediate8(state, memory)
            low := memory[addr]
            high := memory[addr+1]
            return memory[getCombined(high, low)]
        case .Indirect_Y:
            base := readImmediate8(state, memory)
            low := memory[base]
            high := memory[base+1]
            return memory[getCombined(high, low) + u16(state.iy)]
        case .NoneAddressing:
            log.error("Trying to read operand with NoneAddressing")
            return 0
    }

    log.error("Somehow made it past the switch statement which should always return")
    return 0
}

pushR :: proc(reg1: u8, reg2: u8, state: ^MOS6502, stack: []u8) -> int {
    stack[state.sp-2] = reg2
    stack[state.sp-1] = reg1
    state.sp -= 2
    return 1
}

popR :: proc(reg1: ^u8, reg2: ^u8, state: ^MOS6502, stack: []u8) -> int {
    reg2^ = stack[state.sp]
    reg1^ = stack[state.sp+1]
    state.sp += 2
    return 1
}

getHighLow :: proc(value: u16) -> (u8, u8) {
    high : u8 = auto_cast (value >> 8) & 0xff
    low : u8 = auto_cast value & 0xff

    return high, low
}

getCombined :: proc(high: u8, low: u8) -> u16 { return (u16(high) << 8) | u16(low) }

getStack :: proc(memory: []u8) -> []u8 { return memory[0x0100:0x0200] }

readImmediate8 :: proc(state: ^MOS6502, memory: []u8) -> u8 {
    state.pc += 1
    return memory[state.pc-1]
}

/*
readImmediate16 :: proc(state: ^MOS6502, memory: []u8) -> u16 {
    low := readImmediate8(state, memory)
    high := readImmediate8(state, memory)
    return getCombined(high, low)
}
*/

readImmediate16 :: proc(state: ^MOS6502, memory: []u8) -> u16 {
    state.pc += 2
    return auto_cast (cast(^u16le) &memory[state.pc-2])^
}

emulate6502p :: proc(state: ^MOS6502, memory: []u8) -> int {
    opcode : OpCode = auto_cast readImmediate8(state, memory)
    nCycles : int

    opCodeInfo := AddModeMap[opcode]

    switch opcode {
        case .BRK:
            brk()
        case .LDA_IM, .LDA_ZP, .LDA_ZPX, .LDA_A, .LDA_AX, .LDA_AY, .LDA_IX, .LDA_IY:
            lda(state, memory, opCodeInfo.addMode)
        case .ADC_IM, .ADC_ZP, .ADC_ZPX, .ADC_A, .ADC_AX, .ADC_AY, .ADC_IX, .ADC_IY:
            adc(state, memory, opCodeInfo.addMode)
        case .TAX:
            tax(state)
        case .INX:
            inx(state)
    }

    return opCodeInfo.nCycles
}