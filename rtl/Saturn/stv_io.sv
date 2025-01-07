// 
// Rough version of the IO chip on Sega ST-V.
//
// See MAME code, for reference...
//
// https://github.com/mamedev/mame/blob/mame0272/src/mame/sega/315_5649.cpp#L77
//
// ElectronAsh. Dec 2024.
//
//
module stv_io (
	input CLK,
	input RST_N,
	
	input STV_IO_CS,
	
	input [4:0] MSHA,
	input [7:0] MSHDO,
	input MSHBS_N,
	input MSHRD_WR_N,
	
	input [31:0] joy0,
	input [31:0] joy1,
	input [31:0] joy2,
	input [31:0] joy3,
	
	input [7:0] ADC_IN_0,
	input [7:0] ADC_IN_1,
	input [7:0] ADC_IN_2,
	input [7:0] ADC_IN_3,
	input [7:0] ADC_IN_4,
	input [7:0] ADC_IN_5,
	input [7:0] ADC_IN_6,
	input [7:0] ADC_IN_7,
	
	output reg [7:0] PORTD_OUT,	// JAMMA (56P) + CN25 (JST NH 5P) RESERVED OUTPUT 4bit. (?)
	output reg [7:0] PORTF_OUT,	// CN21 (JST NH 11P) EXTENSION I/O 8bit. Used for 7-Seg disp, on games like Critter Crusher.
	output reg [7:0] PORTG_OUT,	// CN20 (JST HN 10P) EXTENSION INPUT 8bit. (?)
	
	output [31:0] STV_IO_DOUT
);


// 0x0001 PORT-A (P1)      JAMMA (56P)
// 0x0003 PORT-B (P2)      JAMMA (56P)
// 0x0005 PORT-C (SYSTEM)  JAMMA (56P)
// 0x0007 PORT-D (OUTPUT)  JAMMA (56P) + CN25 (JST NH 5P) RESERVED OUTPUT 4bit. (?)
// 0x0009 PORT-E (P3)      CN32 (JST NH 9P) EXTENSION I/O 8bit.
// 0x000b PORT-F (P4 / Extra 6B layout)    CN21 (JST NH 11P) EXTENSION I/O 8bit.
// 0x000d PORT-G           CN20 (JST HN 10P) EXTENSION INPUT 8bit. (?)
// 0x000f unused
// 0x0011 PORT_DIR
//
// (each bit of PORT_DIR configures the DIRection of each 8-bit IO port. 1=input, 0=output.)
//
//  eg. PORT_DIR[0]=1=PORTA pins are all INPUTs.
//  eg. PORT_DIR[1]=1=PORTB pins are all INPUTs.
//  eg. PORT_DIR[2]=1=PORTC pins are all INPUTs.
//  eg. PORT_DIR[3]=0=PORTD pins are all OUTPUTs.


// PORTs A, B, E, F. (Player 1, 2, 3, 4)...
// 
// b7 = Left
// b6 = Right
// b5 = Up
// b4 = Down
// b3 = Button 4 (P3/P4 use this for Start)
// b2 = Button 3
// b1 = Button 2
// b0 = Button 1
//
// Button inputs to core are Active-LOW !
// 
wire [7:0] P1_CONT = ~{joy0[1],joy0[0],joy0[3],joy0[2], joy0[7:4]};
wire [7:0] P2_CONT = ~{joy1[1],joy1[0],joy1[3],joy1[2], joy1[7:4]};
wire [7:0] P3_CONT = ~{joy2[1],joy2[0],joy2[3],joy2[2], joy2[7:4]};

//wire [7:0] P4_CONT = ~{joy3[1],joy3[0],joy3[3],joy3[2], joy3[7:4]};

// Added some extra buttons to CONF_STR, so they can be mapped to P4.
// Also mapping the directions (U,D,L,R) from P1 to P4, which is probably not a good idea, but TESTING. ElectronAsh.
wire [7:0] P4_CONT = ~{joy0[1],joy0[0],joy0[3],joy0[2], joy0[19:16]};


// PORTC (System) inputs...
// 
// b7 = Pause (if the game supports it)
// b6 = Multi-Cart Select.
// b5 = Start 2 ?
// b4 = Start 1 ?
// b3 = Service 1.
// b2 = Service - No toggle??
// b1 = Coin 2
// b0 = Coin 1
//
// Button inputs to core are Active-LOW !
// 
wire [7:0] SYS_CONT = ~joy0[15:8];


