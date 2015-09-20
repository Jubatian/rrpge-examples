;
; Graphics Display Generator example program
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2015, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;
;
; Shows various effects possible by the Graphics Display Generator, mostly
; the use of sprites.
;


include "../rrpge.asm"

AppAuth db "Jubatian"
AppName db "Example: GDG Sprites"
Version db "00.000.018"
EngSpec db "00.018.000"
License db "RRPGEvt", "\n"
        db 0



section data

font_rle:
bindata "font_rle.bin"

logo_rle:
bindata "../logo_rle.bin"

tiles:
bindata "tilessm.bin"

	;  |<--------- 30 chars --------->|
txt0:	db "   RETRO REVOLUTION PROJECT   "
txt1:   db "         GAME ENGINE          "

	; Rasterbar patterns

rbars:	dw 0x0A0A, 0xAAAA, 0xAFAF, 0xFFFF, 0xFFFF, 0xFAFA, 0xAAAA, 0xA0A0



section zero

colps:	ds 30			; Text column positions
rowps:	ds 25			; Row positions
rasps:	ds 8			; Rasterbar positions



section code

main:

	; Display list  usage:
	; Column 0: BG: Rasterbars
	; Column 1: Waving tile pattern, PRAM bank 2
	; Column 2: RRPGE Logo, PRAM bank 0, low half
	; Column 9-31: 23 sprite columns

	; Set up GDG sources. Source A0 is OK with the default setup (0x0050,
	; 80 column wide positioned source on PRAM bank 0, used for the RRPGE
	; Logo)

	mov x3,    P_GDG_SA1
	mov a,     0x2086	; Waving tile pattern: 128 cell wide shift ...
	mov [x3],  a		; ... source on PRAM bank 2
	mov a,     0x1001	; Sprites (text): 2 cell wide positioned ...
	mov [x3],  a		; ... source on high half of PRAM bank 1

	; Clear default display list (getting rid of default display)

	jfa us_dlist_clear {DLDEF_0_32}

	; Pre-fill Column 2 of the lists (stationary). Just shows the dragon
	; from PRAM bank 0, leaving the bottom 145 lines unused, so the waving
	; text can get enough GDG cycles to render.

	jfa us_dlist_add {0x1040, 0x0400, 255, 2, DLDEF_0_32, 0}
	jfa us_dlist_add {0x1040, 0x0400, 255, 2, DLDEF_1_32, 0}

	; Prepare sprites: give columns 9 - 31 inclusive (23 cols) to them.

	jfa us_smux_setbounds {9, 23}

	; Prepare for double buffering, setting the display lists.
	; Display list clear setup: needs to clear the background and columns
	; 9-31. On the first line clearing the bg. is skipped since it is not
	; possible to form a suitable clear command containing it.
	; Initial cells to skip:         9 (=> 0x4800)
	; Cells to clear in a streak:   24 (=> 0x0018)
	; Cells to skip after a streak:  8 (=> 0x0200)

	jfa us_dbuf_init {DLDEF_0_32, DLDEF_1_32, 0x4A18}

	; Decode RLE encoded logo into it's display location, using the high
	; half of PRAM bank 0 for temporarily storing the RLE encoded stream

	jfa us_copy_pfc {0x0001, 0x0000, logo_rle, 1927}
	jfa rledec {0x3, 0xE800, 0, 0xFFFF, 0x0000, 0x0000, 0x0010, 0x0000, 0x1230}

	; Decode RLE encoded font to high half of PRAM bank 1, making them
	; directly available as sprites

	jfa us_copy_pfc {0x0001, 0x0000, font_rle, 570}
	jfa rledec {  0,   9216, 0, 0xFFFF, 0x0030, 0x0000, 0x0010, 0x0000, 0x3000}

	; Initially display nothing, will reveal in the main loop (the dragon
	; logo however RLE decodes on-screen as a crude effect)

	jfa us_dlist_setbounds {200, 200}

	; Using the noise data in PRAM, fill up PRAM page 2 with tiles. The
	; noise data with its reductions as 4 bit source is enough for 16 rows
	; of tile data, the remaining 9 rows are copied.

	jfa us_ptr_set4i {1, up1h_smp, up1l_smp_nois1}
	mov a,     0
