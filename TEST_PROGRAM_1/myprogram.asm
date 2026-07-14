# MIPS32 Assembly Program

ADDI R1, R0, 10     # R1 = 10
ADDI R2, R0, 20     # R2 = 20
ADDI R3, R0, 25     # R3 = 25
OR   R7, R7, R7
OR   R7, R7, R7
ADD  R4, R1, R2     # R4 = R1 + R2 = 30
OR   R7, R7, R7
ADD  R5, R4, R3     # R5 = R4 + R3 = 55

HLT                 # Halt execution
