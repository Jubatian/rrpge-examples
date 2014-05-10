;
; Sprites & Tiles example program
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;
;
; A simple race with the beam style tile & sprite example showing some uses of
; the accelerator. Note that on the minimal RRPGE implementation it is barely
; possible to fill an entire 640x400 display with the accelerator before the
; beam takes over, so only 480 pixels width is used. However real uses of this
; rendering style are possible if the regions needing updating are correctly
; identified.
;


include "../rrpge.asm"
bindata "tiles.bin" h, 0x100

section cons

	db "RPA\n"
	db "\nAppAuth: Jubatian        "
	db "\nAppName: Example program: Sprites and Tiles"
	db "\nVersion: 00.000.002"
	db "\nEngSpec: 00.004.001"
	db "\nLicense: RRPGEv2\n\n"
	db 0

org 0xBC0

	dw 0x0000, 0x0000, 0x0100, 0x0000, 0xF800


org 0x300

	; A simple sprite

spr:	dw 0x0000, 0x0000, 0x0000, 0x0000
	dw 0x0000, 0x0333, 0x3330, 0x0000
	dw 0x0003, 0x3333, 0x3333, 0x3000
	dw 0x0033, 0x3300, 0x0033, 0x3300
	dw 0x0033, 0x3000, 0x0003, 0x3300
	dw 0x0333, 0x0000, 0x0000, 0x3330
	dw 0x0330, 0x0000, 0x0000, 0x0330
	dw 0x0330, 0x0000, 0x0000, 0x0330
	dw 0x0330, 0x0000, 0x0000, 0x0330
	dw 0x0330, 0x0000, 0x0000, 0x0330
	dw 0x0333, 0x0000, 0x0000, 0x3330
	dw 0x0033, 0x3000, 0x0003, 0x3300
	dw 0x0033, 0x3300, 0x0033, 0x3300
	dw 0x0003, 0x3333, 0x3333, 0x3000
	dw 0x0000, 0x0333, 0x3330, 0x0000
	dw 0x0000, 0x0000, 0x0000, 0x0000
spre:


section data

auitc:	ds 1			; Audio interrupt counter
vidfr:	ds 1			; Video event frameskip

tmap:	ds 250			; 40 x 25 4bit tile map (1000 tiles)
tmape:

sprp:	ds 200			; Sprite X and Y locations
sprpe:				; Y locations must be incremential!

section code

	mov xm3,   PTR16I
	mov xm2,   PTR16I

	; Fill tile map using the noise data

	mov x3,    0x1B00	; Noise
	mov x2,    tmap
tfill:	mov a,     [x3]
	mov [x2],  a
	xeq x2,    tmape
	jmr tfill

	; Copy tile data in Video RAM

	jsv {kc_mem_banksame, 15, 0x8010}
	mov x3,    0x0100	; Tiles
	mov x2,    0xF000	; Target area
tcopy:	mov a,     [x3]
	mov [x2],  a
	xeq x3,    0x0300	; 8x 16x16 4bit tiles: 0x200 words
	jmr tcopy

	; Copy sprite in Video RAM

	mov x3,    spr		; Sprite
	mov x2,    0xF400	; Target area
scopy:	mov a,     [x3]
	mov [x2],  a
	xeq x3,    spre
	jmr scopy

	; Set up display list for 640x400. Only need to set a 80 increment for
	; lines 1 - 399, in the whole part.

	mov a,     80
	mov x3,    0x2002
ldls:	mov [x3],  a		; Write whole part only
	add x3,    1
	xeq x3,    0x2320
	jmr ldls

	; Initial sprite fill: none visible

	mov a,     0x7FFF
	mov x3,    sprp
sfill:	mov [x3],  a
	xeq x3,    sprpe
	jmr sfill

	; Set up events

	jsv {kc_vid_sethnd, video_ev, 16}
	jsv {kc_aud_sethnd, audio_ev}
	mov x3,    [auitc]	; x3: real time sync

	; Main loop: Sprite sine wave effect

	mov xm2,   PTR16I
	mov xm1,   PTR8I
	mov xh1,   0

