//Add three numbers 10, 20 and 30 stored in processor registers.  

//The steps:  

// 1) Initialize register R1 with 10.  

// 2) Initialize register R2 with 20.  

// 3)Initialize register R3 with 30.  

// 4) Add the three numbers and store the sum in R4, R5.

module test_mips;

    reg clk1, clk2;
    integer k;

    TOP_MIPS MIPS(clk1, clk2);

    // Two-phase clock generation
    initial begin
        clk1 = 0;
        clk2 = 0;

        repeat (20)
        begin
            #5 clk1 = 1;
            #5 clk1 = 0;
            #5 clk2 = 1;
            #5 clk2 = 0;
        end
    end

    // Initialize Registers
    initial begin
        for(k = 0; k < 31; k = k + 1)
            MIPS.Reg[k] = k;
    end

    // Load Program
    initial begin

        $readmemh("program_1.mem", MIPS.Mem);

        MIPS.HALTED = 0;
        MIPS.PC = 0;
        MIPS.TAKEN_BRANCH = 0;

        #280

        for(k = 0; k < 6; k = k + 1)
            $display("R%1d = %2d", k, MIPS.Reg[k]);

    end

    initial begin
        $dumpfile("Mips.vcd");
        $dumpvars(0, test_mips);

        #300
        $finish;
    end

endmodule

