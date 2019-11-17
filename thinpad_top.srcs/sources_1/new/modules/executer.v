module ex(
    input   wire  rst,
	
    // signals from id
    input wire[`AluOpBus]         aluop_i,
    input wire[`AluSelBus]        alusel_i,
    input wire[`RegBus]           reg1_i,
    input wire[`RegBus]           reg2_i,
    input wire[`RegAddrBus]       wd_i,
    input wire                    wreg_i,
    
    // propagate result to mem (and forward to id)
    output reg                    wreg_o,
    output reg[`RegAddrBus]       wd_o,
    output reg[`RegBus]           wdata_o
);

reg[`RegBus]    logic_res;
reg[`RegBus]    shift_res;
reg[`RegBus]    move_res;
reg[`RegBus]    arith_res;
reg[`RegBus]    load_res;

wire[`RegBus]   sum_res = reg1_i + reg2_i;
// assign          sum_res = reg1_i + reg2_i;

always @ * begin    // perform logical computation
    
    if (rst == `RstEnable) begin
        logic_res <= `ZeroWord;
    end else begin
        case (aluop_i)      // ** case various alu operations **

            `EXE_OR_OP: logic_res <= reg1_i | reg2_i;

            `EXE_AND_OP: logic_res <= reg1_i & reg2_i;
            
            `EXE_XOR_OP: logic_res <= reg1_i ^ reg2_i;

            default: logic_res <= `ZeroWord;
            
        endcase
    end

end

always @ * begin    // perform shift computation
    
    if (rst == `RstEnable) begin
        shift_res <= `ZeroWord;
    end else begin
        case (aluop_i)      // ** case various alu operations **

            `EXE_SLL_OP: shift_res <= reg1_i << reg2_i[4:0]; // shift less than 32 bits

            `EXE_SRL_OP: shift_res <= reg1_i >> reg2_i[4:0];

            default: shift_res <= `ZeroWord;
            
        endcase
    end

end

always @ * begin    // perform arithmetic computation
    
    if (rst == `RstEnable) begin
        arith_res <= `ZeroWord;
    end else begin
        case (aluop_i)      // ** case various alu operations **

            `EXE_ADDU_OP: arith_res <= sum_res;

            `EXE_CLZ_OP: begin: loop // count leading zeros in reg_1
                arith_res = `ZeroWord;
                for (integer i = 31; i >= 0; i = i - 1)
                    if (reg1_i[i] == 1'b0)
                        arith_res = 32 - i;
                    else
                        disable loop; // break
                // for (integer i = 32; i >= 0; i = i - 1)
                    // if (reg1_i >> i == `ZeroWord)
                        // arith_res = 32 - i;
            end

            default: arith_res <= `ZeroWord;
            
        endcase
    end

end

always @ * begin    // generate write signal
    if (rst == `RstEnable) begin      //  TODO: block this case or not?
        wd_o <= `NOPRegAddr;
        wreg_o <= `WriteDisable;
        wdata_o <= `ZeroWord;
    end else begin
        wd_o <= wd_i;
        wreg_o <= wreg_i;
        case (alusel_i)     // alu result selection

            `EXE_RES_LOGIC: wdata_o <= logic_res; 

            `EXE_RES_SHIFT: wdata_o <= shift_res;

            `EXE_RES_MOVE: wdata_o <= move_res;

            `EXE_RES_ARITH: wdata_o <= arith_res;

            `EXE_RES_LOAD: wdata_o <= load_res;

            default: wdata_o <= `ZeroWord;

        endcase
    end
end


endmodule // ex