import sys

NUM_GPR = 8
opcodes = ['END', 'ADD', 'SUB', 'MUL', 'DV2', 'LDM', 'STM', 'MVR', 'MVI', 'BEQ', 'BLT']
registers = ['0', '1', 'DI', 'IM', 'AR', 'JR'] + [f'R{i}' for i in range(NUM_GPR)]

'''
Setup
'''
in_filename = sys.argv[1]
out_filename = in_filename.replace('assembly', 'mcode')

input_lines = []
with open(in_filename, "r") as f:
    input_lines = f.readlines()

program = []
jump_labels = {}
variables = {}
iram_addr = 0

'''
Read & parse assembly, identify jump labels
'''
for i, line in enumerate(input_lines):
    ins = line.split("#")[0] # discard comments

    if ins.isspace() or ins == "":
        continue # skip blank input_lines
    
    '''
    Remove tabs, commas, newline, extra spaces
    '''
    ins = ins.strip().replace("\t", "").replace(",", "")
    ins = ' '.join(ins.split())
    ins = ins.split()

    '''
    Remove & store jump labels
    '''
    if ins[0][0] == "$":
        label, *ins = ins
        jump_labels[label.upper()] = iram_addr

    if ins[0][0] == "`":
        reg, var = ins
        variables[var] = reg[1:]
        continue
    else:
        for i, word in enumerate(ins):
            if word in variables.keys():
                ins[i] = variables[word]

    '''
    Add line number (for debugging), and convert all to uppercase
    '''
    ins = [i+1] + [word.upper() for word in ins]

    program += [ins]
    iram_addr += 1

    print(ins)

'''
Converts a list of registers to binary
'''
def reg_to_bin(operands, binary, header):
    global registers
    for operand in operands:
        assert operand in registers, f"{header} Invalid register '{operand}'. Valid:{registers}"
        binary += f"{registers.index(operand):04b} "
    return binary


'''
Check Syntax Errors & Translate to Machine code
'''
with open(out_filename, "w") as f:
    for ins in program:

        binary = ""
        line_no, opcode, *operands = ins 
        header = f"Syntax error, line:{line_no} ->"
        assert opcode in opcodes, f"{header} Invalid opcode '{opcode}'. Valid:{opcodes}"

        binary += f"{opcodes.index(opcode):04b} "
        
        if opcode in ['ADD', 'SUB', 'MUL']:
            assert len(operands) == 3, f"{header} Need 3 operands for {opcode}"
            binary = reg_to_bin(operands, binary, header)

        if opcode in ['BEQ', 'BLT']:
            binary += f"{0:04b} "
            assert len(operands) == 2, f"{header} Need 2 operands for {opcode}"
            binary = reg_to_bin(operands, binary, header)

        if opcode in ['MVR', 'DV2']:
            assert len(operands) == 2, f"{header} Need 2 operands for {opcode}"
            binary = reg_to_bin(operands, binary, header)
            binary += f"{0:04b} "

        if opcode =='MVI':
            assert len(operands) == 2, f"{header} Need 2 operands for {opcode}"
            im = operands.pop()
            binary = reg_to_bin(operands, binary, header)

            if not im.isnumeric():
                assert im in jump_labels.keys(), f"{header} Invalid jump label '{im}'. Available:{jump_labels}"
                binary += f"{0:04b} {jump_labels[im]:04b} "            
            else:
                im = int(im)
                im = im if im >=0 else im + 256 # 2's complement
                binary += f"{im // 16:04b} {im % 16:04b} "

        if opcode == 'STM':
            assert len(operands) == 1, f"{header} Need 1 operand for {opcode}"
            binary += f"{0:04b} "
            binary = reg_to_bin(operands, binary, header)
            binary += f"{0:04b} "

        if opcode in ['END', 'LDM']:
            binary += f"{0:04b} {0:04b} {0:04b}"

        f.write(binary + '\n')