#include "cpu8085.h"
#include <sstream>
#include <iomanip>
#include <cstring>
#include <cstdio>
#include <algorithm>

CPU8085::CPU8085() {
    // Allocate memory banks on heap
    for (int i = 0; i < NUM_BANKS; i++) {
        memory_banks[i] = new uint8_t[65536];
        std::memset(memory_banks[i], 0, 65536);
    }
    current_bank = 0;
    reset();
}

CPU8085::~CPU8085() {
    // Free memory banks
    for (int i = 0; i < NUM_BANKS; i++) {
        delete[] memory_banks[i];
    }
}

void CPU8085::reset() {
    A = B = C = D = E = H = L = 0;
    SP = 0xFFFF;
    PC = 0x0000;
    flags = {false, false, false, false, false};
    
    // Clear all memory banks
    for (int i = 0; i < NUM_BANKS; i++) {
        std::memset(memory_banks[i], 0, 65536);
    }
    
    current_bank = 0;
    halted = false;
    interruptEnabled = false;
}

uint8_t CPU8085::fetchByte() {
    return memory_banks[current_bank][PC++];
}

uint16_t CPU8085::fetchWord() {
    uint8_t low = fetchByte();
    uint8_t high = fetchByte();
    return (high << 8) | low;
}

void CPU8085::step() {
    if (halted) return;
    
    uint8_t opcode = fetchByte();
    executeInstruction(opcode);
}

