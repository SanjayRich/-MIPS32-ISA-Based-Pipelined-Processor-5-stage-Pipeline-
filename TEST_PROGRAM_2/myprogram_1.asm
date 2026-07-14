
ADDI R1, R0, 120
OR   R7, R7, R7  # dummy instruction to avoid hazard
LW   R2, 0(R1)
OR   R7, R7, R7  # dummy instruction to avoid hazard
ADDI R2, R2, 45
OR   R7, R7, R7  # dummy instruction to avoid hazard
SW   R2, 1(R1)
HLT