lmaiw:	jsv {kc_dly_delay, 0xFFFF}
lmain:	mov c,     [auitc]
	xne c,     x3
	jmr lmaiw		; Wait for an audio tick (real time sync)
	mov x3,    c

	; Produce sprite X's

	mov x1,    0x3100	; Sine wave
	mov a,     x3
	and a,     0xFF
	add x1,    a		; Go around in the sine
	mov x2,    sprp
	mov b,     x2
	add b,     128
xlp:	mov a,     [x1]
	xne x1,    0x3200
	mov x1,    0x3100	; Wrap sine
	add x1,    1
	xne x1,    0x3200
	mov x1,    0x3100	; Wrap sine
	add a,     192		; Center
	mov [x2],  a
	add x2,    1
	xeq x2,    b
	jmr xlp

	; Produce sprite Y's (this could have been pre rendered, but here it
	; is easier to add an effect)

	mov a,     7
	mov x2,    sprp
	mov b,     x2
	add b,     128
ylp:	add x2,    1
	mov [x2],  a
	add a,     7
	xeq x2,    b
	jmr ylp

	; End of main loop

	jmr lmain




;
; Audio event (all registers are saved by the kernel)
;
; param0: Left / Mono target sample pointer in sample (byte) units
; param1: Right target sample pointer in sample (byte) units
;

audio_ev:
	mov a,     1
	add [auitc], a
	rfn



;
; Video event (all registers are saved by the kernel)
;

video_ev:

	mov a,     [vidfr]
	add a,     1
	xne a,     2		; Render every second frame only
	jmr .rstr
	mov [vidfr], a
	rfn			; No rendering this time

.rstr:	mov a,     0
	mov [vidfr], a

	; Set up tile row & sprite indices

	mov b,     0		; Tile row waiting to be rendered
	mov x1,    sprp		; Sprite waiting to be rendered
	mov xm1,   PTR16I

	; Set up assumed initial graphics output line

	mov x0,    16		; Enters on line 16

	; Rendering loop entry

.rloop:

	; Wait for the beam passing the currentrly waiting tile row's bottom
	; Normally since the tile row rendering takes more time than 16 lines,
	; no busy waiting should happen, however on faster RRPGE
	; implementations it may be necessary.

	mov c,     b
	shl c,     16
	add c,     15		; Line to pass
