package cpu

import "core:fmt"

OpCode :: enum u8 {
    BRK = 0x00,
    LDA = 0xA9,
    TAX = 0xAA,
    INX = 0xE8,
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

test1 :: proc() {
    fmt.println("TEST CPU Package")
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

brk :: proc() -> int {
    return 7
}

lda :: proc(state: ^MOS6502, memory: []u8, addMode: AddressingMode) -> int {
    state.a = getValue8(state, memory, addMode)
    state.status = setZeroFlag(state.a, state.status)
    state.status = setNegativeFlag(state.a, state.status)

    return 2
}

tax :: proc(state: ^MOS6502) -> int {
    state.ix = state.a
    state.status = setZeroFlag(state.ix, state.status)
    state.status = setNegativeFlag(state.ix, state.status)

    return 2
}

inx :: proc(state: ^MOS6502) -> int {
    state.ix += 1
    state.status = setZeroFlag(state.ix, state.status)
    state.status = setNegativeFlag(state.ix, state.status)

    return 2
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
            fmt.println("ERROR IN ADRESSING")
    }

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

readImmediate16 :: proc(state: ^MOS6502, memory: []u8) -> u16 {
    low := readImmediate8(state, memory)
    high := readImmediate8(state, memory)
    return getCombined(high, low)
}

emulate6502p :: proc(state: ^MOS6502, memory: []u8) -> int {
    opcode : OpCode = auto_cast readImmediate8(state, memory)
    nCycles : int

    switch opcode {
        case .BRK:
            nCycles = brk()
        case .LDA:
            nCycles = lda(state, memory, .Immediate)
        case .TAX:
            nCycles = tax(state)
        case .INX:
            nCycles = inx(state)
    }

    return 1
}