void CPU8085::executeInstruction(uint8_t opcode) {
    uint16_t addr, temp16;
    uint8_t temp8;
    
    // Define memory accessor for current bank
    uint8_t* memory = memory_banks[current_bank];
    
    switch (opcode) {
        // NOP and HLT
        case 0x00: break; // NOP
        case 0x76: halted = true; break; // HLT
        
        // Data Transfer Group - MOV r1, r2 (all 49 combinations)
        case 0x40: B = B; break; case 0x41: B = C; break; case 0x42: B = D; break; case 0x43: B = E; break;
        case 0x44: B = H; break; case 0x45: B = L; break; case 0x46: B = memory[getHL()]; break; case 0x47: B = A; break;
        case 0x48: C = B; break; case 0x49: C = C; break; case 0x4A: C = D; break; case 0x4B: C = E; break;
        case 0x4C: C = H; break; case 0x4D: C = L; break; case 0x4E: C = memory[getHL()]; break; case 0x4F: C = A; break;
        case 0x50: D = B; break; case 0x51: D = C; break; case 0x52: D = D; break; case 0x53: D = E; break;
        case 0x54: D = H; break; case 0x55: D = L; break; case 0x56: D = memory[getHL()]; break; case 0x57: D = A; break;
        case 0x58: E = B; break; case 0x59: E = C; break; case 0x5A: E = D; break; case 0x5B: E = E; break;
        case 0x5C: E = H; break; case 0x5D: E = L; break; case 0x5E: E = memory[getHL()]; break; case 0x5F: E = A; break;
        case 0x60: H = B; break; case 0x61: H = C; break; case 0x62: H = D; break; case 0x63: H = E; break;
        case 0x64: H = H; break; case 0x65: H = L; break; case 0x66: H = memory[getHL()]; break; case 0x67: H = A; break;
        case 0x68: L = B; break; case 0x69: L = C; break; case 0x6A: L = D; break; case 0x6B: L = E; break;
        case 0x6C: L = H; break; case 0x6D: L = L; break; case 0x6E: L = memory[getHL()]; break; case 0x6F: L = A; break;
        case 0x70: memory[getHL()] = B; break; case 0x71: memory[getHL()] = C; break;
        case 0x72: memory[getHL()] = D; break; case 0x73: memory[getHL()] = E; break;
        case 0x74: memory[getHL()] = H; break; case 0x75: memory[getHL()] = L; break;
        case 0x77: memory[getHL()] = A; break;
        case 0x78: A = B; break; case 0x79: A = C; break; case 0x7A: A = D; break; case 0x7B: A = E; break;
        case 0x7C: A = H; break; case 0x7D: A = L; break; case 0x7E: A = memory[getHL()]; break; case 0x7F: A = A; break;
        
        // MVI r, data
        case 0x06: B = fetchByte(); break; case 0x0E: C = fetchByte(); break;
        case 0x16: D = fetchByte(); break; case 0x1E: E = fetchByte(); break;
        case 0x26: H = fetchByte(); break; case 0x2E: L = fetchByte(); break;
        case 0x36: memory[getHL()] = fetchByte(); break; case 0x3E: A = fetchByte(); break;
        
        // LXI rp, data16
        case 0x01: setBC(fetchWord()); break; // LXI B
        case 0x11: setDE(fetchWord()); break; // LXI D
        case 0x21: setHL(fetchWord()); break; // LXI H
        case 0x31: SP = fetchWord(); break;    // LXI SP
        
        // LDA/STA addr
        case 0x3A: addr = fetchWord(); A = memory[addr]; break; // LDA
        case 0x32: addr = fetchWord(); memory[addr] = A; break; // STA
        
        // LHLD/SHLD addr
        case 0x2A: addr = fetchWord(); L = memory[addr]; H = memory[addr + 1]; break; // LHLD
        case 0x22: addr = fetchWord(); memory[addr] = L; memory[addr + 1] = H; break; // SHLD
        
        // LDAX/STAX
        case 0x0A: A = memory[getBC()]; break; // LDAX B
        case 0x1A: A = memory[getDE()]; break; // LDAX D
        case 0x02: memory[getBC()] = A; break; // STAX B
        case 0x12: memory[getDE()] = A; break; // STAX D
        
        // XCHG
        case 0xEB: temp8 = D; D = H; H = temp8; temp8 = E; E = L; L = temp8; break;
        
        // Arithmetic Group - ADD
        case 0x80: A = add(B); break; case 0x81: A = add(C); break; case 0x82: A = add(D); break;
        case 0x83: A = add(E); break; case 0x84: A = add(H); break; case 0x85: A = add(L); break;
        case 0x86: A = add(memory[getHL()]); break; case 0x87: A = add(A); break;
        case 0xC6: A = add(fetchByte()); break; // ADI
        
        // ADC (Add with Carry)
        case 0x88: A = add(B, true); break; case 0x89: A = add(C, true); break; case 0x8A: A = add(D, true); break;
        case 0x8B: A = add(E, true); break; case 0x8C: A = add(H, true); break; case 0x8D: A = add(L, true); break;
        case 0x8E: A = add(memory[getHL()], true); break; case 0x8F: A = add(A, true); break;
        case 0xCE: A = add(fetchByte(), true); break; // ACI
        
        // SUB
        case 0x90: A = sub(B); break; case 0x91: A = sub(C); break; case 0x92: A = sub(D); break;
        case 0x93: A = sub(E); break; case 0x94: A = sub(H); break; case 0x95: A = sub(L); break;
        case 0x96: A = sub(memory[getHL()]); break; case 0x97: A = sub(A); break;
        case 0xD6: A = sub(fetchByte()); break; // SUI
        
        // SBB (Subtract with Borrow)
        case 0x98: A = sub(B, true); break; case 0x99: A = sub(C, true); break; case 0x9A: A = sub(D, true); break;
        case 0x9B: A = sub(E, true); break; case 0x9C: A = sub(H, true); break; case 0x9D: A = sub(L, true); break;
        case 0x9E: A = sub(memory[getHL()], true); break; case 0x9F: A = sub(A, true); break;
        case 0xDE: A = sub(fetchByte(), true); break; // SBI
        
        // INR (Increment)
        case 0x04: B++; updateFlags(B); break; case 0x0C: C++; updateFlags(C); break;
        case 0x14: D++; updateFlags(D); break; case 0x1C: E++; updateFlags(E); break;
        case 0x24: H++; updateFlags(H); break; case 0x2C: L++; updateFlags(L); break;
        case 0x34: temp8 = memory[getHL()] + 1; memory[getHL()] = temp8; updateFlags(temp8); break;
        case 0x3C: A++; updateFlags(A); break;
        
        // DCR (Decrement)
        case 0x05: B--; updateFlags(B); break; case 0x0D: C--; updateFlags(C); break;
        case 0x15: D--; updateFlags(D); break; case 0x1D: E--; updateFlags(E); break;
        case 0x25: H--; updateFlags(H); break; case 0x2D: L--; updateFlags(L); break;
        case 0x35: temp8 = memory[getHL()] - 1; memory[getHL()] = temp8; updateFlags(temp8); break;
        case 0x3D: A--; updateFlags(A); break;
        
        // INX (Increment Register Pair)
        case 0x03: setBC(getBC() + 1); break; case 0x13: setDE(getDE() + 1); break;
        case 0x23: setHL(getHL() + 1); break; case 0x33: SP++; break;
        
        // DCX (Decrement Register Pair)
        case 0x0B: setBC(getBC() - 1); break; case 0x1B: setDE(getDE() - 1); break;
        case 0x2B: setHL(getHL() - 1); break; case 0x3B: SP--; break;
        
        // DAD (Add register pair to HL)
        case 0x09: temp16 = getHL() + getBC(); flags.CY = (temp16 < getHL()); setHL(temp16); break;
        case 0x19: temp16 = getHL() + getDE(); flags.CY = (temp16 < getHL()); setHL(temp16); break;
        case 0x29: temp16 = getHL() + getHL(); flags.CY = (temp16 < getHL()); setHL(temp16); break;
        case 0x39: temp16 = getHL() + SP; flags.CY = (temp16 < getHL()); setHL(temp16); break;
        
        // DAA (Decimal Adjust Accumulator)
        case 0x27: {
            uint8_t correction = 0;
            if ((A & 0x0F) > 9 || flags.AC) correction += 0x06;
            if ((A >> 4) > 9 || flags.CY || ((A >> 4) >= 9 && (A & 0x0F) > 9)) {
                correction += 0x60;
                flags.CY = true;
            }
            A += correction;
            updateFlags(A);
            break;
        }
        
        // Logical Group - ANA (AND)
        case 0xA0: A &= B; updateFlagsLogical(A); break; case 0xA1: A &= C; updateFlagsLogical(A); break;
        case 0xA2: A &= D; updateFlagsLogical(A); break; case 0xA3: A &= E; updateFlagsLogical(A); break;
        case 0xA4: A &= H; updateFlagsLogical(A); break; case 0xA5: A &= L; updateFlagsLogical(A); break;
        case 0xA6: A &= memory[getHL()]; updateFlagsLogical(A); break; case 0xA7: A &= A; updateFlagsLogical(A); break;
        case 0xE6: A &= fetchByte(); updateFlagsLogical(A); break; // ANI
        
        // XRA (XOR)
        case 0xA8: A ^= B; updateFlagsLogical(A); break; case 0xA9: A ^= C; updateFlagsLogical(A); break;
        case 0xAA: A ^= D; updateFlagsLogical(A); break; case 0xAB: A ^= E; updateFlagsLogical(A); break;
        case 0xAC: A ^= H; updateFlagsLogical(A); break; case 0xAD: A ^= L; updateFlagsLogical(A); break;
        case 0xAE: A ^= memory[getHL()]; updateFlagsLogical(A); break; case 0xAF: A ^= A; updateFlagsLogical(A); break;
        case 0xEE: A ^= fetchByte(); updateFlagsLogical(A); break; // XRI
        
        // ORA (OR)
        case 0xB0: A |= B; updateFlagsLogical(A); break; case 0xB1: A |= C; updateFlagsLogical(A); break;
        case 0xB2: A |= D; updateFlagsLogical(A); break; case 0xB3: A |= E; updateFlagsLogical(A); break;
        case 0xB4: A |= H; updateFlagsLogical(A); break; case 0xB5: A |= L; updateFlagsLogical(A); break;
        case 0xB6: A |= memory[getHL()]; updateFlagsLogical(A); break; case 0xB7: A |= A; updateFlagsLogical(A); break;
        case 0xF6: A |= fetchByte(); updateFlagsLogical(A); break; // ORI
        
        // CMP (Compare)
        case 0xB8: sub(B); break; case 0xB9: sub(C); break; case 0xBA: sub(D); break; case 0xBB: sub(E); break;
        case 0xBC: sub(H); break; case 0xBD: sub(L); break; case 0xBE: sub(memory[getHL()]); break; case 0xBF: sub(A); break;
        case 0xFE: sub(fetchByte()); break; // CPI
        
        // RLC (Rotate Left)
        case 0x07: flags.CY = (A & 0x80) != 0; A = (A << 1) | (flags.CY ? 1 : 0); break;
        
        // RRC (Rotate Right)
        case 0x0F: flags.CY = (A & 0x01) != 0; A = (A >> 1) | (flags.CY ? 0x80 : 0); break;
        
        // RAL (Rotate Left through Carry)
        case 0x17: temp8 = flags.CY ? 1 : 0; flags.CY = (A & 0x80) != 0; A = (A << 1) | temp8; break;
        
        // RAR (Rotate Right through Carry)
        case 0x1F: temp8 = flags.CY ? 0x80 : 0; flags.CY = (A & 0x01) != 0; A = (A >> 1) | temp8; break;
        
        // CMA (Complement Accumulator)
        case 0x2F: A = ~A; break;
        
        // CMC (Complement Carry)
        case 0x3F: flags.CY = !flags.CY; break;
        
        // STC (Set Carry)
        case 0x37: flags.CY = true; break;
        
        // Branch Group - JMP
        case 0xC3: PC = fetchWord(); break; // JMP
        case 0xC2: addr = fetchWord(); if (!flags.Z) PC = addr; break; // JNZ
        case 0xCA: addr = fetchWord(); if (flags.Z) PC = addr; break;  // JZ
        case 0xD2: addr = fetchWord(); if (!flags.CY) PC = addr; break; // JNC
        case 0xDA: addr = fetchWord(); if (flags.CY) PC = addr; break;  // JC
        case 0xE2: addr = fetchWord(); if (!flags.P) PC = addr; break;  // JPO
        case 0xEA: addr = fetchWord(); if (flags.P) PC = addr; break;   // JPE
        case 0xF2: addr = fetchWord(); if (!flags.S) PC = addr; break;  // JP
        case 0xFA: addr = fetchWord(); if (flags.S) PC = addr; break;   // JM
        
        // CALL
        case 0xCD: addr = fetchWord(); push(PC); PC = addr; break; // CALL
        case 0xC4: addr = fetchWord(); if (!flags.Z) { push(PC); PC = addr; } break; // CNZ
        case 0xCC: addr = fetchWord(); if (flags.Z) { push(PC); PC = addr; } break;  // CZ
        case 0xD4: addr = fetchWord(); if (!flags.CY) { push(PC); PC = addr; } break; // CNC
        case 0xDC: addr = fetchWord(); if (flags.CY) { push(PC); PC = addr; } break;  // CC
        case 0xE4: addr = fetchWord(); if (!flags.P) { push(PC); PC = addr; } break;  // CPO
        case 0xEC: addr = fetchWord(); if (flags.P) { push(PC); PC = addr; } break;   // CPE
        case 0xF4: addr = fetchWord(); if (!flags.S) { push(PC); PC = addr; } break;  // CP
        case 0xFC: addr = fetchWord(); if (flags.S) { push(PC); PC = addr; } break;   // CM
        
        // RET
        case 0xC9: PC = pop(); break; // RET
        case 0xC0: if (!flags.Z) PC = pop(); break; // RNZ
        case 0xC8: if (flags.Z) PC = pop(); break;  // RZ
        case 0xD0: if (!flags.CY) PC = pop(); break; // RNC
        case 0xD8: if (flags.CY) PC = pop(); break;  // RC
        case 0xE0: if (!flags.P) PC = pop(); break;  // RPO
        case 0xE8: if (flags.P) PC = pop(); break;   // RPE
        case 0xF0: if (!flags.S) PC = pop(); break;  // RP
        case 0xF8: if (flags.S) PC = pop(); break;   // RM
        
        // RST (Restart)
        case 0xC7: push(PC); PC = 0x00; break; case 0xCF: push(PC); PC = 0x08; break;
        case 0xD7: push(PC); PC = 0x10; break; case 0xDF: push(PC); PC = 0x18; break;
        case 0xE7: push(PC); PC = 0x20; break; case 0xEF: push(PC); PC = 0x28; break;
        case 0xF7: push(PC); PC = 0x30; break; case 0xFF: push(PC); PC = 0x38; break;
        
        // PCHL (Move HL to PC)
        case 0xE9: PC = getHL(); break;
        
        // Stack Group - PUSH
        case 0xC5: push(getBC()); break; // PUSH B
        case 0xD5: push(getDE()); break; // PUSH D
        case 0xE5: push(getHL()); break; // PUSH H
        case 0xF5: push((A << 8) | (flags.S ? 0x80 : 0) | (flags.Z ? 0x40 : 0) | (flags.AC ? 0x10 : 0) | (flags.P ? 0x04 : 0) | 0x02 | (flags.CY ? 0x01 : 0)); break; // PUSH PSW
        
        // POP
        case 0xC1: setBC(pop()); break; // POP B
        case 0xD1: setDE(pop()); break; // POP D
        case 0xE1: setHL(pop()); break; // POP H
        case 0xF1: { // POP PSW
            temp16 = pop();
            A = (temp16 >> 8) & 0xFF;
            flags.S = (temp16 & 0x80) != 0;
            flags.Z = (temp16 & 0x40) != 0;
            flags.AC = (temp16 & 0x10) != 0;
            flags.P = (temp16 & 0x04) != 0;
            flags.CY = (temp16 & 0x01) != 0;
            break;
        }
        
        // XTHL (Exchange HL with top of stack)
        case 0xE3:
            temp8 = memory[SP];
            memory[SP] = L;
            L = temp8;
            temp8 = memory[SP + 1];
            memory[SP + 1] = H;
            H = temp8;
            break;
        
        // SPHL (Move HL to SP)
        case 0xF9: SP = getHL(); break;
        
        // IN/OUT (I/O instructions)
        case 0xDB: // IN port
            temp8 = fetchByte();  // port number
            if (ioReadCallback) {
                A = ioReadCallback(temp8);
            } else {
                A = 0xFF;  // Default: return 0xFF if no callback
            }
            break;
        case 0xD3: // OUT port
            temp8 = fetchByte();  // port number
            
            // Port 254 is reserved for bank switching
            if (temp8 == 254) {
                switchBank(A & 0x07);  // A contains bank number (0-7)
            } else if (ioWriteCallback) {
                ioWriteCallback(temp8, A);
            }
            break;
        
        // EI/DI (Enable/Disable Interrupts)
        case 0xFB: interruptEnabled = true; break;  // EI
        case 0xF3: interruptEnabled = false; break; // DI
        
        // RIM/SIM (8085 specific - Read/Set Interrupt Mask)
        case 0x20: A = 0; break; // RIM (simplified)
        case 0x30: break;         // SIM (simplified)
        
        // Undefined/Illegal opcodes in 8085 - treat as NOP
        case 0x08: break; // *NOP (undefined)
        case 0x10: break; // *NOP (undefined)
        case 0x18: break; // *NOP (undefined)
        case 0x28: break; // *NOP (undefined)
        case 0x38: break; // *NOP (undefined)
        case 0xCB: break; // *NOP (undefined)
        case 0xD9: break; // *NOP (undefined - RET in 8080, but NOP in 8085)
        case 0xDD: break; // *NOP (undefined)
        case 0xED: break; // *NOP (undefined)
        case 0xFD: break; // *NOP (undefined)
        
        default:
            // Unknown opcode - should never reach here if all 256 are covered
            break;
    }
}

