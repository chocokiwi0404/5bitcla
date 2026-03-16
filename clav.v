module propgen (
	input wire [4:0] a,
	input wire [4:0] b,
	output wire [4:0] p,
	output wire [4:0] g
);
	xor x0(p[0], a[0], b[0]);
	xor x1(p[1], a[1], b[1]);
	xor x2(p[2], a[2], b[2]);
	xor x3(p[3], a[3], b[3]);
	xor x4(p[4], a[4], b[4]);
	and a0(g[0], a[0], b[0]);
	and a1(g[1], a[1], b[1]);
	and a2(g[2], a[2], b[2]);
	and a3(g[3], a[3], b[3]);
	and a4(g[4], a[4], b[4]);

endmodule

module sum (
	input wire [4:0] p,
	input wire [4:0] c,
	output wire [4:0] s
);
	xor s0(s[0], p[0], c[0]);
	xor s1(s[1], p[1], c[1]);
	xor s2(s[2], p[2], c[2]);
	xor s3(s[3], p[3], c[3]);
	xor s4(s[4], p[4], c[4]);

endmodule

module cla5 (
	input wire [4:0] a,
	input wire [4:0] b,
	input c0,   
	output wire [4:0] s,
	output cout  
);

	wire [4:0] p, g;
	wire [4:0] c;

	propgen pg(a, b, p, g);

	wire a10;
	and (a10, p[0], c0);
	or (c[1], g[0], a10);

	wire a20, a21;
	and (a20, p[1], g[0]);
	and (a21, p[1], p[0], c0);
	or (c[2], g[1], a20, a21);

	wire a30, a31, a32;
	and (a30, p[2], g[1]);
	and (a31, p[2], p[1], g[0]);
	and (a32, p[2], p[1], p[0], c0);
	or (c[3], g[2], a30, a31, a32);

	wire a40, a41, a42, a43;
	and (a40, p[3], g[2]);
	and (a41, p[3], p[2], g[1]);
	and (a42, p[3], p[2], p[1], g[0]);
	and (a43, p[3], p[2], p[1], p[0], c0);
	or (c[4], g[3], a40, a41, a42, a43);

	wire a50, a51, a52, a53, a54;
	and (a50, p[4], g[3]);
	and (a51, p[4], p[3], g[2]);
	and (a52, p[4], p[3], p[2], g[1]);
	and (a53, p[4], p[3], p[2], p[1], g[0]);
	and (a54, p[4], p[3], p[2], p[1], p[0], c0);
	or (cout, g[4], a50, a51, a52, a53, a54);

	assign c[0] = c0;
	sum si(p, c, s);

endmodule