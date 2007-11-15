// datapath.sv
// datapath for hmc-6502 CPU
// 31oct07
// tbarr at cs hmc edu

`timescale 1 ns / 1 ps

module datapath(input logic [7:0] data_in,
                output logic [7:0] data_out,
                output logic [15:0] address,
                input logic ph1, ph2, reset,
                
                // controls list from ucodeasm:
                input logic th_in_en,
                input logic th_out_en,
                input logic tl_in_en,
                input logic tl_out_en,
                input logic [7:0] p_in_en,
                input logic p_out_en,
                input logic p_sel,
                input logic reg_write_en,
                input logic [1:0] reg_read_addr_a,
                input logic [1:0] reg_read_addr_b,
                input logic [1:0] reg_write_addr,
                input logic reg_a_en,
                input logic reg_b_en,
                input logic pch_in_en,
                input logic pch_out_en,
                input logic pcl_in_en,
                input logic pcl_out_en,
                input logic pc_inc_en,
                input logic pc_sel,
                input logic d_in_en,
                input logic d_out_sel,
                input logic [2:0] ah_sel,
                input logic [1:0] al_sel,
                input logic [3:0] alu_op,
                input logic c_temp_en,
                input logic carry_sel,
                input logic [7:0] constant,
                input logic constant_en
                );
  
  wire [7:0] a_s1, flag_selected_s2;
  logic [7:0] th_s1, tl_s1, p_s1, r_s2;

  logic [7:0] reg_a_s1, reg_b_s1;
  
  logic [7:0] pch_in_s2, pcl_in_s2, pch_next_s1, pch_next_s2, pcl_next_s1,
              pcl_next_s2, pch_s1, pcl_s1;
  
  logic [7:0] di_s1;
  
  wire [7:0] b_s1, b_s2;
  
  logic [7:0] th_s2, tl_s2;
  
  logic [7:0] r_s1;
  logic [7:0] flags_s1, flags_s2;
  logic c_in_s1, bcd_s1;
  
  // registers
  buslatch temp_high(th_in_en, th_out_en, th_s1, r_s2, a_s1, ph2, reset);
  buslatch  temp_low(tl_in_en, tl_out_en, tl_s1, r_s2, a_s1, ph2, reset);
  flaglatch p(p_in_en, p_out_en, p_s1, flag_selected_s2, b_s1, ph2, reset);
  mux2 #8 p_sel_mux(flags_s2, r_s2, p_sel, flag_selected_s2);
  
  // constant
  tristate #8 constant_tris(constant, constant_en, a_s1);
  
  // register file
  regfile regfile(ph2, reset, reg_write_en, reg_read_addr_a, reg_read_addr_b, 
          reg_write_addr, r_s2, reg_a_s1, reg_b_s1);
  tristate #8 rfile_tris_a(reg_a_s1, reg_a_en, a_s1);
  tristate #8 rfile_tris_b(reg_b_s1, reg_b_en, b_s1);
  
  // program counter
  buslatch pc_high(pch_in_en, pch_out_en, pch_s1, pch_in_s2, b_s1, ph2, reset);
  buslatch  pc_low(pcl_in_en, pcl_out_en, pcl_s1, pcl_in_s2, b_s1, ph2, reset);
  
  // -16-bit half adder
  halfadder #16 pcinc({pch_s1, pcl_s1}, pc_inc_en, {pch_next_s1, pcl_next_s1});
  
  // -buffer addition, and select source
  latch #16 pc_next_buf({pch_next_s1, pcl_next_s1}, 
                        {pch_next_s2, pcl_next_s2}, ph1, reset);
  mux2 #8 pch_sel(pch_next_s2, r_s2, pc_sel, pch_in_s2);
  mux2 #8 pcl_sel(pcl_next_s2, r_s2, pc_sel, pcl_in_s2);
  
  // memory I/O
  // -input
  latch #8 d_in_buf(data_in, di_s1, ph2, reset);
  tristate #8 di_tris(di_s1, d_in_en, a_s1);
  
  // -output
  // we must buffer the b_s1 line into a b_s2 line to put on the bus
  latch #8 b_buf(b_s1, b_s2, ph1, reset);
  mux2 #8 data_out_sel_mux(r_s2, b_s2, d_out_sel, data_out);
  
  // -address bus
  latch th_buf(th_s1, th_s2, ph1, reset);
  latch tl_buf(tl_s1, tl_s2, ph1, reset);
  
  mux5 #8 ah_mux(pch_next_s2, r_s2, th_s2, 8'h00, 8'h01, ah_sel, address[15:8]);
  mux3 #8 al_mux(pcl_next_s2, r_s2, tl_s2, al_sel, address[7:0]);
  
  // ALU and carry logic
  assign bcd_s1 = p_s1[4];
  
  alu alu(a_s1, b_s1, r_s1, alu_op, c_in_s1, bcd_s1, 
          flags_s1[1], flags_s1[7], flags_s1[6], flags_s1[0]);
  
  // -buffer to prevent loops
  latch r_buf(r_s1, r_s2, ph1, reset);
  latch flag_buf(flags_s1, flags_s2, ph1, reset);
  
  // -select carry source
  latch #1 c_temp(flags_s2[0], c_temp_s1, (ph2 & c_temp_en), reset);
  mux2 #1 carry_sel_mux(p_s1[0], c_temp_s1, carry_sel, c_in_s1);

endmodule