uint8_t CPU8085::add(uint8_t value, bool withCarry) {
    uint16_t result = A + value + (withCarry && flags.CY ? 1 : 0);
    flags.CY = (result > 0xFF);
    flags.AC = ((A & 0x0F) + (value & 0x0F) + (withCarry && flags.CY ? 1 : 0)) > 0x0F;
    updateFlags(result & 0xFF);
    return result & 0xFF;
}

uint8_t CPU8085::sub(uint8_t value, bool withBorrow) {
    uint16_t result = A - value - (withBorrow && flags.CY ? 1 : 0);
    flags.CY = (result > 0xFF);
    flags.AC = ((A & 0x0F) < ((value & 0x0F) + (withBorrow && flags.CY ? 1 : 0)));
    updateFlags(result & 0xFF);
    return result & 0xFF;
}

void CPU8085::updateFlags(uint8_t result) {
    flags.Z = (result == 0);
    flags.S = (result & 0x80) != 0;
    
    // Calculate parity
    int bits = 0;
    for (int i = 0; i < 8; i++) {
        if (result & (1 << i)) bits++;
    }
    flags.P = (bits % 2 == 0);
}

void CPU8085::updateFlagsLogical(uint8_t result) {
    flags.Z = (result == 0);
    flags.S = (result & 0x80) != 0;
    flags.CY = false;  // Logical operations clear carry
    flags.AC = false;  // Auxiliary carry is reset
    
    // Calculate parity
    int bits = 0;
    for (int i = 0; i < 8; i++) {
        if (result & (1 << i)) bits++;
    }
    flags.P = (bits % 2 == 0);
}