.tilp:	jfa tilecopy {[P1_RW], 0x0004, a, 256}
	add a,     4
	mov b,     a
	and b,     0xFF
	xne b,     0
	add a,     0x0F00	; Row complete, next row
	jnz a,     .tilp	; First half done
	jfa us_copy_pfp {0x0005, 0x0000, 0x0004, 0x0000, 0x9000}

	; Register 'b' is used to reveal the background and text by setting
	; the vertical bounds for the display list & sprite managers

	mov b,     0

	; Enter main loop

.lm:	jfa us_dbuf_flip

	mov a,     [P_CLOCK]
	shr a,     2

	mov x0,    200
	sub x0,    b
	mov x1,    200
	add x1,    b
	jfa us_dlist_setbounds {x0, x1}
	xug b,     199
	add b,     1

	jfa sinewave {colps, 30, a, 300,    70, 14}
	jfa sinewave {rowps, 25, a,   0, 0x100,  5}
	jfa sinewave {rasps,  8, a, 200, 0x100,  5}
	jfa renderrows {rowps}
	jfa renderbars {rasps, rbars}
	jfa rendertext {colps, txt0}

	jms .lm



;
; Simple, slow tile copy
;
; Copies the given tile index (only 0-5 gives a tile) to the passed location
; of the given pitch (width in cells).
;
; param0: Tile index to copy
; param1: Target PRAM word offset, high
; param2: Target PRAM word offset, low
; param3: Pitch (target width) in word units
;
; Uses PRAM pointer 3, not preserved.
;
tilecopy:

.stl	equ	0		; Source tile index
.toh	equ	1		; Target offset high
.tol	equ	2		; Target offset low
.tpt	equ	3		; Target pitch

	; Save CPU regs

	psh d
	xch a,     [$.stl]	; Save 'a' and load source tile index
	xch b,     [$.tpt]	; Save 'b' and load target pitch

	; Check source tile index, convert to offset or exit

	xug 6,     a
	jms .exit
	shl a,     6		; One tile is 64 words
	add a,     tiles	; Start offset within CPU RAM

	; Copy the tile to the target area

	mov d,     16
.lp:	jfa us_copy_pfc {[$.toh], [$.tol], a, 4}
	add c:[$.tol], b
	add [$.toh], c
	add a,     4
	sub d,     1
	jnz d,     .lp

.exit:	; Restore CPU regs & exit

	mov a,     [$.stl]
	mov b,     [$.tpt]
	pop d
	rfn c:x3,  0



;
; Fills in the position data with sine, to wave stuff
;
; param0: Offset of buffer to fill in with sine
; param1: Buffer size
; param2: Sine start offset (low 8 bits used)
; param3: Shift for the sine (add)
; param4: Multiplier for the sine (max. 0x100)
; param5: Sine increment
;
; Uses PRAM pointer 3, not preserved.
;
sinewave:

.sof	equ	0		; Sine buffer start offset
.siz	equ	1		; Sine buffer size
.sst	equ	2		; Sine start offset
.shf	equ	3		; Shift (add value)
.mul	equ	4		; Multiplier
.inc	equ	5		; Sine increment

	; Save CPU regs

	xch a,     [$.sst]	; Load sine start & save 'a'
	xch b,     [$.siz]	; Load sine buffer size & save 'b'

	; Set up sine pointer

	mov c,     3
	shl [$.inc], c		; Increment converted to bit units
	and a,     0xFF		; Sine start offset
	shl a,     3		; Shifted to bit address
	add a,     up1l_smp_sine
	jfa us_ptr_setgen {3, up1h_smp, a, 0, [$.inc], 3}

	; Prepare target and loop count

	mov x3,    [$.sof]
	add b,     x3		; Termination offset from size