.wait:
	jsv {kc_vid_getline}
	xbc a,     15
	mov x0,    400		; Negative: Reached VBlank
	xsg x0,    a		; (don't override with lines from next frame)
	mov x0,    a		; Advanced some lines
	xug x0,    c		; If x0 > c happens, it is OK, can render
	jmr .wait

	; Render a tile row and any sprites on this row

	jfa tile_row {b}
	add b,     1
	mov a,     b
	shl a,     4		; Terminating line where sprite shouldn't render
	sub a,     16		; Sprite max. height is 16 pixels
.sprn:	mov c,     [x1]
	mov d,     [x1]
	xsg a,     d		; Not reached the render limit?
	jmr .spre
	jfa sprite {c, d}	; OK, render sprite
	jmr .sprn
.spre:	sub x1,    2		; Throw back for next time

	; When all rows are complete, the rendering is over

	xeq b,     25
	jmr .rloop
	rfn



;
; Output a row of tile data. Note that only the middle 30 tiles are output,
; sprite movement is also constrained to this region.
;
; param0: The row to produce
;

tile_row:
	mov sp,    8
	mov [bp + 1], xm
	mov [bp + 2], x3
	mov [bp + 3], x2
	mov [bp + 4], a
	mov [bp + 5], b
	mov [bp + 6], c
	mov [bp + 7], d

	; Set up common accelerator configuration. A Block Blitter will be
	; used, filling the tiles in vertical strips to require less
	; operations.

	mov xm3,   PTR16I
	mov x3,    0x2EF3	; Start with destination fraction
	mov a,     0
	mov [x3],  a		; Destination fraction
	mov a,     2
	mov [x3],  a		; Source increment (16 pixels tile width)
	mov a,     80
	mov [x3],  a		; Destination increment whole (640 pixels)
	add x3,    1		; Skip reindex bank select
	mov a,     0x80FF
	mov [x3],  a		; Source partition, rotate, AND mask
	mov a,     0x0000
	mov [x3],  a		; Mode, colorkey
	mov a,     128
	mov [x3],  a		; Number of pixels to process (128 in a strip)
	mov a,     0
	mov [x3],  a		; Source high (Video RAM bank)
	mov [x3],  a		; Destination high (Video RAM bank)

	; For each tile 4 accelerator ops are required. There are 30 tiles to
	; blit in a row.

	mov b,     1280		; Size of a tile row in VRAM cells
	mul b,     [bp + 0]	; Destination start
	add b,     10		; Offset since only 30 columns are output
	mov x2,    40		; Size of a tile row in the tile map
	mul x2,    [bp + 0]	; Tile map start
	add x2,    5		; Offset since only 30 columns are output
	mov c,     tmap
	shl c,     2
	add x2,    c
	mov xm2,   PTR4I
	mov xh2,   0

	; Blit the tile row. One accelerator operation takes 20 + (16 * 6) =
	; 116 cycles, to blit the row 60 such operations are needed, with
	; overhead approx. 8K cycles.

	mov x3,    0
.cloop:	mov c,     [x2]		; Tile to blit
	shl c,     5		; Start offset in VRAM cells
	add c,     0x8000	; Tiles are expanded here in the VRAM
	mov d,     0		; Count 2 strips
.tloop:	mov [0x2EF0], c		; Source start
	mov [0x2EF2], b		; Destination start
	mov [0x2EFF], a		; Start operation (value indifferent)
	add c,     1
	add b,     1
	add d,     1
	xeq d,     2
	jmr .tloop
	add x3,    1
	xeq x3,    30
	jmr .cloop

	; Return

	mov xm,    [bp + 1]
	mov x3,    [bp + 2]
	mov x2,    [bp + 3]
	mov a,     [bp + 4]
	mov b,     [bp + 5]
	mov c,     [bp + 6]
	mov d,     [bp + 7]
	rfn



;
; Output a sprite
;
; param0: X location
; param1: Y location
;

sprite:

	mov sp,    6
	mov [bp + 2], xm
	mov [bp + 3], x3
	mov [bp + 4], a
	mov [bp + 5], b

	; Set up accelerator configuration. A Block Blitter will be used, now
	; filling in the usual order as the sprite will not necessarily end up
	; on a tile boundary. A bit of cheating is here: Does not set up the
	; Source partition / rot / AND mask field and Video RAM banks assuming
	; it is already done (the tile blitter does it)

	mov xm3,   PTR16I
	mov x3,    0x2EF0	; Start with source
	mov a,     0x8200	; Sprite is loaded here in VRAM
	mov [x3],  a		; Source start
	mov x3,    0x2EF4	; Source increment
	mov a,     1
	mov [x3],  a		; Source increment
	mov [x3],  a		; Destination increment
	add x3,    2		; Skip reindex & partition
	mov a,     0x0200
	mov [x3],  a		; Mode, colorkey (ck. enabled, color index 0)
	mov a,     16
	mov [x3],  a		; Number of pixels to process (16 in a row)

	; Calculate destination from X:Y

	mov a,     [bp + 1]	; Y location
	mul a,     80		; 80 cells in a row
	mov b,     [bp + 0]	; X location
	shr b,     3		; Cell location
	add b,     a		; b: Destination whole
	mov x3,    [bp + 0]
	shl x3,    13		; c: Destination fraction
	mov [0x2EF3], x3	; This will be fixed through the blit

	; Perform the sprite blit, 16 rows. One accelerator operation takes
	; 20 + (2 * 6) = 32 cycles, with overhead may total to approx. 600
	; cycles.

	mov x3,    16
.sloop:	mov [0x2EF2], b		; Destination start
	mov [0x2EFF], a		; Start operation (value indifferent)
	add b,     80		; Next row
	sub x3,    1
	xeq x3,    0
	jmr .sloop

	; Return

	mov xm,    [bp + 2]
	mov x3,    [bp + 3]
	mov a,     [bp + 4]
	mov b,     [bp + 5]
	rfn
