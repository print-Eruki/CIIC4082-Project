FILE = ""

def read_bin(file):
    with open(file=file, mode="rb") as f:
            b = f.read(32) 
            map_bytes = []
            while b:
                map_bytes.append(b)
                b = f.read(32)
            #get the atributes table, which are the last
            attributes_table = map_bytes[-2:]
            #eliminate the atribute tables from the map
            map_bytes.pop()
            map_bytes.pop()
            map_bytes = clean_map(map_bytes)
            print(map_bytes)
            return (map_bytes, attributes_table)
    
def clean_map(matrix):
     #eliminate every other row 
    matrix = matrix[::2]
     #eliminate every other column
    for i in range(len(matrix)):
        matrix[i] = matrix[i][::2]

    return matrix
    
def package(map_bin):
    packaging = []
    for i in range(len(map_bin)):
        convert = []
        for j in range(0,16,2):
            num = map_bin[i][j] << 2 #shifting to the left two bits
            num |= map_bin[i][j+1] #adding the number into the extra bits
            convert.append(hex(num))
        packaging.append(convert)
    
    return packaging

 

def create_asm(package):    
    asm = [f"{FILE[:-4]}:"]
    for row in package:
        asm_row = ','.join([f'${row[i][2:] + row[i+1][2:]}' for i in range(0,len(row)-1,2)])
        asm.append('    .byte ' + asm_row)
    
    with open(f"{FILE[:-4]}.asm", "w")as f:
        f.write('\n'.join(asm))

if __name__ == "__main__":
    from sys import argv   
    if len(argv) > 1:
        FILE = argv[1]
        create_asm(package(read_bin(FILE)[0]))
    else:
        FILE = "Deliverable4/second_map_part1.bin"
        create_asm(package(read_bin(FILE)[0]))
