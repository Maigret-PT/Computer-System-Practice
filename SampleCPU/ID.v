`include "lib/defines.vh"
module ID(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,  //stall
    
    output wire stallreq,

    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,  //receive "IF to ID"




    input wire ex_write_en,              //EX write enable
    input wire [4:0] ex_write_address,   //5bits
    input wire [31:0] ex_write_data,     //32bits
    

    input wire mem_write_en,             //MEM write enable
    input wire [4:0] mem_write_address,  //5bits
    input wire [31:0] mem_write_data,    //32bits




    input wire [31:0] inst_sram_rdata,

    input wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,  //Write Back

    

    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,  //output "ID to EX"

    output wire [`BR_WD-1:0] br_bus 
);

    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;
    wire [31:0] inst;
    wire [31:0] id_pc;
    wire ce;

    wire wb_rf_we;  // WB to rf , write enable
    wire [4:0] wb_rf_waddr;  // WB to rf , write address
    wire [31:0] wb_rf_wdata; // WB to rf , write data

    always @ (posedge clk) begin
        if (rst) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;        
        end
        // else if (flush) begin
        //     ic_to_id_bus <= `IC_TO_ID_WD'b0;
        // end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
        end
        else if (stall[1]==`NoStop) begin
            if_to_id_bus_r <= if_to_id_bus;
        end
    end
    
    assign inst = inst_sram_rdata;
    assign {
        ce,
        id_pc
    } = if_to_id_bus_r;
    assign {
        wb_rf_we,
        wb_rf_waddr,
        wb_rf_wdata
    } = wb_to_rf_bus;

    wire [5:0] opcode;  //operation code, 6bits
    wire [4:0] rs,rt,rd,sa;    //register, 5bits
    wire [5:0] func;
    wire [15:0] imm;  //immediate number, 16bits
    wire [25:0] instr_index;
    wire [19:0] code;
    wire [4:0] base;
    wire [15:0] offset;  //pian yi liang
    wire [2:0] sel;

    wire [63:0] op_d, func_d;
    wire [31:0] rs_d, rt_d, rd_d, sa_d;

    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire [11:0] alu_op;

    wire data_ram_en;
    wire [3:0] data_ram_wen;
    
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [2:0] sel_rf_dst;

    wire [31:0] rdata1, rdata2;

    wire rs_ex_done, rt_ex_done;    //the last EX already done?
    wire rs_mem_done, rt_mem_done;  //the last MEM already done?
    wire is_rs_forward, is_rt_forward;  //now rs/rt need forward?
    wire [31:0] rs_forward_data, rt_forward_data;  //data that rs/rt forwarding need

    wire [31:0] rf_rdata1, 
                rf_rdata2;

    wire [31:0] rdata1_to_ex,rdata2_to_ex;  //data that to EX

    regfile u_regfile(
    	.clk    (clk    ),
        .raddr1 (rs ),
        .rdata1 (rdata1 ),
        .raddr2 (rt ),
        .rdata2 (rdata2 ),
        .we     (wb_rf_we     ),
        .waddr  (wb_rf_waddr  ),
        .wdata  (wb_rf_wdata  )
    );

    wire r1_write_data, r2_write_data;  //data that Write Back

    assign r1_write_data = (rs == wb_rf_waddr) && wb_rf_we;
    assign r2_write_data = (rt == wb_rf_waddr) && wb_rf_we;

    assign rf_rdata1 = r1_write_data ? wb_rf_wdata : rdata1;
    assign rf_rdata2 = r2_write_data ? wb_rf_wdata : rdata2;

    //decode
    assign opcode = inst[31:26];
    assign rs = inst[25:21];
    assign rt = inst[20:16];
    assign rd = inst[15:11];
    assign sa = inst[10:6];
    assign func = inst[5:0];
    assign imm = inst[15:0];
    assign instr_index = inst[25:0];
    assign code = inst[25:6];
    assign base = inst[25:21];
    assign offset = inst[15:0];
    assign sel = inst[2:0];

    wire inst_ori, inst_lui, inst_addiu, inst_beq;

    wire op_add, op_sub, op_slt, op_sltu;
    wire op_and, op_nor, op_or, op_xor;
    wire op_sll, op_srl, op_sra, op_lui;

    decoder_6_64 u0_decoder_6_64(
    	.in  (opcode  ),
        .out (op_d )
    );

    decoder_6_64 u1_decoder_6_64(
    	.in  (func  ),
        .out (func_d )
    );
    
    decoder_5_32 u0_decoder_5_32(
    	.in  (rs  ),
        .out (rs_d )
    );

    decoder_5_32 u1_decoder_5_32(
    	.in  (rt  ),
        .out (rt_d )
    );

    
    assign inst_ori     = op_d[6'b00_1101];
    assign inst_lui     = op_d[6'b00_1111];
    assign inst_addiu   = op_d[6'b00_1001];
    assign inst_beq     = op_d[6'b00_0100];



    // rs to reg1
    assign sel_alu_src1[0] = inst_ori | inst_addiu;

    // pc to reg1
    assign sel_alu_src1[1] = 1'b0;

    // sa_zero_extend to reg1
    assign sel_alu_src1[2] = 1'b0;

    
    // rt to reg2
    assign sel_alu_src2[0] = 1'b0;
    
    // imm_sign_extend to reg2
    assign sel_alu_src2[1] = inst_lui | inst_addiu;

    // 32'b8 to reg2
    assign sel_alu_src2[2] = 1'b0;

    // imm_zero_extend to reg2
    assign sel_alu_src2[3] = inst_ori;



    assign op_add = inst_addiu;
    assign op_sub = 1'b0;
    assign op_slt = 1'b0;
    assign op_sltu = 1'b0;
    assign op_and = 1'b0;
    assign op_nor = 1'b0;
    assign op_or = inst_ori;
    assign op_xor = 1'b0;
    assign op_sll = 1'b0;
    assign op_srl = 1'b0;
    assign op_sra = 1'b0;
    assign op_lui = inst_lui;

    assign alu_op = {op_add, op_sub, op_slt, op_sltu,
                     op_and, op_nor, op_or, op_xor,
                     op_sll, op_srl, op_sra, op_lui};



    // load and store enable
    assign data_ram_en = 1'b0;

    // write enable
    assign data_ram_wen = 1'b0;



    // regfile store enable
    assign rf_we = inst_ori | inst_lui | inst_addiu;



    // store in [rd]
    assign sel_rf_dst[0] = 1'b0;
    // store in [rt] 
    assign sel_rf_dst[1] = inst_ori | inst_lui | inst_addiu;
    // store in [31]
    assign sel_rf_dst[2] = 1'b0;

    // sel for regfile address
    assign rf_waddr = {5{sel_rf_dst[0]}} & rd 
                    | {5{sel_rf_dst[1]}} & rt
                    | {5{sel_rf_dst[2]}} & 32'd31;

    // 0 from alu_res ; 1 from ld_res
    assign sel_rf_res = 1'b0; 

    // RAW begin
    assign rs_ex_done = (rs == ex_write_address) && ex_write_en ? 1'b1 : 1'b0;
    assign rt_ex_done = (rt == ex_write_address) && ex_write_en ? 1'b1 : 1'b0;

    assign rs_mem_done = (rs == mem_write_address) && mem_write_en ? 1'b1 : 1'b0;
    assign rt_mem_done = (rt == mem_write_address) && mem_write_en ? 1'b1 : 1'b0;

    assign is_rs_forward = rs_ex_done | rs_mem_done;
    assign is_rt_forward = rt_ex_done | rt_mem_done;

    assign rs_forward_data = rs_ex_done ? ex_write_data : (rs_mem_done ? mem_write_data : 32'b0);
    assign rt_forward_data = rt_ex_done ? ex_write_data : (rt_mem_done ? mem_write_data : 32'b0);

    assign rdata1_to_ex = is_rs_forward ? rs_forward_data : rf_rdata1;
    assign rdata2_to_ex = is_rt_forward ? rt_forward_data : rf_rdata2;
    //end

    assign id_to_ex_bus = {
        id_pc,          // 158:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rdata1_to_ex,         // 63:32
        rdata2_to_ex          // 31:0
    };


    wire br_e;
    wire [31:0] br_addr;
    wire rs_eq_rt;
    wire rs_ge_z;
    wire rs_gt_z;
    wire rs_le_z;
    wire rs_lt_z;
    wire [31:0] pc_plus_4;
    assign pc_plus_4 = id_pc + 32'h4;

    assign rs_eq_rt = (rdata1_to_ex == rdata2_to_ex);

    assign br_e = inst_beq & rs_eq_rt;
    assign br_addr = inst_beq ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) : 32'b0;

    assign br_bus = {
        br_e,
        br_addr
    };
    


endmodule