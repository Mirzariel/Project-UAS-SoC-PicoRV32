`timescale 1ns / 1ps

interface if_axi4_lite #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst_n
);

    // Write Address Channel
    logic [ADDR_WIDTH-1:0] awaddr;
    logic                  awvalid;
    logic                  awready;
    logic [2:0]            awprot;

    // Write Data Channel
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH/8-1:0] wstrb;
    logic                  wvalid;
    logic                  wready;

    // Write Response Channel
    logic [1:0]            bresp;
    logic                  bvalid;
    logic                  bready;

    // Read Address Channel
    logic [ADDR_WIDTH-1:0] araddr;
    logic                  arvalid;
    logic                  arready;
    logic [2:0]            arprot;

    // Read Data Channel
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0]            rresp;
    logic                  rvalid;
    logic                  rready;

    // Modport for Master
    modport master (
        // diubah: clk dan rst_n ditambahkan ke modport karena tanpa ini yosys
        // berhenti dengan error "does not have a port named 's0.rst_n'"
        input  clk, rst_n,

        output awaddr, awprot, awvalid,
        input  awready,

        output wdata, wstrb, wvalid, 
        input  wready,

        input  bresp, bvalid, 
        output bready,

        output araddr, arprot, arvalid, 
        input  arready,

        input  rdata, rresp, rvalid, 
        output rready
    );

    // Modport for Slave
    modport slave (
        // diubah: clk dan rst_n ditambahkan ke modport karena tanpa ini yosys
        // berhenti dengan error "does not have a port named 's0.rst_n'"
        input  clk, rst_n,

        input  awaddr, awprot, awvalid,
        output awready,

        input  wdata, wstrb, wvalid, 
        output wready,

        output bresp, bvalid, 
        input  bready,

        input  araddr, arprot, arvalid, 
        output arready,
        
        output rdata, rresp, rvalid, 
        input  rready
    );

endinterface
