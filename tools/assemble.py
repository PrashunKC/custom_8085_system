#!/usr/bin/env python3
"""
Simple 8080/8085 Assembler for BIOS
Handles basic instructions needed for the monitor BIOS
"""

import sys
import re
from pathlib import Path

class Assembler8085:
    def __init__(self):
        self.labels = {}
        self.output = bytearray()
        self.pc = 0
        self.org = 0
        
        # 8080/8085 instruction opcodes
        self.opcodes = {
            # Data transfer
            'MOV': {'B,B': 0x40, 'B,C': 0x41, 'B,D': 0x42, 'B,E': 0x43, 'B,H': 0x44, 'B,L': 0x45, 'B,M': 0x46, 'B,A': 0x47,
                    'C,B': 0x48, 'C,C': 0x49, 'C,D': 0x4A, 'C,E': 0x4B, 'C,H': 0x4C, 'C,L': 0x4D, 'C,M': 0x4E, 'C,A': 0x4F,
                    'D,B': 0x50, 'D,C': 0x51, 'D,D': 0x52, 'D,E': 0x53, 'D,H': 0x54, 'D,L': 0x55, 'D,M': 0x56, 'D,A': 0x57,
                    'E,B': 0x58, 'E,C': 0x59, 'E,D': 0x5A, 'E,E': 0x5B, 'E,H': 0x5C, 'E,L': 0x5D, 'E,M': 0x5E, 'E,A': 0x5F,
                    'H,B': 0x60, 'H,C': 0x61, 'H,D': 0x62, 'H,E': 0x63, 'H,H': 0x64, 'H,L': 0x65, 'H,M': 0x66, 'H,A': 0x67,
                    'L,B': 0x68, 'L,C': 0x69, 'L,D': 0x6A, 'L,E': 0x6B, 'L,H': 0x6C, 'L,L': 0x6D, 'L,M': 0x6E, 'L,A': 0x6F,
                    'M,B': 0x70, 'M,C': 0x71, 'M,D': 0x72, 'M,E': 0x73, 'M,H': 0x74, 'M,L': 0x75, 'M,A': 0x77,
                    'A,B': 0x78, 'A,C': 0x79, 'A,D': 0x7A, 'A,E': 0x7B, 'A,H': 0x7C, 'A,L': 0x7D, 'A,M': 0x7E, 'A,A': 0x7F},
            'MVI': {'B': 0x06, 'C': 0x0E, 'D': 0x16, 'E': 0x1E, 'H': 0x26, 'L': 0x2E, 'M': 0x36, 'A': 0x3E},
            'LXI': {'B': 0x01, 'D': 0x11, 'H': 0x21, 'SP': 0x31},
            'STAX': {'B': 0x02, 'D': 0x12},
            'LDAX': {'B': 0x0A, 'D': 0x1A},
            'STA': 0x32, 'LDA': 0x3A, 'SHLD': 0x22, 'LHLD': 0x2A,
            'XCHG': 0xEB, 'XTHL': 0xE3, 'SPHL': 0xF9, 'PCHL': 0xE9,
            
            # Arithmetic
            'ADD': {'B': 0x80, 'C': 0x81, 'D': 0x82, 'E': 0x83, 'H': 0x84, 'L': 0x85, 'M': 0x86, 'A': 0x87},
            'ADI': 0xC6, 'ADC': {'B': 0x88, 'C': 0x89, 'D': 0x8A, 'E': 0x8B, 'H': 0x8C, 'L': 0x8D, 'M': 0x8E, 'A': 0x8F},
            'ACI': 0xCE, 'SUB': {'B': 0x90, 'C': 0x91, 'D': 0x92, 'E': 0x93, 'H': 0x94, 'L': 0x95, 'M': 0x96, 'A': 0x97},
            'SUI': 0xD6, 'SBB': {'B': 0x98, 'C': 0x99, 'D': 0x9A, 'E': 0x9B, 'H': 0x9C, 'L': 0x9D, 'M': 0x9E, 'A': 0x9F},
            'SBI': 0xDE, 'INR': {'B': 0x04, 'C': 0x0C, 'D': 0x14, 'E': 0x1C, 'H': 0x24, 'L': 0x2C, 'M': 0x34, 'A': 0x3C},
            'DCR': {'B': 0x05, 'C': 0x0D, 'D': 0x15, 'E': 0x1D, 'H': 0x25, 'L': 0x2D, 'M': 0x35, 'A': 0x3D},
            'INX': {'B': 0x03, 'D': 0x13, 'H': 0x23, 'SP': 0x33},
            'DCX': {'B': 0x0B, 'D': 0x1B, 'H': 0x2B, 'SP': 0x3B},
            'DAD': {'B': 0x09, 'D': 0x19, 'H': 0x29, 'SP': 0x39},
            'DAA': 0x27,
            
            # Logical
            'ANA': {'B': 0xA0, 'C': 0xA1, 'D': 0xA2, 'E': 0xA3, 'H': 0xA4, 'L': 0xA5, 'M': 0xA6, 'A': 0xA7},
            'ANI': 0xE6, 'XRA': {'B': 0xA8, 'C': 0xA9, 'D': 0xAA, 'E': 0xAB, 'H': 0xAC, 'L': 0xAD, 'M': 0xAE, 'A': 0xAF},
            'XRI': 0xEE, 'ORA': {'B': 0xB0, 'C': 0xB1, 'D': 0xB2, 'E': 0xB3, 'H': 0xB4, 'L': 0xB5, 'M': 0xB6, 'A': 0xB7},
            'ORI': 0xF6, 'CMP': {'B': 0xB8, 'C': 0xB9, 'D': 0xBA, 'E': 0xBB, 'H': 0xBC, 'L': 0xBD, 'M': 0xBE, 'A': 0xBF},
            'CPI': 0xFE, 'RLC': 0x07, 'RRC': 0x0F, 'RAL': 0x17, 'RAR': 0x1F,
            'CMA': 0x2F, 'CMC': 0x3F, 'STC': 0x37,
            
            # Branch
            'JMP': 0xC3, 'JNZ': 0xC2, 'JZ': 0xCA, 'JNC': 0xD2, 'JC': 0xDA,
            'JPO': 0xE2, 'JPE': 0xEA, 'JP': 0xF2, 'JM': 0xFA,
            'CALL': 0xCD, 'CNZ': 0xC4, 'CZ': 0xCC, 'CNC': 0xD4, 'CC': 0xDC,
            'CPO': 0xE4, 'CPE': 0xEC, 'CP': 0xF4, 'CM': 0xFC,
            'RET': 0xC9, 'RNZ': 0xC0, 'RZ': 0xC8, 'RNC': 0xD0, 'RC': 0xD8,
            'RPO': 0xE0, 'RPE': 0xE8, 'RP': 0xF0, 'RM': 0xF8,
            
            # Stack
            'PUSH': {'B': 0xC5, 'D': 0xD5, 'H': 0xE5, 'PSW': 0xF5},
            'POP': {'B': 0xC1, 'D': 0xD1, 'H': 0xE1, 'PSW': 0xF1},
            
            # I/O and control
            'IN': 0xDB, 'OUT': 0xD3, 'HLT': 0x76, 'NOP': 0x00,
            'EI': 0xFB, 'DI': 0xF3, 'RIM': 0x20, 'SIM': 0x30,
        }
    
    def parse_value(self, val_str):
        """Parse numeric value (decimal, hex, binary, or label)"""
        val_str = val_str.strip().upper()
        
        # Check labels first
        if val_str in self.labels:
            return self.labels[val_str]
        
        # Hex with 'h' suffix
        if val_str.endswith('H'):
            return int(val_str[:-1], 16)
        
        # Hex with 0x prefix
        if val_str.startswith('0X'):
            return int(val_str, 16)
        
        # Binary
        if val_str.endswith('B'):
            return int(val_str[:-1], 2)
        
        # Character literal
        if val_str.startswith("'") or val_str.startswith('"'):
            return ord(val_str[1])
        
        # Try as decimal
        try:
            return int(val_str)
        except:
            # Return 0 as placeholder for unresolved symbols
            print(f"Warning: Could not resolve '{val_str}', using 0")
            return 0
    
    def emit(self, *bytes_to_emit):
        """Emit bytes to output"""
        for b in bytes_to_emit:
            self.output.append(b & 0xFF)
            self.pc += 1
    
    def assemble_line(self, line):
        """Assemble a single line"""
        original_line = line
        
        # Remove comments
        if ';' in line:
            line = line[:line.index(';')]
        line = line.strip()
        if not line:
            return
        
        # Check for label (but not ':' inside strings!)
        colon_pos = -1
        in_string = False
        quote_char = None
        for i, ch in enumerate(line):
            if ch in ('"', "'") and not in_string:
                in_string = True
                quote_char = ch
            elif ch == quote_char and in_string:
                in_string = False
                quote_char = None
            elif ch == ':' and not in_string:
                colon_pos = i
                break
        
        if colon_pos >= 0 and not line.startswith('\t') and not line.startswith(' '):
            label = line[:colon_pos]
            # Don't update label address here - already done in first pass
            line = line[colon_pos+1:].strip()
            if not line:
                return
        
        # Split into mnemonic and operands, preserving case for operands
        parts_orig = line.split(None, 1)
        if not parts_orig:
            return
        
        mnemonic_orig = parts_orig[0]
        operands_orig = parts_orig[1] if len(parts_orig) > 1 else ''
        
        # Uppercase for matching
        parts = [mnemonic_orig.upper()]
        if operands_orig:
            parts.append(operands_orig)  # Keep original case for operands!
        
        mnemonic = parts[0]
        operands = parts[1] if len(parts) > 1 else ''
        
        # Skip EQU early (handle as directive)
        if operands:
            # Normalize whitespace and check if it's an EQU line
            ops_check = ' '.join(operands.split()).upper()
            if ops_check.startswith('EQU ') or ops_check == 'EQU':
                return  # Already handled in first pass
        
        # Directives
        if mnemonic == 'ORG':
            val_str = operands.strip().upper()
            if val_str.endswith('H'):
                self.org = int(val_str[:-1], 16)
            elif val_str.startswith('0X'):
                self.org = int(val_str, 16)
            else:
                self.org = int(val_str)
            self.pc = self.org
            # Pad output to reach this address
            while len(self.output) < self.org:
                self.output.append(0)
            return
        elif mnemonic == 'EQU':
            return  # Already handled in first pass
        elif mnemonic == 'DB':
            # Data bytes - parse from ORIGINAL line to preserve case
            original_operands = parts[1] if len(parts) > 1 else ''
            
            # Parse items carefully to preserve strings
            items = []
            current = ''
            in_string = False
            quote_char = None
            
            for ch in original_operands:
                if ch in ('"', "'") and not in_string:
                    in_string = True
                    quote_char = ch
                    current += ch
                elif ch == quote_char and in_string:
                    in_string = False
                    current += ch
                    quote_char = None
                elif ch == ',' and not in_string:
                    if current.strip():
                        items.append(current.strip())
                    current = ''
                else:
                    current += ch
            
            if current.strip():
                items.append(current.strip())
            
            for item in items:
                if item.startswith('"') or item.startswith("'"):
                    # String literal - preserve case!
                    string = item[1:-1] if len(item) > 1 else ''
                    for ch in string:
                        self.emit(ord(ch))
                else:
                    # Numeric value
                    self.emit(self.parse_value(item))
            return
        elif mnemonic == 'DW':
            # Data word
            val = self.parse_value(operands)
            self.emit(val & 0xFF, (val >> 8) & 0xFF)
            return
        elif mnemonic == 'END':
            return
        
        # Instructions
        if mnemonic not in self.opcodes:
            print(f"Warning: Unknown mnemonic {mnemonic}")
            return
        
        opcode_data = self.opcodes[mnemonic]
        
        # No operand instructions
        if isinstance(opcode_data, int):
            if mnemonic in ['IN', 'OUT']:
                self.emit(opcode_data, self.parse_value(operands))
            elif mnemonic in ['ADI', 'ACI', 'SUI', 'SBI', 'ANI', 'XRI', 'ORI', 'CPI']:
                # Immediate byte instructions
                self.emit(opcode_data, self.parse_value(operands))
            elif mnemonic in ['JMP', 'JNZ', 'JZ', 'JNC', 'JC', 'JPO', 'JPE', 'JP', 'JM',
                             'CALL', 'CNZ', 'CZ', 'CNC', 'CC', 'CPO', 'CPE', 'CP', 'CM',
                             'STA', 'LDA', 'SHLD', 'LHLD']:
                addr = self.parse_value(operands)
                self.emit(opcode_data, addr & 0xFF, (addr >> 8) & 0xFF)
            else:
                self.emit(opcode_data)
        # Instructions with register operands
        elif isinstance(opcode_data, dict):
            # Split operands properly
            parts = [p.strip() for p in operands.split(',')]
            reg = parts[0].upper() if parts else ''
            
            if reg in opcode_data:
                opcode = opcode_data[reg]
                if mnemonic in ['MVI', 'ADI', 'ACI', 'SUI', 'SBI', 'ANI', 'XRI', 'ORI', 'CPI']:
                    # Has immediate byte
                    if len(parts) >= 2:
                        self.emit(opcode, self.parse_value(parts[1]))
                    else:
                        self.emit(opcode)
                elif mnemonic == 'LXI':
                    # Has immediate word
                    if len(parts) >= 2:
                        val = self.parse_value(parts[1])
                        self.emit(opcode, val & 0xFF, (val >> 8) & 0xFF)
                    else:
                        self.emit(opcode)
                else:
                    self.emit(opcode)
            else:
                # Try without spaces for MOV instructions
                operands_clean = operands.replace(' ', '').upper()
                if operands_clean in opcode_data:
                    self.emit(opcode_data[operands_clean])
                else:
                    print(f"Warning: Unknown operand for {mnemonic}: {operands}")
    
    def first_pass(self, lines):
        """First pass: collect labels and EQU definitions"""
        temp_pc = 0
        debug = False  # Set to True to debug
        
        for line_num, line in enumerate(lines, 1):
            if line_num == 195:
                debug = True  # Enable debug at MSG_BANNER
            original_line = line
            if ';' in line:
                line = line[:line.index(';')]
            line = line.strip()
            if not line:
                continue
            
            # Handle EQU (must be a proper EQU statement, not just containing the word)
            parts = re.split(r'\s+', line, maxsplit=2)
            if len(parts) >= 3 and parts[1].upper() == 'EQU':
                label = parts[0].upper()
                value_str = parts[2]
                try:
                    # Parse the value - handle hex properly
                    if value_str.endswith('h') or value_str.endswith('H'):
                        val = int(value_str[:-1], 16)
                    elif value_str.startswith('0x'):
                        val = int(value_str, 16)
                    else:
                        val = int(value_str)
                    self.labels[label] = val
                except:
                    pass
                continue
            
            # Handle ORG
            if line.upper().startswith('ORG'):
                parts = line.split(None, 1)
                if len(parts) > 1:
                    val_str = parts[1].strip().upper()
                    if val_str.endswith('H'):
                        temp_pc = int(val_str[:-1], 16)
                    elif val_str.startswith('0X'):
                        temp_pc = int(val_str, 16)
                    else:
                        temp_pc = int(val_str)
                continue
            
            # Handle labels on their own line or before instruction
            # But don't confuse ':' inside strings as labels!
            colon_pos = -1
            in_string = False
            quote_char = None
            for i, ch in enumerate(line):
                if ch in ('"', "'") and not in_string:
                    in_string = True
                    quote_char = ch
                elif ch == quote_char and in_string:
                    in_string = False
                    quote_char = None
                elif ch == ':' and not in_string:
                    colon_pos = i
                    break
            
            if colon_pos >= 0:
                label_part = line[:colon_pos]
                if not label_part.startswith('\t') and not label_part.startswith(' '):
                    label = label_part.strip().upper()
                    self.labels[label] = temp_pc
                    line = line[colon_pos+1:].strip()
                    if not line:
                        continue
            
            # Estimate instruction size for PC tracking
            # Split but keep operands in original case
            parts_split = line.split(None, 1)
            if not parts_split:
                continue
            
            mnemonic = parts_split[0].upper()
            operands_for_size = parts_split[1] if len(parts_split) > 1 else ''
            
            # Skip directives that don't emit code
            if mnemonic in ['END', 'CPU']:
                continue
                
            if mnemonic == 'DB':
                # Count bytes in DB directive - use original case operands!
                if operands_for_size:
                    # Parse comma-separated items
                    items = []
                    current = ''
                    in_string = False
                    quote_char = None
                    
                    for ch in operands_for_size:
                        if ch in ('"', "'") and not in_string:
                            in_string = True
                            quote_char = ch
                            current += ch
                        elif ch == quote_char and in_string:
                            in_string = False
                            current += ch
                            quote_char = None
                        elif ch == ',' and not in_string:
                            if current.strip():
                                items.append(current.strip())
                            current = ''
                        else:
                            current += ch
                    
                    if current.strip():
                        items.append(current.strip())
                    
                    for item in items:
                        if item.startswith('"') or item.startswith("'"):
                            # String literal - count characters (preserving case!)
                            string = item[1:-1] if len(item) > 1 else ''
                            temp_pc += len(string)
                        else:
                            # Single byte value
                            temp_pc += 1
            elif mnemonic == 'DW':
                temp_pc += 2
            elif mnemonic in ['MVI', 'ADI', 'ACI', 'SUI', 'SBI', 'ANI', 'XRI', 'ORI', 'CPI', 'IN', 'OUT']:
                temp_pc += 2
            elif mnemonic in ['LXI', 'JMP', 'JNZ', 'JZ', 'JNC', 'JC', 'JPO', 'JPE', 'JP', 'JM',
                             'CALL', 'CNZ', 'CZ', 'CNC', 'CC', 'CPO', 'CPE', 'CP', 'CM',
                             'STA', 'LDA', 'SHLD', 'LHLD']:
                temp_pc += 3
            elif mnemonic not in ['ORG', 'EQU']:
                # All other instructions are 1 byte
                if debug and line_num < 200:
                    print(f"L{line_num}: {mnemonic} -> PC 0x{temp_pc:04X} + 1")
                temp_pc += 1
    
    def assemble(self, source_file, output_file):
        """Assemble the source file"""
        with open(source_file, 'r') as f:
            lines = f.readlines()
        
        # First pass: collect labels and constants
        self.first_pass(lines)
        
        # Second pass: assemble
        for line in lines:
            try:
                self.assemble_line(line)
            except Exception as e:
                print(f"Error on line: {line.strip()}")
                print(f"  {e}")
        
        # Write output
        with open(output_file, 'wb') as f:
            f.write(bytes(self.output))
        
        print(f"Assembled {len(self.output)} bytes to {output_file}")
        return True

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: assemble.py <input.asm> <output.bin>")
        sys.exit(1)
    
    assembler = Assembler8085()
    try:
        assembler.assemble(sys.argv[1], sys.argv[2])
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
