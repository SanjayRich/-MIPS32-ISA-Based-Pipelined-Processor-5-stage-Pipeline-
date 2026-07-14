#!/usr/bin/env python3
"""
MIPS32 Subset Assembler → .mem file generator
==============================================
Engineer : SANJAY ELAVARASAN KARTHIKEYAN (VIT Vellore)
Tool     : Icarus Verilog compatible $readmemh format

Supported Instructions (14):
  R-type : ADD, SUB, AND, OR, SLT, MUL     (rd, rs, rt)
  I-type : ADDI, SUBI, SLTI                (rt, rs, imm)
           LW                              (rt, rs, imm)  or  rt, imm(rs)
           SW                              (rt, rs, imm)  or  rt, imm(rs)
           BEQZ, BNEQZ                     (rs, label/imm)
  Special: HLT, NOP

Instruction Encoding (32-bit):
  R-type : [31:26] opcode | [25:21] rs | [20:16] rt | [15:11] rd | [10:0] unused
  I-type : [31:26] opcode | [25:21] rs | [20:16] rt | [15:0]  imm (sign-extended)

Usage:
  python3 mips_to_mem.py program.asm              → program.mem
  python3 mips_to_mem.py program.asm -o out.mem   → out.mem
  python3 mips_to_mem.py --example                → example_program.mem
"""

import sys, os, re, argparse

# ── Opcodes (match TOP_MIPS parameters exactly) ──────────────
OPCODES = {
    'ADD'  : 0b000000,
    'SUB'  : 0b000001,
    'AND'  : 0b000010,
    'OR'   : 0b000011,
    'SLT'  : 0b000100,
    'MUL'  : 0b000101,
    'LW'   : 0b001000,
    'SW'   : 0b001001,
    'ADDI' : 0b001010,
    'SUBI' : 0b001011,
    'SLTI' : 0b001100,
    'BNEQZ': 0b001101,
    'BEQZ' : 0b001110,
    'HLT'  : 0b111111,
}

R_TYPE = {'ADD','SUB','AND','OR','SLT','MUL'}
I_TYPE = {'ADDI','SUBI','SLTI','LW','SW','BEQZ','BNEQZ'}


class Assembler:
    def __init__(self):
        self.labels = {}
        self.words  = []   # list of (addr, hex_word, original_line)
        self.errors = []

    def parse_reg(self, t):
        t = t.strip().rstrip(',').upper()
        if t.startswith('$'): t = 'R' + t[1:]
        if t.startswith('R') and t[1:].isdigit():
            r = int(t[1:])
            if 0 <= r <= 31: return r
        raise ValueError(f"Bad register: '{t}'")

    def parse_imm(self, t, addr=0):
        t = t.strip().rstrip(',')
        # label reference
        if t.upper() in self.labels:
            return self.labels[t.upper()] - (addr + 1)  # PC-relative
        try:
            v = int(t, 16) if t.startswith('0x') or t.startswith('0X') else int(t)
        except:
            raise ValueError(f"Bad immediate: '{t}'")
        if v < 0: v = v & 0xFFFF
        return v & 0xFFFF

    def clean(self, line):
        return re.sub(r'[#;].*', '', line).strip()

    def first_pass(self, lines):
        addr = 0
        for line in lines:
            line = self.clean(line)
            if not line: continue
            if ':' in line:
                lbl, rest = line.split(':', 1)
                self.labels[lbl.strip().upper()] = addr
                line = rest.strip()
                if not line: continue
            tok = line.split()[0].upper()
            if tok in OPCODES or tok in ('NOP',):
                addr += 1

    def second_pass(self, lines):
        addr = 0
        for lineno, line in enumerate(lines, 1):
            orig = line.strip()
            line = self.clean(line)
            if not line: continue
            if ':' in line:
                line = line.split(':', 1)[1].strip()
                if not line: continue
            tokens = line.split()
            if not tokens: continue
            mnem = tokens[0].upper()
            ops  = tokens[1:]
            try:
                w = self.encode(mnem, ops, addr, lineno)
                self.words.append((addr, w, orig))
                addr += 1
            except Exception as e:
                self.errors.append(f"Line {lineno}: {e}  →  '{orig}'")

    def encode(self, mnem, ops, addr, lineno):
        if mnem == 'NOP':
            return 0x00000000

        if mnem == 'HLT':
            return OPCODES['HLT'] << 26

        if mnem not in OPCODES:
            raise ValueError(f"Unknown instruction '{mnem}'")

        op = OPCODES[mnem]

        # ── R-type: rd, rs, rt ───────────────────────────────
        if mnem in R_TYPE:
            if len(ops) < 3: raise ValueError(f"{mnem} needs rd, rs, rt")
            rd = self.parse_reg(ops[0])
            rs = self.parse_reg(ops[1])
            rt = self.parse_reg(ops[2])
            return (op<<26)|(rs<<21)|(rt<<16)|(rd<<11)

        # ── LW / SW: rt, imm(rs)  or  rt, rs, imm ──────────
        if mnem in ('LW', 'SW'):
            rt = self.parse_reg(ops[0])
            rest = ''.join(ops[1:])
            m = re.match(r'(-?\w+)\((\w+)\)', rest)
            if m:
                imm = self.parse_imm(m.group(1), addr)
                rs  = self.parse_reg(m.group(2))
            else:
                rs  = self.parse_reg(ops[1])
                imm = self.parse_imm(ops[2], addr) if len(ops)>2 else 0
            return (op<<26)|(rs<<21)|(rt<<16)|(imm & 0xFFFF)

        # ── ADDI / SUBI / SLTI: rt, rs, imm ─────────────────
        if mnem in ('ADDI','SUBI','SLTI'):
            if len(ops) < 3: raise ValueError(f"{mnem} needs rt, rs, imm")
            rt  = self.parse_reg(ops[0])
            rs  = self.parse_reg(ops[1])
            imm = self.parse_imm(ops[2], addr)
            return (op<<26)|(rs<<21)|(rt<<16)|(imm & 0xFFFF)

        # ── BEQZ / BNEQZ: rs, label ──────────────────────────
        if mnem in ('BEQZ','BNEQZ'):
            if len(ops) < 2: raise ValueError(f"{mnem} needs rs, label")
            rs  = self.parse_reg(ops[0])
            imm = self.parse_imm(ops[1], addr)
            return (op<<26)|(rs<<21)|(0<<16)|(imm & 0xFFFF)

        raise ValueError(f"Unhandled '{mnem}'")

    def assemble(self, source):
        lines = source.splitlines()
        self.first_pass(lines)
        self.second_pass(lines)

    def to_mem(self):
        """$readmemh compatible .mem file"""
        out = []
        out.append("// MIPS32 Subset — .mem file")
        out.append("// Load: $readmemh(\"program.mem\", MIPS.Mem);")
        out.append("// Generated by mips_to_mem.py")
        out.append("")
        for addr, word, orig in self.words:
            out.append(f"{word:08X}  // [{addr:04X}] {orig}")
        return '\n'.join(out)

    def print_listing(self):
        print()
        print("="*70)
        print("  ADDR   HEX        BINARY                           INSTRUCTION")
        print("-"*70)
        for addr, word, orig in self.words:
            b = f"{word:032b}"
            bfmt = f"{b[0:6]} {b[6:11]} {b[11:16]} {b[16:32]}"
            print(f"  {addr:04X}   {word:08X}   {bfmt}   {orig}")
        print("-"*70)
        if self.labels:
            print("  Labels:")
            for name, a in sorted(self.labels.items(), key=lambda x: x[1]):
                print(f"    {name:<20} -> {a:04X}")
        print(f"  Total: {len(self.words)} instructions")
        print("="*70)
        if self.errors:
            print("\n  ERRORS:")
            for e in self.errors: print(f"    ✗ {e}")
        else:
            print("  ✓ Assembly successful")
        print()


