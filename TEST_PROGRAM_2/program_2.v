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

        $readmemh("program_2.mem", MIPS.Mem);
        MIPS.Mem[120] = 85;

        MIPS.HALTED = 0;
        MIPS.PC = 0;
        MIPS.TAKEN_BRANCH = 0;

        

        
        #500 $display("Mem[120]: %4d \nMem[121]: %4d", MIPS.Mem[120], MIPS.Mem[121]);

    end

    initial begin
        $dumpfile("Mips.vcd");
        $dumpvars(0, test_mips);

        #600 $finish;
    end

endmodule