.lp:	; Load sine, from the small sine table in the ROPD, and center it
	; (2's complement). Then increment sine offset

	mov c,     [P3_RW]
	btc [P3_AL], 11		; Wrap around sine (don't let it reach the reductions)
	sub c,     0x80		; Center the sine (2's complement)

	; Apply multiplier, and calculate target value

	mul c,     [$.mul]
	asr c,     8
	add c,     [$.shf]

	; Save target value, and end loop

	mov [x3],  c
	xeq x3,    b
	jms .lp

	; Restore CPU regs & exit

	mov a,     [$.sst]
	mov b,     [$.siz]
	rfn c:x3,  0



;
; Renders the rasterbars
;
; param0: Offset of rasterbar positions
; param1: Rasterbar patterns
;
; Uses PRAM pointer 2 and 3, not preserved.
;
renderbars:

.rps	equ	0		; Rasterbar positions
.rpt	equ	1		; Rasterbar patterns

	; Save CPU regs

	psh a, x0, x2, xm

	; Simple, slow solution. Faster would be possible by writing specific
	; routine to do this instead of calling us_dlist_db_addbg for one line
	; each.

	mov x0,    [$.rps]
	mov x2,    [$.rpt]
	mov xm,    0x6666	; Everything PTR16I
	mov a,     8		; 8 rasterbars
.lp:	mov c,     [x2]
	jfa us_dlist_db_addbg {c, c, 1, [x0]}
	sub a,     1
	jnz a,     .lp

	; Restore CPU regs & exit

	pop a, x0, x2, xm
	rfn c:x3,  0



;
; Renders the waving rows
;
; param0: Offset of row positions
;
; Uses PRAM pointers 2 and 3, not preserved.
;
renderrows:

.rps	equ	0		; Row positions

	; Save CPU regs

	psh a, b, d, x2, xm

	; 25 rows of tiles, shift source for scrolling background, so no X,
	; but produce a wrapping position

	mov x2,    [$.rps]
	mov xm2,   PTR16I
	mov a,     0x0000	; Render command high
	mov d,     0		; Y position
.lp:	mov b,     0x03FF	; Low 10 bits are position
	and b,     [x2]
	or  b,     0x0400	; High half-palette 1 selected
	or  b,     0x2000	; Source definition A1 selected
	jfa us_dlist_db_add {a, b, 16, 1, d}
	add a,     2048
	add d,     16
	xeq d,     400
	jms .lp

	; Restore CPU regs & exit

	pop a, b, d, x2, xm
	rfn c:x3,  0



;
; Renders the text by the column positions
;
; param0: Offset of column Y start positions
; param1: Offset of text (2 rows of 30 chars each)
;
rendertext:

.cps	equ	0		; Column positions
.tof	equ	1		; Text start offset

.cpe	equ	2		; End column position for X loop termination
.ade	equ	3		; End adjust position for Y loop termination

	mov sp,    4

	; Save CPU regs

	psh a, b, d, x1, x2, xm, xb

	; There are 2 rows, 30 characters each text, add those to the display
	; list as needed.

	mov xm,    0x6866	; X3: PTR16I, X2: PTR8I, X1: PTR16I, X0: PTR16I
	mov x2,    [$.tof]
	mov xb2,   0		; Pointer for text prepared in X2

	; Prepare loop terminators

	mov c,     30
	add c,     [$.cps]
	mov [$.cpe], c		; Inner (X) loop termination
	mov c,     80
	mov [$.ade], c		; Outer (Y) loop termination

	; Text render loop

	mov d,     0		; Row adjust amount
.l0:	mov x1,    [$.cps]
	mov a,     22		; Starting X position
.l1:	jfa getcharcomm {[x2]}	; Load character's render command
	mov b,     [x1]		; Load column position (Y)
	xne x3,    0
	jms .nsp		; Zero render command: no sprite to draw
	add b,     d		; Row adjust Y
	jfa us_smux_addxy {x3, 0x4400, 16, 0, a, b}
.nsp:	add a,     20		; Next X position
	xeq x1,    [$.cpe]	; Inner (X) loop terminates after 30 chars
	jms .l1
	add d,     40		; For next text row (Y adjust)
	xeq d,     [$.ade]	; Outer (Y) loop terminates after 2 rows
	jms .l0

	; Restore CPU regs & exit

	pop a, b, d, x1, x2, xm, xb
	rfn c:x3,  0



;
; Returns high part of render command to produce a character. Returns 0 if the
; character should not be rendered (should not take a sprite).
;
; param0: Character to produce: ' '; 'A' - 'Z'; '0' - '9'
; Ret.X3: High part of render command for the character
;
getcharcomm:

.chr	equ	0		; Character to produce

	mov x3,    [$.chr]
	xug '0',   x3
	jms .l0
.spc:	mov x3,    0
	rfn
.l0:	xug x3,    '9'
	jms .num
	xug 'A',   x3
	jms .l1
	jms .spc
.l1:	xug x3,    'Z'
	jms .alf
	jms .spc
.num:	sub x3,    '0'
	shl x3,    5
	add x3,    0x8340
	rfn
.alf:	sub x3,    'A'
	shl x3,    5
	add x3,    0x8000
	rfn



;
; Additional code modules
;

include "rledec.asm"