wire [7:0] ADC_MUX = (ADC_SEL==3'd0) ? ADC_IN_0 :
							(ADC_SEL==3'd1) ? ADC_IN_1 :
							(ADC_SEL==3'd2) ? ADC_IN_2 :
							(ADC_SEL==3'd3) ? ADC_IN_3 :
							(ADC_SEL==3'd4) ? ADC_IN_4 :
							(ADC_SEL==3'd5) ? ADC_IN_5 :
							(ADC_SEL==3'd6) ? ADC_IN_6 :
													ADC_IN_7;

// Shifting the address constants below, and ditching the LSB bit of MSHA.
//
// I think the regs probably get mirrored on both ODD and EVEN SH2 addresses? ElectronAsh.
//
// The IO chip Addr inputs are likely hooked up directly to the SH2 Addr bus [4:1].
//
// The usual Register addresses would be 0x0 through 0xf.
// But with the LSB bit of the SH2 Address skipped, the addresses would appear to the SH2 as 0x01 through 0x1f ?
// EVEN SH2 addresses 0, 2, 4, etc. would maybe also work fine?
//
(*keep*)wire PORTA_CS  = (MSHA[4:1]==5'h01>>1);
(*keep*)wire PORTB_CS  = (MSHA[4:1]==5'h03>>1);
(*keep*)wire PORTC_CS  = (MSHA[4:1]==5'h05>>1);
(*keep*)wire PORTD_CS  = (MSHA[4:1]==5'h07>>1);
(*keep*)wire PORTE_CS  = (MSHA[4:1]==5'h09>>1);
(*keep*)wire PORTF_CS  = (MSHA[4:1]==5'h0b>>1);
(*keep*)wire PORTG_CS  = (MSHA[4:1]==5'h0d>>1);
(*keep*)wire UNUSED_CS = (MSHA[4:1]==5'h0f>>1);
(*keep*)wire   DIR_CS  = (MSHA[4:1]==5'h11>>1);

(*keep*)wire   TXD1_CS = (MSHA[4:1]==5'h13>>1);	// ?? Debug ??
(*keep*)wire   TXD2_CS = (MSHA[4:1]==5'h15>>1);	// RS422 Serial COM Tx.
(*keep*)wire   RXD1_CS = (MSHA[4:1]==5'h17>>1);	// ?? Debug ??
(*keep*)wire   RXD2_CS = (MSHA[4:1]==5'h19>>1);	// RS422 Serial COM Rx.
(*keep*)wire   FLAG_CS = (MSHA[4:1]==5'h1b>>1);	// RS422 FLAG.
(*keep*)wire   MODE_CS = (MSHA[4:1]==5'h1d>>1);	// [7]=b1=Set PORTG Counter MODE. [5:0]=RS422 Satelite mode and node# (Technical Bowling).
(*keep*)wire    ADC_CS = (MSHA[4:1]==5'h1f>>1);	// 8ch. [2:0] Write=Select Chan. Read=Chan data with chan auto-inc.
	

// Serial FLAG reg notes. (from MAME).
//	
// RS-422 status
// 7--- ----  RX2IE
// -6-- ----  RX1IE some I-error ?
// --5- ----  RX2FE
// ---4 ----  RX1FE framing error ?
// ---- 3---  RX2BF
// ---- -2--  RX1BF 1 = receive buffer full
// ---- --1-  TX2BF
// ---- ---0  TX1BF 1 = transmit buffer full
reg [7:0] FLAG_REG;


// MODE reg notes. (from MAME).
//
// 7--- ----  port G counter mode
// -6-- ----  ?
// --5- ----  RS-422 satellite mode
// ---4 ----  RS-422 loopback
// ---- 3210  RS-422 satellite N#
reg [7:0] MODE_REG;

wire PORTG_MODE       = MODE_REG[7];
wire RS422_SAT        = MODE_REG[5];
wire RS422_LOOP       = MODE_REG[4];
wire [4:0] RS422_NODE = MODE_REG[3:0];


// PORTG Counters, and Read mux.
reg  [7:0] PORTG_CTR [0:3];
wire [7:0] CTR_MUX = (PORTG_MODE) ? PORTG_CTR[PORTG_OUT[2:1]] : 8'hff;


reg [7:0] DIR_REG;
reg [7:0] TXD1_REG;
reg [7:0] TXD2_REG;

reg [2:0] ADC_SEL;
always @(posedge CLK or negedge RST_N)
if (!RST_N) begin
		 PORTD_OUT <= 8'h00;		// Clear the Output regs.
		 PORTF_OUT <= 8'h00;
		 PORTG_OUT <= 8'h00;
	 PORTG_CTR[0] <= 8'h00;	// Zero the Counters?
	 PORTG_CTR[1] <= 8'h00;
	 PORTG_CTR[2] <= 8'h00;
	 PORTG_CTR[3] <= 8'h00;
			DIR_REG <= 8'hff;		// Set all ports to INPUTs on reset. (MAME)
		  FLAG_REG <= 8'h0C;		// HACK: Receive buffers always Full, Transmit buffers always Empty. (MAME)
		  MODE_REG <= 8'h00;		// Clear MODE reg on reset. (MAME)
			ADC_SEL <= 3'd0;
end
else begin
	// Not sure if checking for MSHBS_N (Bus Strobe) Low is correct?
	// May need to check for the rising edge of MSHBS_N, for more correct timing?
	if (STV_IO_CS && !MSHBS_N) begin
		if (MSHRD_WR_N) begin	// READs.
			// Might need to delay this, so it increments AFTER the current ADC channel has been read? ElectronAsh.
			if (ADC_CS) ADC_SEL <= ADC_SEL + 3'd1;
		end
		else begin					// WRITEs.
			if (PORTD_CS) PORTD_OUT <= MSHDO[7:0];
			if (PORTF_CS) PORTF_OUT <= MSHDO[7:0];
			if (PORTG_CS) PORTG_OUT <= MSHDO[7:0];
			if (DIR_CS)     DIR_REG <= MSHDO[7:0];
			if (TXD1_CS)   TXD1_REG <= MSHDO[7:0];
			if (TXD2_CS)   TXD2_REG <= MSHDO[7:0];
			if (MODE_CS)   MODE_REG <= MSHDO[7:0];
			if (ADC_CS)     ADC_SEL <= MSHDO[2:0];
		end
	end
	
	// Spoofing counters for now. Trying to get a game (ANY game) to boot!
	PORTG_CTR[0] <= PORTG_CTR[0]+8'd1;
	PORTG_CTR[1] <= PORTG_CTR[1]+8'd1;
	PORTG_CTR[2] <= PORTG_CTR[2]+8'd1;
	PORTG_CTR[3] <= PORTG_CTR[3]+8'd1;
end


assign STV_IO_DOUT = PORTA_CS ? {4{P1_CONT}}		:	// 0x01. P1.
							PORTB_CS ? {4{P2_CONT}}		:	// 0x03. P2.
							PORTC_CS ? {4{SYS_CONT}}	:	// 0x05. PORTC = SYSTEM (input).
							PORTD_CS ? {4{PORTD_OUT}}	:	// 0x07. PORTD = (output / readback).
							PORTE_CS ? {4{P3_CONT}}		:	// 0x09. P3.
							PORTF_CS ? {4{P4_CONT}}		:	// 0x0b. P4 / Extra 6-button Layout.
							PORTG_CS ? {4{CTR_MUX}} 	:	// 0x0d. PORTG = Counters.
							  DIR_CS ? {4{DIR_REG}}		:	// 0x11. IO Port DIRection reg.
							 TXD1_CS ? {4{TXD1_REG}}		:	// 0x13. 
							 TXD2_CS ? {4{TXD2_REG}}		:	// 0x15. 
							 RXD1_CS ? {4{TXD1_REG}}		:	// 0x17. (trying loopback from TXD1 atm)
							 RXD2_CS ? {4{TXD2_REG}}		:	// 0x19. (trying loopback from TXD2) 
							 FLAG_CS ? {4{FLAG_REG}}	:	// 0x1b. Serial COM READ status.
							 MODE_CS ? {4{MODE_REG}}	:	// 0x1d.
							  ADC_CS ? {4{ADC_MUX}}		:	// 0x1f. Read ADC channel(s).
										  32'h00ff00ff;		// Default / Open bus.

endmodule