void CPU8085::push(uint16_t value) {
    memory_banks[current_bank][--SP] = (value >> 8) & 0xFF;
    memory_banks[current_bank][--SP] = value & 0xFF;
}

uint16_t CPU8085::pop() {
    uint8_t low = memory_banks[current_bank][SP++];
    uint8_t high = memory_banks[current_bank][SP++];
    return (high << 8) | low;
}

std::string CPU8085::getRegisterState() const {
    std::ostringstream oss;
    oss << std::hex << std::uppercase << std::setfill('0');
    oss << "A:" << std::setw(2) << (int)A << " "
        << "B:" << std::setw(2) << (int)B << " "
        << "C:" << std::setw(2) << (int)C << " "
        << "D:" << std::setw(2) << (int)D << " "
        << "E:" << std::setw(2) << (int)E << " "
        << "H:" << std::setw(2) << (int)H << " "
        << "L:" << std::setw(2) << (int)L << "\n"
        << "SP:" << std::setw(4) << SP << " "
        << "PC:" << std::setw(4) << PC;
    return oss.str();
}

std::string CPU8085::getFlagsState() const {
    std::ostringstream oss;
    oss << "S:" << flags.S << " "
        << "Z:" << flags.Z << " "
        << "AC:" << flags.AC << " "
        << "P:" << flags.P << " "
        << "CY:" << flags.CY;
    return oss.str();
}