# ── Built-in example (matches your test output) ──────────────
EXAMPLE = """\
# Test Program 1 — Add three numbers
# R1=10, R2=20, R3=30 (already in register file from testbench init)
# But initializing via ADDI to be self-contained:

        ADDI  R1, R0, 10      # R1 = 10
        ADDI  R2, R0, 20      # R2 = 20
        ADDI  R3, R0, 5       # R3 = 5  (not 30 — testbench init sets R3=3, we override)
        ADD   R4, R1, R2      # R4 = R1 + R2 = 30
        ADD   R5, R4, R2      # R5 = R4 + R2 = 50  (or use R3 for 55)
        HLT
"""

# Your exact test program (matches R0=0,R1=10,R2=20,R3=25,R4=30,R5=55 output)
EXAMPLE_EXACT = """\
# Test Program 1 — Exact match to your simulation output
# Testbench initializes Reg[k]=k, so R1=1,R2=2... we override with ADDI
# Output: R1=10, R2=20, R3=25, R4=30, R5=55

        ADDI  R1, R0, 10      # R1 = 10
        ADDI  R2, R0, 20      # R2 = 20
        ADDI  R3, R0, 25      # R3 = 25
        ADD   R4, R1, R2      # R4 = 10 + 20 = 30
        ADD   R5, R1, R4      # R5 = 10 + 30 + 15... 
        ADD   R5, R4, R3      # R5 = 30 + 25 = 55
        HLT
"""


def main():
    parser = argparse.ArgumentParser(
        description='MIPS32 14-Instruction Subset Assembler → .mem file',
        epilog='Example: python3 mips_to_mem.py myprogram.asm'
    )
    parser.add_argument('input', nargs='?', help='Input .asm file')
    parser.add_argument('-o', '--output', help='Output .mem filename')
    parser.add_argument('--example', action='store_true', help='Assemble built-in example')
    args = parser.parse_args()

    if args.example:
        source   = EXAMPLE_EXACT
        out_name = args.output or 'program_1.mem'
        print("\nAssembling built-in example program...")
        print(source)
    elif args.input:
        if not os.path.exists(args.input):
            print(f"Error: '{args.input}' not found"); sys.exit(1)
        with open(args.input) as f:
            source = f.read()
        base     = os.path.splitext(args.input)[0]
        out_name = args.output or (base + '.mem')
    else:
        parser.print_help()
        print("\nTip: Run with --example to generate program_1.mem")
        sys.exit(0)

    asm = Assembler()
    asm.assemble(source)
    asm.print_listing()

    if asm.errors:
        print(f"Assembly failed — {len(asm.errors)} error(s)\n")
        sys.exit(1)

    with open(out_name, 'w') as f:
        f.write(asm.to_mem())

    print(f"  ✓ Written to: {out_name}")
    print(f"    Load in testbench: $readmemh(\"{out_name}\", MIPS.Mem);\n")


if __name__ == '__main__':
    main()
