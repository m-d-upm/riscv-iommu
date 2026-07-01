// Copyright © 2023 Manuel Rodríguez & Zero-Day Labs, Lda.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Licensed under the Solderpad Hardware License v 2.1 (the “License”); 
// you may not use this file except in compliance with the License, 
// or, at your option, the Apache License version 2.0. 
// You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/.
// Unless required by applicable law or agreed to in writing, 
// any work distributed under the License is distributed on an “AS IS” BASIS, 
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
// See the License for the specific language governing permissions and limitations under the License.
//
// Author: Manuel Rodríguez <manuel.cederog@gmail.com>
// Date:   02/02/2023
// Acknowledges: SSRC - Technology Innovation Institute (TII)
//
// Description: Wrapper module for the RISC-V IOMMU register programming interface.
//              Instantiates the IOMMU register map and performs conversion between 
//              register interface protocol and AXI4.
//

`include "register_interface/assign.svh"

module rv_iommu_prog_if #(
    /// The width of the address.
    parameter int               ADDR_WIDTH = -1,
    /// The width of the data.
    parameter int               DATA_WIDTH = -1,
    /// AXI ID width
    parameter int               ID_WIDTH  = -1,
    /// AXI user width
    parameter int               USER_WIDTH  = 1,
    
    /// Regbus request struct type.
    parameter type  reg_req_t = logic,
    /// Regbus response struct type.
    parameter type  reg_rsp_t = logic
) (
    // rising-edge clock 
    input  logic     clk_i,
    // asynchronous reset, active low
    input  logic     rst_ni,

    // From IOMMU programing interface
    input logic apb_reg_bus_penable,
    input logic apb_reg_bus_pwrite,
    input logic [31:0] apb_reg_bus_paddr,
    input logic apb_reg_bus_psel,
    input logic [31:0] apb_reg_bus_pwdata,
    output logic [31:0] apb_reg_bus_prdata,
    output logic apb_reg_bus_pready,
    output logic apb_reg_bus_pslverr,

    // To register map
    output reg_req_t regmap_req_o,
    input  reg_rsp_t regmap_resp_i
);

    REG_BUS #(
        .ADDR_WIDTH ( ADDR_WIDTH ),
        .DATA_WIDTH ( 32         )
    ) iommu_reg_bus (clk_i);

    logic                       penable;
    logic                       pwrite;
    logic [(ADDR_WIDTH-1):0]    paddr;
    logic                       psel;
    logic [31:0]                pwdata;
    logic [31:0]                prdata;
    logic                       pready;
    logic                       pslverr;

    assign penable = apb_reg_bus_penable;
    assign pwrite = apb_reg_bus_pwrite;
    assign paddr = [31:0] apb_reg_bus_paddr;
    assign psel = apb_reg_bus_psel;
    assign pwdata = [31:0] apb_reg_bus_pwdata;

    assign apb_reg_bus_prdata = prdata;
    assign apb_reg_bus_pready = pready;
    assign apb_reg_bus_pslverr = pslverr;

    // APB to REG IF
    apb_to_reg i_apb_to_reg (
        .clk_i     ( clk_i          ),
        .rst_ni    ( rst_ni         ),
        .penable_i ( penable        ),
        .pwrite_i  ( pwrite         ),
        .paddr_i   ( paddr          ),
        .psel_i    ( psel           ),
        .pwdata_i  ( pwdata         ),
        .prdata_o  ( prdata         ),
        .pready_o  ( pready         ),
        .pslverr_o ( pslverr        ),
        .reg_o     ( iommu_reg_bus  )
    );

    // assign REG_BUS.out to (req_t, rsp_t) pair
    `REG_BUS_ASSIGN_TO_REQ(regmap_req_o, iommu_reg_bus)
    `REG_BUS_ASSIGN_FROM_RSP(iommu_reg_bus, regmap_resp_i)

endmodule