uint8_t CPU8085::getMemory(uint16_t address) const {
    return memory_banks[current_bank][address];
}

void CPU8085::setMemory(uint16_t address, uint8_t value) {
    memory_banks[current_bank][address] = value;
}

bool CPU8085::loadBinary(const char* filename, uint16_t startAddress) {
    FILE* f = fopen(filename, "rb");
    if (!f) return false;
    
    // Get file size
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    
    // Read file into current bank's memory
    size_t bytesRead = fread(&memory_banks[current_bank][startAddress], 1, 
                             std::min((long)(65536 - startAddress), size), f);
    fclose(f);
    
    return bytesRead > 0;
}

void CPU8085::loadProgram(const uint8_t* program, size_t size, uint16_t startAddress) {
    std::memcpy(&memory_banks[current_bank][startAddress], program, size);
    PC = startAddress;
}

// Bank switching functions
void CPU8085::switchBank(int bank) {
    if (bank >= 0 && bank < NUM_BANKS) {
        current_bank = bank;
        // Note: memory reference already points to memory_banks[0]
        // We need to update the reference, but C++ doesn't allow reassigning references
        // So we use direct array access in memory operations instead
    }
}

uint8_t CPU8085::getMemoryFromBank(int bank, uint16_t address) const {
    if (bank >= 0 && bank < NUM_BANKS) {
        return memory_banks[bank][address];
    }
    return 0;
}

void CPU8085::setMemoryInBank(int bank, uint16_t address, uint8_t value) {
    if (bank >= 0 && bank < NUM_BANKS) {
        memory_banks[bank][address] = value;
    }
}
