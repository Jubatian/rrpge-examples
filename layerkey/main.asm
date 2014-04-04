;
; Colorkeyed multilayer example
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv1 (version 1 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv1 in the project root.
;
;
; Enables two display layers using colorkeys, also using the background layer
; for a "raster" effect.
;


include "../rrpge.asm"
bindata "tiles.bin" h, 0x100
bindata "../logo_rle.bin" h, 0x300


section cons

	db "RPA\n"
	db "\nAppAuth: Jubatian        "
	db "\nAppName: Example program: Multiple layers  "
	db "\nVersion: 00.000.001"
	db "\nEngSpec: 00.001.000"
	db "\nLicense: RRPGEv1\n\n"
	db 0

org 0xBC0

	dw 0x0000, 0x0000, 0x0100, 0x0000, 0xF800

org 0xB00

	; Background display list pattern ("raster" effect)

bgpt:	dw 0x0000, 0x0A0A, 0xAAAA, 0xA2A2, 0x2222, 0xA2A2, 0xAAAA, 0x0A0A
	dw 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000
bgpte:


section data

auitc:	ds 1			; Audio interrupt counter

tmap:	ds 250			; 40 x 25 4bit tile map (1000 tiles)
tmape:


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

	jsv {kc_mem_banksame, 15, 0x8030}
	mov x3,    0x0100	; Tiles
	mov x2,    0xF000	; Target area
tcopy:	mov a,     [x3]
	mov [x2],  a
	xeq x3,    0x0300	; 8x 16x16 4bit tiles: 0x200 words
	jmr tcopy

	; Fill remaining tile data (16 tiles) with white, which will be set the
	; colorkey (no tile uses white)

	mov a,     0x3333
twht:	mov [x2],  a
	xeq x2,    0xF400
	jmr twht

	; Use the wave effect to set up display lists

	jfa effwave {0, 0, 0, 0, 0x2000}
	jfa effwave {0, 0, 0, 0, 0x2400}

	; Load RLE image

	jfa rledec {0x3, 0xE800, 0, 0x3000, 0x8000, 0x0000, PAGE_ROPD, 0xC00, 0x1230}

	; Change Layer 0's colorkey to white

	mov a,     0x0003	; Colorkey: White
	mov x3,    0x2400
l0ckl:	add x3,    1
	or  [x3],  a		; Add the colorkey
	xeq x3,    0x2720
	jmr l0ckl

	; Set up tiles on Layer 0

	mov d,     0
tllp:	jfa tile_row {d}
	add d,     1
	xeq d,     25
	jmr tllp

	; Alter background display list to enable Layer 0

	mov x3,    0x2800	; Background display list
	mov a,     0x0001	; Changes layer config from 0 to 1
l2ena:	or  [x3],  a
	add x3,    1
	xeq x3,    0x2B20
	jmr l2ena

	; Set up events

	mov a,     0x180
	mov [auitc], a
	jsv {kc_vid_sethnd, video_ev, 400}
	jsv {kc_aud_sethnd, audio_ev}

	; Idle main loop

lmain:	jmr lmain



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

	mov xm2,   PTR16I
	mov xm1,   PTR16I
	mov x3,    [auitc]	; Real time sync

	; Load a value from the large ROPD sine table by x3

	mov x2,    x3
	and x2,    0x1FF
	add x2,    0xE00	; Offset of large sine (-0x4000 - 0x4000)
	mov a,     [x2]

	; Run wave effect

	mov b,     a
	add b,     0x4000	; 0x0000 - 0x8000
	shr b,     9		; 0x00 - 0x40
	jfa effwave {0, 0, x3, b, 0x2000}

	; Some rasterpuke to the background layer

	mov x2,    x3
	shr x2,    1
	and x2,    0xF
	add x2,    bgpt
	mov x1,    0x2800	; Background display list
.rasl:	mov a,     [x2]
	xne x2,    bgpte
	mov x2,    bgpt
	add x1,    1
	mov [x1],  a		; Update pattern
	xeq x1,    0x2B20
	jmr .rasl

	rfn



;
; Output a row of tile data.
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
	mov a,     1
	mov [x3],  a		; Source high (Video RAM bank)
	mov [x3],  a		; Destination high (Video RAM bank)

	; For each tile 4 accelerator ops are required. There are 40 tiles to
	; blit in a row.

	mov b,     1280		; Size of a tile row in VRAM cells
	mul b,     [bp + 0]	; Destination start
	mov x2,    40		; Size of a tile row in the tile map
	mul x2,    [bp + 0]	; Tile map start
	mov c,     tmap
	shl c,     2
	add x2,    c
	mov xm2,   PTR4I
	mov xh2,   0

	; Blit the tile row. One accelerator operation takes 20 + (16 * 6) =
	; 116 cycles, to blit the row 80 such operations are needed, with
	; overhead approx. 10K cycles.

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
	xeq x3,    40
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
; Additional code modules
;

include "rledec.asm"
include "effwave.asm"
