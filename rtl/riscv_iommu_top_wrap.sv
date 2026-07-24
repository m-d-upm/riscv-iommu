module riscv_iommu_wrapper #(
    parameter int unsigned AXI_ID_WIDTH_MASTER = -1,
    parameter int unsigned AXI_ADDR_WIDTH      = -1,
    parameter int unsigned AXI_DATA_WIDTH      = -1,
    parameter int unsigned AXI_ID_WIDTH_SLAVE  = -1
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic [3:0] iommu_id, // must be unique for every instance and the same value should be used when connecting accelerator to IOMMU in device tree
    // IOMMU TRANSLATION REQUEST AXI SLV
    input logic axi_tr_awvalid,
    output logic axi_tr_awready,
    input logic [AXI_ID_WIDTH_SLAVE-1:0] axi_tr_awid,
    input logic [7:0] axi_tr_awlen,
    input logic [AXI_ADDR_WIDTH-1:0] axi_tr_awaddr,
    input logic axi_tr_wvalid,
    output logic axi_tr_wready,
    input logic [AXI_DATA_WIDTH-1:0] axi_tr_wdata,
    input logic [AXI_DATA_WIDTH/8-1:0] axi_tr_wstrb,
    input logic axi_tr_wlast,
    input logic axi_tr_arvalid,
    output logic axi_tr_arready,
    input logic [AXI_ID_WIDTH_SLAVE-1:0] axi_tr_arid,
    input logic [7:0] axi_tr_arlen,
    input logic [AXI_ADDR_WIDTH-1:0] axi_tr_araddr,
    output logic [1:0] axi_tr_bresp,
    output logic axi_tr_bvalid,
    input logic axi_tr_bready,
    output logic [AXI_ID_WIDTH_SLAVE-1:0] axi_tr_bid,
    output logic axi_tr_rvalid,
    input logic axi_tr_rready,
    output logic [AXI_ID_WIDTH_SLAVE-1:0] axi_tr_rid,
    output logic axi_tr_rlast,
    output logic [AXI_DATA_WIDTH-1:0] axi_tr_rdata,
    output logic [1:0] axi_tr_rresp,
    input logic [2:0] axi_tr_awsize,
    input logic [2:0] axi_tr_arsize,
    input logic [1:0] axi_tr_awburst,
    input logic [1:0] axi_tr_arburst,
    input logic axi_tr_awlock,
    input logic axi_tr_arlock,
    input logic [3:0] axi_tr_awcache,
    input logic [3:0] axi_tr_arcache,
    input logic [2:0] axi_tr_awprot,
    input logic [2:0] axi_tr_arprot,
    input logic [3:0] axi_tr_awqos,
    input logic [5:0] axi_tr_awatop,
    input logic [3:0] axi_tr_awregion,
    input logic [3:0] axi_tr_arqos,
    input logic [3:0] axi_tr_arregion,
    // IOMMU AXI MST OUTPUT MUX ARB
    output logic axi_awvalid_muxed,
    input logic axi_awready_muxed,
    output logic [AXI_ID_WIDTH_MASTER:0] axi_awid_muxed,
    output logic [7:0] axi_awlen_muxed,
    output logic [AXI_ADDR_WIDTH-1:0] axi_awaddr_muxed,
    output logic axi_wvalid_muxed,
    input logic axi_wready_muxed,
    output logic [AXI_DATA_WIDTH-1:0] axi_wdata_muxed,
    output logic [AXI_DATA_WIDTH/8-1:0] axi_wstrb_muxed,
    output logic axi_wlast_muxed,
    output logic axi_arvalid_muxed,
    input logic axi_arready_muxed,
    output logic [AXI_ID_WIDTH_MASTER:0] axi_arid_muxed,
    output logic [7:0] axi_arlen_muxed,
    output logic [AXI_ADDR_WIDTH-1:0] axi_araddr_muxed,
    input logic [1:0] axi_bresp_muxed,
    input logic axi_bvalid_muxed,
    output logic axi_bready_muxed,
    input logic [AXI_ID_WIDTH_MASTER:0] axi_bid_muxed,
    input logic axi_rvalid_muxed,
    output logic axi_rready_muxed,
    input logic [AXI_ID_WIDTH_MASTER:0] axi_rid_muxed,
    input logic axi_rlast_muxed,
    input logic [AXI_DATA_WIDTH-1:0] axi_rdata_muxed,
    input logic [1:0] axi_rresp_muxed,
    output logic [2:0] axi_awsize_muxed,
    output logic [2:0] axi_arsize_muxed,
    output logic [1:0] axi_awburst_muxed,
    output logic [1:0] axi_arburst_muxed,
    output logic axi_awlock_muxed,
    output logic axi_arlock_muxed,
    output logic [3:0] axi_awcache_muxed,
    output logic [3:0] axi_arcache_muxed,
    output logic [2:0] axi_awprot_muxed,
    output logic [2:0] axi_arprot_muxed,
    output logic [3:0] axi_awqos_muxed,
    output logic [5:0] axi_awatop_muxed,
    output logic [3:0] axi_awregion_muxed,
    output logic [3:0] axi_arqos_muxed,
    output logic [3:0] axi_arregion_muxed,
    // IOMMU APB
    input logic apb_reg_bus_penable_iommu,
    input logic apb_reg_bus_pwrite_iommu,
    input logic [31:0] apb_reg_bus_paddr_iommu,
    input logic apb_reg_bus_psel_iommu,
    input logic [31:0] apb_reg_bus_pwdata_iommu,
    output logic [31:0] apb_reg_bus_prdata_iommu,
    output logic apb_reg_bus_pready_iommu,
    output logic apb_reg_bus_pslverr_iommu,
    // IOMMU IRQ
    output logic[1:0] int_lines_iommu // CQ and FQ
);
    // AXI DVM extension
    localparam DevIDWidth   = 24;
    localparam ProcIDWidth  = 20;

    typedef logic [DevIDWidth-1:0]  iommu_sid_t;
    typedef logic                   iommu_ssidv_t;
    typedef logic [ProcIDWidth-1:0] iommu_ssid_t;

    // AW Channel
    typedef struct packed {
        logic [AXI_ID_WIDTH_MASTER - 1 : 0] id;
        logic [AXI_ADDR_WIDTH - 1 : 0] addr;
        logic [7:0] len;
        logic [2:0] size;
        logic [1:0] burst;
        logic lock;
        logic [3:0] cache;
        logic [2:0] prot;
        logic [3:0] qos;
        logic [3:0] region;
        logic [5:0] atop;
        logic            user;
    } aw_chan_t;

    // AW Channel Slave
    typedef struct packed {
        logic [AXI_ID_WIDTH_SLAVE - 1 : 0] id;
        logic [AXI_ADDR_WIDTH - 1 : 0] addr;
        logic [7:0] len;
        logic [2:0] size;
        logic [1:0] burst;
        logic lock;
        logic [3:0] cache;
        logic [2:0] prot;
        logic [3:0] qos;
        logic [3:0] region;
        logic [5:0] atop;
        logic user;
    } aw_chan_slv_t;

    // AW Channel - AXI DVM extension for SMMU
    typedef struct packed {
        logic [AXI_ID_WIDTH_MASTER - 1 : 0] id;
        logic [AXI_ADDR_WIDTH - 1 : 0] addr;
        logic [7:0] len;
        logic [2:0] size;
        logic [1:0] burst;
        logic             lock;
        logic [3:0] cache;
        logic [2:0] prot;
        logic [3:0] qos;
        logic [3:0] region;
        logic [5:0] atop;
        logic            user;
        iommu_sid_t         stream_id;
        iommu_ssidv_t       ss_id_valid;
        iommu_ssid_t        substream_id;
    } aw_chan_iommu_t;

    // W Channel
    typedef struct packed {
        logic [AXI_DATA_WIDTH - 1 : 0]  data;
        logic [AXI_DATA_WIDTH/8 - 1 : 0]  strb;
        logic last;
        logic user;
    } w_chan_t;

    // B Channel
    typedef struct packed {
        logic [AXI_ID_WIDTH_MASTER - 1 : 0] id;
        logic [1:0] resp;
        logic user;
    } b_chan_t;

    // B Channel - Slave
    typedef struct packed {
        logic [AXI_ID_WIDTH_SLAVE - 1 : 0] id;
        logic [1:0] resp;
        logic          user;
    } b_chan_slv_t;

    // AR Channel
    typedef struct packed {
        logic [AXI_ID_WIDTH_MASTER - 1 : 0] id;
        logic [AXI_ADDR_WIDTH - 1 : 0] addr;
        logic [7:0] len;
        logic [2:0] size;
        logic [1:0] burst;
        logic             lock;
        logic [3:0] cache;
        logic [2:0] prot;
        logic [3:0] qos;
        logic [3:0] region;
        logic             user;
    } ar_chan_t;

    // AR Channel Slave
    typedef struct packed {
        logic [AXI_ID_WIDTH_SLAVE - 1 : 0] id;
        logic [AXI_ADDR_WIDTH - 1 : 0] addr;
        logic [7:0] len;
        logic [2:0] size;
        logic [1:0] burst;
        logic             lock;
        logic [3:0] cache;
        logic [2:0] prot;
        logic [3:0] qos;
        logic [3:0] region;
        logic             user;
    } ar_chan_slv_t;

    // AR Channel - AXI DVM extension for SMMU
    typedef struct packed {
        logic [AXI_ID_WIDTH_MASTER - 1 : 0] id;
        logic [AXI_ADDR_WIDTH - 1 : 0] addr;
        logic [7:0] len;
        logic [2:0] size;
        logic [1:0] burst;
        logic             lock;
        logic [3:0] cache;
        logic [2:0] prot;
        logic [3:0] qos;
        logic [3:0] region;
        logic             user;
        iommu_sid_t       stream_id;
        iommu_ssidv_t     ss_id_valid;
        iommu_ssid_t      substream_id;
    } ar_chan_iommu_t;

    // R Channel
    typedef struct packed {
        logic [AXI_ID_WIDTH_MASTER - 1 : 0] id;
        logic [AXI_DATA_WIDTH - 1 : 0] data;
        logic [1:0] resp;
        logic           last;
        logic           user;
    } r_chan_t;

    // R Channel - Slave
    typedef struct packed {
        logic [AXI_ID_WIDTH_SLAVE - 1 : 0] id;
        logic [AXI_DATA_WIDTH - 1 : 0] data;
        logic [1:0] resp;
        logic last;
        logic user;
    } r_chan_slv_t;

    // Request/Response structs
    typedef struct packed {
        aw_chan_t aw;
        logic     aw_valid;
        w_chan_t  w;
        logic     w_valid;
        logic     b_ready;
        ar_chan_t ar;
        logic     ar_valid;
        logic     r_ready;
    } req_t;

    typedef struct packed {
        logic     aw_ready;
        logic     ar_ready;
        logic     w_ready;
        logic     b_valid;
        b_chan_t  b;
        logic     r_valid;
        r_chan_t  r;
    } resp_t;

    // Request/Response structs for AXI MUX
     typedef struct packed {
        logic [AXI_ID_WIDTH_MASTER : 0] id;
        logic [AXI_ADDR_WIDTH - 1 : 0] addr;
        logic [7:0] len;
        logic [2:0] size;
        logic [1:0] burst;
        logic lock;
        logic [3:0] cache;
        logic [2:0] prot;
        logic [3:0] qos;
        logic [3:0] region;
        logic [5:0] atop;
        logic            user;
    } aw_chan_mux_t;

    typedef struct packed {
        logic [AXI_ID_WIDTH_MASTER : 0] id;
        logic [1:0] resp;
        logic user;
    } b_chan_mux_t;

    typedef struct packed {
        logic [AXI_ID_WIDTH_MASTER : 0] id;
        logic [AXI_ADDR_WIDTH - 1 : 0] addr;
        logic [7:0] len;
        logic [2:0] size;
        logic [1:0] burst;
        logic             lock;
        logic [3:0] cache;
        logic [2:0] prot;
        logic [3:0] qos;
        logic [3:0] region;
        logic             user;
    } ar_chan_mux_t;

    typedef struct packed {
        logic [AXI_ID_WIDTH_MASTER : 0] id;
        logic [AXI_DATA_WIDTH - 1 : 0] data;
        logic [1:0] resp;
        logic           last;
        logic           user;
    } r_chan_mux_t;

    typedef struct packed {
        aw_chan_mux_t aw;
        logic     aw_valid;
        w_chan_t  w;
        logic     w_valid;
        logic     b_ready;
        ar_chan_mux_t ar;
        logic     ar_valid;
        logic     r_ready;
    } req_mux_t;

    typedef struct packed {
        logic     aw_ready;
        logic     ar_ready;
        logic     w_ready;
        logic     b_valid;
        b_chan_mux_t  b;
        logic     r_valid;
        r_chan_mux_t  r;
    } resp_mux_t;

    typedef struct packed {
        aw_chan_slv_t aw;
        logic         aw_valid;
        w_chan_t      w;
        logic         w_valid;
        logic         b_ready;
        ar_chan_slv_t ar;
        logic         ar_valid;
        logic         r_ready;
    } req_slv_t;

    typedef struct packed {
        logic         aw_ready;
        logic         ar_ready;
        logic         w_ready;
        logic         b_valid;
        b_chan_slv_t  b;
        logic         r_valid;
        r_chan_slv_t  r;
    } resp_slv_t;

    // AXI DVM extension for SMMU
    typedef struct packed {
        aw_chan_iommu_t   aw;
        logic           aw_valid;
        w_chan_t        w;
        logic           w_valid;
        logic           b_ready;
        ar_chan_iommu_t   ar;
        logic           ar_valid;
        logic           r_ready;
    } req_iommu_t;

    typedef struct packed {
        logic[31:0] addr;
        logic  write;
        logic[31:0] wdata;
        logic[3:0] wstrb;
        logic  valid;
    } reg_req_t;

    typedef struct packed {
        logic[31:0] rdata;
        logic  error;
        logic  ready;
    } reg_rsp_t;

    logic [3:0] iommu_int;

    assign int_lines_iommu = iommu_int[1:0];

    req_iommu_t axi_iommu_tr_req;
    resp_slv_t axi_iommu_tr_rsp;

    req_t axi_iommu_pgwlk_req;
    resp_t axi_iommu_pgwlk_rsp;

    req_t axi_iommu_data_req;
    resp_t axi_iommu_data_rsp;

    // tie user signals to 0
    assign axi_iommu_tr_req.aw.user = '0;
    assign axi_iommu_tr_req.ar.user = '0;
    assign axi_iommu_tr_req.w.user = '0;
    assign axi_iommu_tr_rsp.r.user = '0;
    assign axi_iommu_tr_rsp.b.user = '0;

    assign axi_iommu_pgwlk_req.aw.user = '0;
    assign axi_iommu_pgwlk_req.ar.user = '0;
    assign axi_iommu_pgwlk_req.w.user = '0;
    assign axi_iommu_pgwlk_rsp.r.user = '0;
    assign axi_iommu_pgwlk_rsp.b.user = '0;

    assign axi_iommu_data_req.aw.user = '0;
    assign axi_iommu_data_req.ar.user = '0;
    assign axi_iommu_data_req.w.user = '0;
    assign axi_iommu_data_rsp.r.user = '0;
    assign axi_iommu_data_rsp.b.user = '0;

    // AW
    assign axi_iommu_tr_req.aw.stream_id = {20'b0, iommu_id};
    assign axi_iommu_tr_req.aw.ss_id_valid = '0;
    assign axi_iommu_tr_req.aw.substream_id = '0;

    // AR
    assign axi_iommu_tr_req.ar.stream_id = {20'b0, iommu_id};
    assign axi_iommu_tr_req.ar.ss_id_valid = '0;
    assign axi_iommu_tr_req.ar.substream_id = '0;

    /// IOMMU AXI TRANSLATION REQUEST SLV
    // AW
    assign axi_iommu_tr_req.aw.id = axi_tr_awid;
    assign axi_iommu_tr_req.aw.addr = axi_tr_awaddr;
    assign axi_iommu_tr_req.aw.len = axi_tr_awlen;
    assign axi_iommu_tr_req.aw.size = axi_tr_awsize;
    assign axi_iommu_tr_req.aw.burst = axi_tr_awburst;
    assign axi_iommu_tr_req.aw.lock = axi_tr_awlock;
    assign axi_iommu_tr_req.aw.cache = axi_tr_awcache;
    assign axi_iommu_tr_req.aw.prot = axi_tr_awprot;
    assign axi_iommu_tr_req.aw.qos = axi_tr_awqos;
    assign axi_iommu_tr_req.aw.region = axi_tr_awregion;
    assign axi_iommu_tr_req.aw.atop = axi_tr_awatop;
    assign axi_iommu_tr_req.aw_valid = axi_tr_awvalid;

    // W
    assign axi_iommu_tr_req.w.data = axi_tr_wdata;
    assign axi_iommu_tr_req.w.strb = axi_tr_wstrb;
    assign axi_iommu_tr_req.w.last = axi_tr_wlast;
    assign axi_iommu_tr_req.w_valid = axi_tr_wvalid;

    // AR
    assign axi_iommu_tr_req.ar.id = axi_tr_arid;
    assign axi_iommu_tr_req.ar.addr = axi_tr_araddr;
    assign axi_iommu_tr_req.ar.len = axi_tr_arlen;
    assign axi_iommu_tr_req.ar.size = axi_tr_arsize;
    assign axi_iommu_tr_req.ar.burst = axi_tr_arburst;
    assign axi_iommu_tr_req.ar.lock = axi_tr_arlock;
    assign axi_iommu_tr_req.ar.cache = axi_tr_arcache;
    assign axi_iommu_tr_req.ar.prot = axi_tr_arprot;
    assign axi_iommu_tr_req.ar.qos = axi_tr_arqos;
    assign axi_iommu_tr_req.ar.region = axi_tr_arregion;
    assign axi_iommu_tr_req.ar_valid = axi_tr_arvalid;

    // Address & Data
    assign axi_tr_awready = axi_iommu_tr_rsp.aw_ready;
    assign axi_tr_wready = axi_iommu_tr_rsp.w_ready;
    assign axi_tr_arready = axi_iommu_tr_rsp.ar_ready;

    // B
    assign axi_tr_bid = axi_iommu_tr_rsp.b.id;
    assign axi_tr_bresp = axi_iommu_tr_rsp.b.resp;
    assign axi_tr_bvalid = axi_iommu_tr_rsp.b_valid;
    assign axi_iommu_tr_req.b_ready = axi_tr_bready;

    // R
    assign axi_tr_rid = axi_iommu_tr_rsp.r.id;
    assign axi_tr_rdata = axi_iommu_tr_rsp.r.data;
    assign axi_tr_rresp = axi_iommu_tr_rsp.r.resp;
    assign axi_tr_rlast = axi_iommu_tr_rsp.r.last;
    assign axi_tr_rvalid = axi_iommu_tr_rsp.r_valid;
    assign axi_iommu_tr_req.r_ready = axi_tr_rready;

    riscv_iommu #(
        .InclPC         (0),
        .InclBC         (0),
        .InclDBG        (1),
        .N_INT_VEC      (4),
        .MSITrans       (rv_iommu::MSI_DISABLED),
        .IOTLB_ENTRIES  (8),
        .N_IOHPMCTR     (0),
        .IGS            (rv_iommu::WSI_ONLY),
        .ADDR_WIDTH		(AXI_ADDR_WIDTH),
        .DATA_WIDTH		(AXI_DATA_WIDTH),
        .ID_WIDTH		(AXI_ID_WIDTH_MASTER),
        .USER_WIDTH		(1),
        .aw_chan_t		(aw_chan_t),
        .w_chan_t		(w_chan_t),
        .b_chan_t		(b_chan_t),
        .ar_chan_t		(ar_chan_t),
        .r_chan_t		(r_chan_t),
        .axi_req_t		(req_t),
        .axi_rsp_t		(resp_t),
        .axi_req_iommu_t(req_iommu_t),
        .reg_req_t		(reg_req_t),
        .reg_rsp_t		(reg_rsp_t)
    ) i_cgra_iommu (
        .clk_i          (clk_i),
        .rst_ni         (rst_ni),
        // Translation Request Interface (Slave)
        .dev_tr_req_i	(axi_iommu_tr_req),
        .dev_tr_resp_o	(axi_iommu_tr_rsp),
        // Translation Completion Interface (Master)
        .dev_comp_resp_i(axi_iommu_data_rsp),
        .dev_comp_req_o (axi_iommu_data_req),
        // Implicit Memory Accesses Interface (Master)
        .ds_resp_i		(axi_iommu_pgwlk_rsp),
        .ds_req_o		(axi_iommu_pgwlk_req),
        // Programming Interface (Slave) (APB -> Reg IF)
        .apb_reg_bus_penable(apb_reg_bus_penable_iommu),
        .apb_reg_bus_pwrite(apb_reg_bus_pwrite_iommu),
        .apb_reg_bus_paddr(apb_reg_bus_paddr_iommu),
        .apb_reg_bus_psel(apb_reg_bus_psel_iommu),
        .apb_reg_bus_pwdata(apb_reg_bus_pwdata_iommu),
        .apb_reg_bus_prdata(apb_reg_bus_prdata_iommu),
        .apb_reg_bus_pready(apb_reg_bus_pready_iommu),
        .apb_reg_bus_pslverr(apb_reg_bus_pslverr_iommu),
        .wsi_wires_o(iommu_int)
    );

    req_slv_t [1:0] mux_slv_reqs;
    resp_slv_t [1:0] mux_slv_resps;

    req_mux_t mux_mst_out_req;
    resp_mux_t mux_mst_out_resp;

    // user signals to 0
    assign mux_mst_out_req.aw.user = '0;
    assign mux_mst_out_req.ar.user = '0;
    assign mux_mst_out_req.w.user = '0;
    assign mux_mst_out_resp.r.user = '0;
    assign mux_mst_out_resp.b.user = '0;

    assign mux_slv_reqs[0].aw.user = '0;
    assign mux_slv_reqs[0].ar.user = '0;
    assign mux_slv_reqs[0].w.user = '0;
    assign mux_slv_resps[0].r.user = '0;
    assign mux_slv_resps[0].b.user = '0;

    assign mux_slv_reqs[1].aw.user = '0;
    assign mux_slv_reqs[1].ar.user = '0;
    assign mux_slv_reqs[1].w.user = '0;
    assign mux_slv_resps[1].r.user = '0;
    assign mux_slv_resps[1].b.user = '0;


    /// IOMMU SLV MUX MST DATA INTERFACE
    // AW
    assign mux_slv_reqs[0].aw.id = axi_iommu_data_req.aw.id;
    assign mux_slv_reqs[0].aw.addr = axi_iommu_data_req.aw.addr;
    assign mux_slv_reqs[0].aw.len = axi_iommu_data_req.aw.len;
    assign mux_slv_reqs[0].aw.size = axi_iommu_data_req.aw.size;
    assign mux_slv_reqs[0].aw.burst = axi_iommu_data_req.aw.burst;
    assign mux_slv_reqs[0].aw.lock = axi_iommu_data_req.aw.lock;
    assign mux_slv_reqs[0].aw.cache = axi_iommu_data_req.aw.cache;
    assign mux_slv_reqs[0].aw.prot = axi_iommu_data_req.aw.prot;
    assign mux_slv_reqs[0].aw.qos = axi_iommu_data_req.aw.qos;
    assign mux_slv_reqs[0].aw.region = axi_iommu_data_req.aw.region;
    assign mux_slv_reqs[0].aw.atop = axi_iommu_data_req.aw.atop;
    assign mux_slv_reqs[0].aw_valid = axi_iommu_data_req.aw_valid;

    // W
    assign mux_slv_reqs[0].w.data = axi_iommu_data_req.w.data;
    assign mux_slv_reqs[0].w.strb = axi_iommu_data_req.w.strb;
    assign mux_slv_reqs[0].w.last = axi_iommu_data_req.w.last;
    assign mux_slv_reqs[0].w_valid = axi_iommu_data_req.w_valid;

    // AR
    assign mux_slv_reqs[0].ar.id = axi_iommu_data_req.ar.id;
    assign mux_slv_reqs[0].ar.addr = axi_iommu_data_req.ar.addr;
    assign mux_slv_reqs[0].ar.len = axi_iommu_data_req.ar.len;
    assign mux_slv_reqs[0].ar.size = axi_iommu_data_req.ar.size;
    assign mux_slv_reqs[0].ar.burst = axi_iommu_data_req.ar.burst;
    assign mux_slv_reqs[0].ar.lock = axi_iommu_data_req.ar.lock;
    assign mux_slv_reqs[0].ar.cache = axi_iommu_data_req.ar.cache;
    assign mux_slv_reqs[0].ar.prot = axi_iommu_data_req.ar.prot;
    assign mux_slv_reqs[0].ar.qos = axi_iommu_data_req.ar.qos;
    assign mux_slv_reqs[0].ar.region = axi_iommu_data_req.ar.region;
    assign mux_slv_reqs[0].ar_valid = axi_iommu_data_req.ar_valid;

    // Address & Data
    assign axi_iommu_data_rsp.aw_ready = mux_slv_resps[0].aw_ready;
    assign axi_iommu_data_rsp.w_ready = mux_slv_resps[0].w_ready;
    assign axi_iommu_data_rsp.ar_ready = mux_slv_resps[0].ar_ready;

    // B
    assign axi_iommu_data_rsp.b.id = mux_slv_resps[0].b.id;
    assign axi_iommu_data_rsp.b.resp = mux_slv_resps[0].b.resp;
    assign axi_iommu_data_rsp.b_valid = mux_slv_resps[0].b_valid;
    assign mux_slv_reqs[0].b_ready = axi_iommu_data_req.b_ready;

    // R
    assign axi_iommu_data_rsp.r.id = mux_slv_resps[0].r.id;
    assign axi_iommu_data_rsp.r.data = mux_slv_resps[0].r.data;
    assign axi_iommu_data_rsp.r.resp = mux_slv_resps[0].r.resp;
    assign axi_iommu_data_rsp.r.last = mux_slv_resps[0].r.last;
    assign axi_iommu_data_rsp.r_valid = mux_slv_resps[0].r_valid;
    assign mux_slv_reqs[0].r_ready = axi_iommu_data_req.r_ready;

      /// IOMMU SLV MUX MST PGWLK INTERFACE
    // AW
    assign mux_slv_reqs[1].aw.id = axi_iommu_pgwlk_req.aw.id;
    assign mux_slv_reqs[1].aw.addr = axi_iommu_pgwlk_req.aw.addr;
    assign mux_slv_reqs[1].aw.len = axi_iommu_pgwlk_req.aw.len;
    assign mux_slv_reqs[1].aw.size = axi_iommu_pgwlk_req.aw.size;
    assign mux_slv_reqs[1].aw.burst = axi_iommu_pgwlk_req.aw.burst;
    assign mux_slv_reqs[1].aw.lock = axi_iommu_pgwlk_req.aw.lock;
    assign mux_slv_reqs[1].aw.cache = axi_iommu_pgwlk_req.aw.cache;
    assign mux_slv_reqs[1].aw.prot = axi_iommu_pgwlk_req.aw.prot;
    assign mux_slv_reqs[1].aw.qos = axi_iommu_pgwlk_req.aw.qos;
    assign mux_slv_reqs[1].aw.region = axi_iommu_pgwlk_req.aw.region;
    assign mux_slv_reqs[1].aw.atop = axi_iommu_pgwlk_req.aw.atop;
    assign mux_slv_reqs[1].aw_valid = axi_iommu_pgwlk_req.aw_valid;

    // W
    assign mux_slv_reqs[1].w.data = axi_iommu_pgwlk_req.w.data;
    assign mux_slv_reqs[1].w.strb = axi_iommu_pgwlk_req.w.strb;
    assign mux_slv_reqs[1].w.last = axi_iommu_pgwlk_req.w.last;
    assign mux_slv_reqs[1].w_valid = axi_iommu_pgwlk_req.w_valid;

    // AR
    assign mux_slv_reqs[1].ar.id = axi_iommu_pgwlk_req.ar.id;
    assign mux_slv_reqs[1].ar.addr = axi_iommu_pgwlk_req.ar.addr;
    assign mux_slv_reqs[1].ar.len = axi_iommu_pgwlk_req.ar.len;
    assign mux_slv_reqs[1].ar.size = axi_iommu_pgwlk_req.ar.size;
    assign mux_slv_reqs[1].ar.burst = axi_iommu_pgwlk_req.ar.burst;
    assign mux_slv_reqs[1].ar.lock = axi_iommu_pgwlk_req.ar.lock;
    assign mux_slv_reqs[1].ar.cache = axi_iommu_pgwlk_req.ar.cache;
    assign mux_slv_reqs[1].ar.prot = axi_iommu_pgwlk_req.ar.prot;
    assign mux_slv_reqs[1].ar.qos = axi_iommu_pgwlk_req.ar.qos;
    assign mux_slv_reqs[1].ar.region = axi_iommu_pgwlk_req.ar.region;
    assign mux_slv_reqs[1].ar_valid = axi_iommu_pgwlk_req.ar_valid;

    // Address & Data
    assign axi_iommu_pgwlk_rsp.aw_ready = mux_slv_resps[1].aw_ready;
    assign axi_iommu_pgwlk_rsp.w_ready = mux_slv_resps[1].w_ready;
    assign axi_iommu_pgwlk_rsp.ar_ready = mux_slv_resps[1].ar_ready;

    // B
    assign axi_iommu_pgwlk_rsp.b.id = mux_slv_resps[1].b.id;
    assign axi_iommu_pgwlk_rsp.b.resp = mux_slv_resps[1].b.resp;
    assign axi_iommu_pgwlk_rsp.b_valid = mux_slv_resps[1].b_valid;
    assign mux_slv_reqs[1].b_ready = axi_iommu_pgwlk_req.b_ready;

    // R
    assign axi_iommu_pgwlk_rsp.r.id = mux_slv_resps[1].r.id;
    assign axi_iommu_pgwlk_rsp.r.data = mux_slv_resps[1].r.data;
    assign axi_iommu_pgwlk_rsp.r.resp = mux_slv_resps[1].r.resp;
    assign axi_iommu_pgwlk_rsp.r.last = mux_slv_resps[1].r.last;
    assign axi_iommu_pgwlk_rsp.r_valid = mux_slv_resps[1].r_valid;
    assign mux_slv_reqs[1].r_ready = axi_iommu_pgwlk_req.r_ready;

    // IOMMU AXI MST SINGLE OUT MUX
    // AW
    assign axi_awid_muxed     = mux_mst_out_req.aw.id;
    assign axi_awaddr_muxed   = mux_mst_out_req.aw.addr;
    assign axi_awlen_muxed    = mux_mst_out_req.aw.len;
    assign axi_awsize_muxed   = mux_mst_out_req.aw.size;
    assign axi_awburst_muxed  = mux_mst_out_req.aw.burst;
    assign axi_awlock_muxed   = mux_mst_out_req.aw.lock;
    assign axi_awcache_muxed  = mux_mst_out_req.aw.cache;
    assign axi_awprot_muxed   = mux_mst_out_req.aw.prot;
    assign axi_awqos_muxed    = mux_mst_out_req.aw.qos;
    assign axi_awregion_muxed = mux_mst_out_req.aw.region;
    assign axi_awatop_muxed   = mux_mst_out_req.aw.atop;
    assign axi_awvalid_muxed  = mux_mst_out_req.aw_valid;

    // W
    assign axi_wdata_muxed    = mux_mst_out_req.w.data;
    assign axi_wstrb_muxed    = mux_mst_out_req.w.strb;
    assign axi_wlast_muxed    = mux_mst_out_req.w.last;
    assign axi_wvalid_muxed   = mux_mst_out_req.w_valid;

    // AR
    assign axi_arid_muxed     = mux_mst_out_req.ar.id;
    assign axi_araddr_muxed   = mux_mst_out_req.ar.addr;
    assign axi_arlen_muxed    = mux_mst_out_req.ar.len;
    assign axi_arsize_muxed   = mux_mst_out_req.ar.size;
    assign axi_arburst_muxed  = mux_mst_out_req.ar.burst;
    assign axi_arlock_muxed   = mux_mst_out_req.ar.lock;
    assign axi_arcache_muxed  = mux_mst_out_req.ar.cache;
    assign axi_arprot_muxed   = mux_mst_out_req.ar.prot;
    assign axi_arqos_muxed    = mux_mst_out_req.ar.qos;
    assign axi_arregion_muxed = mux_mst_out_req.ar.region;
    assign axi_arvalid_muxed  = mux_mst_out_req.ar_valid;

    // Address & Data
    assign mux_mst_out_resp.aw_ready = axi_awready_muxed;
    assign mux_mst_out_resp.w_ready  = axi_wready_muxed;
    assign mux_mst_out_resp.ar_ready = axi_arready_muxed;

    // B
    assign mux_mst_out_resp.b.id     = axi_bid_muxed;
    assign mux_mst_out_resp.b.resp   = axi_bresp_muxed;
    assign mux_mst_out_resp.b_valid  = axi_bvalid_muxed;
    assign axi_bready_muxed   = mux_mst_out_req.b_ready;

    // R
    assign mux_mst_out_resp.r.id     = axi_rid_muxed;
    assign mux_mst_out_resp.r.data   = axi_rdata_muxed;
    assign mux_mst_out_resp.r.resp   = axi_rresp_muxed;
    assign mux_mst_out_resp.r.last   = axi_rlast_muxed;
    assign mux_mst_out_resp.r_valid  = axi_rvalid_muxed;
    assign axi_rready_muxed   = mux_mst_out_req.r_ready;

    // NOTE: The output mux master (mux_mst_out_req, mux_mst_out_resp) will have
    // in this case the AXI ID widths extended by one bit.
    // Make sure that the AXI accelerator does not use AXI ID widths greater than 9 bits
    // because at the time of leaving this comment the global maximum AXI ID widths in ESP
    // are set to 10 bits wide. 
    axi_mux #(
        .SlvAxiIDWidth (AXI_ID_WIDTH_SLAVE),
        .NoSlvPorts     (2), // number of slave ports
        // maximum number of outstanding transactions per write
        .MaxWTrans      (24),
        .SpillAw         (1),
        .SpillW          (1),
        .SpillB          (1),
        .SpillAr         (1),
        .SpillR          (1),
        .slv_aw_chan_t    (aw_chan_slv_t),
        .mst_aw_chan_t    (aw_chan_mux_t),
        .w_chan_t         (w_chan_t),
        .slv_b_chan_t     (b_chan_slv_t),
        .mst_b_chan_t     (b_chan_mux_t),
        .slv_ar_chan_t    (ar_chan_slv_t),
        .mst_ar_chan_t    (ar_chan_mux_t),
        .mst_resp_t       (resp_mux_t),
        .slv_r_chan_t     (r_chan_slv_t),
        .mst_r_chan_t     (r_chan_mux_t),
        .slv_req_t        (req_slv_t),
        .slv_resp_t       (resp_slv_t),
        .mst_req_t        (req_mux_t)
  ) iommu_arbiter_mux (
    .clk_i            (clk_i),         // Clock
    .rst_ni           (rst_ni),        // Asynchronous reset active low
    .test_i           ('0),
    .slv_reqs_i       (mux_slv_reqs),
    .slv_resps_o      (mux_slv_resps),
    .mst_req_o        (mux_mst_out_req),
    .mst_resp_i       (mux_mst_out_resp)
  );
    
endmodule
