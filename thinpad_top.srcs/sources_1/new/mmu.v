module mmu(
    // from if
    input wire                  clk,
    input wire                  if_ce_i,
    input wire[`InstAddrBus]	if_addr_i,  // pc

    //from mem
    input wire[`RegBus]         mem_addr_i,
    input wire                  mem_we_i,
    input wire[`RegBus]         mem_data_i,
    input wire                  mem_ce_i,
    input wire[3:0]             mem_sel_i,

    // to mem
	output wire[31:0]           data_o,
    // to if-id
    output wire[31:0]           inst_o,

    // ** inout with BaseRam
    inout wire[31:0]            base_ram_data, //BaseRAM数据，低8位与CPLD串口控制器共享

    // output to BaseRAM
    output wire[19:0]           base_ram_addr, //BaseRAM地址
    output reg                  base_ram_ce_n, //BaseRAM片选，低有效
    output reg                  base_ram_oe_n, //BaseRAM读使能，低有效
    output reg                  base_ram_we_n, //BaseRAM写使能，低有效
    output reg[3:0]             base_ram_be_n,  //BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0

    // inout with ExtRAM
    inout wire[31:0]            ext_ram_data,  //ExtRAM数据

    // to ExtRAM
    output wire[19:0]           ext_ram_addr,  //ExtRAM地址
    output reg                  ext_ram_ce_n,  //ExtRAM片选，低有效
    output reg                  ext_ram_oe_n,  //ExtRAM读使能，低有效
    output reg                  ext_ram_we_n,  //ExtRAM写使能，低有效
    output reg[3:0]             ext_ram_be_n,  //ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0

    //CPLD串口控制器信号
    output reg                  uart_rdn,         //读串口信号，低有效
    output reg                  uart_wrn,         //写串口信号，低有效

    input wire                  uart_dataready,    //串口数据准备好
    input wire                  uart_tsre,         //数据发送完毕标志

    // to ctrl
    output reg                  stallreq_o
);


reg[31:0] inner_base_ram_data;
reg[31:0] inner_ext_ram_data;
wire mem_access_base_ram = (mem_ce_i == `ChipEnable) && (mem_addr_i[23:0] < 24'h400000);  // if memory is accessing baseram ?
wire mem_access_uart_data = (mem_ce_i == `ChipEnable) && (mem_addr_i == 32'hBFD003F8); // serial data
wire mem_access_uart_stat = (mem_ce_i == `ChipEnable) && (mem_addr_i == 32'hBFD003FC); // serial stat
wire mem_access_ext_ram = (mem_ce_i == `ChipEnable) && (mem_addr_i[23:0] >= 24'h400000) && mem_access_uart_data==1'b0 && mem_access_uart_stat==1'b0; // if memory is accessing extram ?


assign base_ram_data = inner_base_ram_data;
assign ext_ram_data = inner_ext_ram_data; 

assign inst_o = if_ce_i == `ChipEnable ? base_ram_data : `ZeroWord;

assign data_o = mem_access_uart_stat ? {uart_dataready,uart_tsre} :
                mem_access_uart_data ? {32{ base_ram_data[7:0] }} :
                mem_access_ext_ram ? ext_ram_data :
                mem_access_base_ram ? base_ram_data : `ZeroWord;  // if disable


assign ext_ram_addr = mem_addr_i[21:2]; // minus 0x80400000 then div 4

assign base_ram_addr = mem_access_base_ram ? 
                       mem_addr_i[21:2] :  // minus 0x80000000 then div 4
                       if_addr_i[21:2];  // pc access baseram

always @(*) begin // handle ext ram alone

    ext_ram_ce_n <= `RAMDisable;
    ext_ram_oe_n <= `RAMDisable;
    ext_ram_we_n <= `RAMDisable;
    ext_ram_be_n <= 4'b0000;
    inner_ext_ram_data <= 32'bz;

    // if (mem_access_ext_ram) begin
    //     ext_ram_ce_n <= `RAMEnable;
    //     // read or write?
    //     if (mem_we_i == `WriteDisable) begin // read ext ram
    //         ext_ram_we_n <= `RAMDisable;
    //         ext_ram_oe_n <= `RAMEnable;
    //         inner_ext_ram_data <= 32'bz;
    //     end else begin // write ext ram
    //         // ext_ram_we_n <= `RAMEnable;
    //         ext_ram_be_n <= mem_sel_i;
    //         ext_ram_we_n <= clk;   // * write concurrently with clk
    //         ext_ram_oe_n <= `RAMDisable;
    //         inner_ext_ram_data <= mem_data_i;
    //     end
    // end
end

always @(*) begin // ** handle bus conflicts here 

    stallreq_o <= `StallDisable;
    base_ram_ce_n <= `RAMDisable;
    base_ram_we_n <= `RAMDisable;
    base_ram_oe_n <= `RAMDisable;
    inner_base_ram_data <= 32'bz;
    uart_rdn <= `UARTDisable;
    uart_wrn <= `UARTDisable;
    base_ram_be_n <= 4'b0000;

    if (mem_access_base_ram) begin
        // !!
        // stallreq_o <= `StallEnable;
        // base_ram_ce_n <= `RAMEnable;
        // if (mem_we_i == `WriteDisable) begin // read base ram
        //     base_ram_we_n <= `RAMDisable;
        //     base_ram_oe_n <= `RAMEnable;
        //     inner_base_ram_data <= 32'bz;
        // end else begin  // write base ram
        //     // base_ram_we_n <= `RAMEnable;
        //     base_ram_be_n <= mem_sel_i;
        //     base_ram_we_n <= clk;   // * write concurrently with clk
        //     base_ram_oe_n <= `RAMDisable;
        //     inner_base_ram_data <= mem_data_i;
        // end
    end else if (mem_access_uart_data) begin
        // !!
        // stallreq_o <= `StallEnable;
        // if (mem_we_i == `WriteDisable) begin // read uart
        //     uart_rdn <= clk;  // * read concurrently with clk
        //     uart_wrn <= `UARTDisable;
        //     inner_base_ram_data <= 32'bz;
        // end else begin
        //     uart_rdn <= `UARTDisable;
        //     uart_wrn <= clk;  // * write concurrently with clk
        //     inner_base_ram_data <= mem_data_i;
        // end
        // uart stat already returned, no need to stall
    end else if (if_ce_i == `ChipEnable) begin // read pc inst
        // ok
        base_ram_ce_n <= `RAMEnable;
        base_ram_we_n <= `RAMDisable;
        base_ram_oe_n <= `RAMEnable;
        // base ram addr already returned
    end
end


endmodule // inst_ram