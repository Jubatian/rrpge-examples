;
; Graphics Display Generator example program
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;
;
; Shows various effects possible by the Graphics Display Generator, mostly
; the use of sprites.
;


include "../rrpge.asm"
bindata "font_rle.bin"    h, 0x6A
bindata "../logo_rle.bin" h, 0x2A4
bindata "tilessm.bin"     h, 0xA2C

section cons

	db "RPA\n"
	db "\nAppAuth: Jubatian        "
	db "\nAppName: Example program: GDG sprites      "
	db "\nVersion: 00.000.003"
	db "\nEngSpec: 00.008.000"
	db "\nLicense: RRPGEv2\n\n"
	db 0

	;  |<--------- 30 chars --------->|
txt0:	db "   RETRO REVOLUTION PROJECT   "
txt1:   db "         GAME ENGINE          "

org 0xBC0

	dw 0x0000, 0x0000, 0x0100, 0x0000, 0xF800

org 0xBAC

	; Graphics configuration for the sprite library

gconf:	dw 0x5000, 0x01FE, 0x1020, 0x4080
	dw 0x0014, 0x2041, 0x4041, 0x6041
	dw 0x00A7, 0x8083, 0x00C3, 0x80C3

	; Rasterbar patterns

rbars:	dw 0x0A0A, 0xAAAA, 0xAFAF, 0xFFFF, 0xFFFF, 0xFAFA, 0xAAAA, 0xA0A0



section data

sprt_data	equ	0x4000	; Internal data (512 words) for the sprite library
sprt_list	equ	0x8000	; Display list for the sprite library

colps:	ds 30			; Text column positions
rowps:	ds 25			; Row positions
rasps:	ds 8			; Rasterbar positions



section code

	; Bank in area for a large display list in the upper half of the CPU
	; address space. Note that this area is sufficient for the largest
	; display list, however the example uses smaller (offering 15 graphics
	; elements per line).

	mov a,     8
	mov b,     0x4008
membl:	jsv {kc_mem_banksame, a, b}
	add a,     1
	add b,     1
	xug a,     15
	jmr membl

	; Switch to 16 color 640x400 mode

	jsv {kc_vid_mode, 0}

	; Prepare graphics & display list so the loading below will fill it up
	; giving some initialization effect

	jfa sinewave {colps, 30, 0, 300,    70, 14}
	jfa sinewave {rowps, 25, 0,   0, 0x100,  5}
	jfa sinewave {rasps,  8, 0, 200, 0x100,  5}
	jfa gdgsprit_init {sprt_data, sprt_list, gconf}
	jfa gdgspfix_reset {sprt_data, sprt_list, 0, 0x2006}
	jfa renderbars {rasps, rbars}
	jfa renderrows {rowps}
	jfa gdgspfix_addsprite {sprt_data, sprt_list, 0x019A, 0x8000, 230, 2, 40, 0}
	jfa rendertext {colps, txt0}
	jfa gdgsprit_frame {sprt_data, sprt_list, 0, 0}

	; Load the data into the Video RAM: characters and the RRPGE logo

	jfa rledec {  0,   9216, 0, 0x3000, 0x8024, 0x0000, PAGE_ROPD, 0x1A8, 0x3000}
	jfa rledec {0x3, 0xE800, 0, 0x3000, 0x8000, 0x0000, PAGE_ROPD, 0xA90, 0x1230}

	; Using noise data, fill up VRAM page 2 with tiles

	mov xm3,   PTR4I
	mov x3,    0x1B00	; Noise waveforms (2 x 256 bytes)
	shl c:x3,  2
	mov xh3,   c
	mov a,     0
tilp0:	jfa tilecopy {[x3], 0x804, a, 256}
	add a,     4
	mov b,     a
	and b,     0xFF
	xne b,     0
	add a,     0x0F00	; Row complete, next row
	xeq a,     0		; First half done
	jmr tilp0
	jfa copy {0x804, 0, 0x805, 0, 1, 0}

	; Set audio to 16KHz so to produce a wrapping 256 tick 62.5Hz clock
	; easily. A divider of 3 will do this. Note that this style of timing
	; is mostly fine to work around differences in display refresh rate
	; (which may range from 50Hz to 70Hz), but will produce slight jitter
	; in all. To circumvent it, a higher resolution time base would be
	; necessary, but in this example the granularity of the sine wave
	; source limits this.

	mov a,     3
	mov [0x1F0B], a

	; Wait for the audio sample counter based 62.5Hz tick to reach zero

await:	mov a,     [0x1F0C]
	shr a,     8
	xeq a,     0
	jmr await

	; Main loop, timed by audio

lmain:	mov a,     [0x1F0C]
	shr a,     8
	jfa sinewave {colps, 30, a, 300,    70, 14}
	jfa sinewave {rowps, 25, a,   0, 0x100,  5}
	jfa sinewave {rasps,  8, a, 200, 0x100,  5}
	jfa gdgspfix_reset {sprt_data, sprt_list, 0, 0x2006}
	jfa renderbars {rasps, rbars}
	jfa renderrows {rowps}
	jfa gdgspfix_addsprite {sprt_data, sprt_list, 0x019A, 0x8000, 230, 2, 40, 0}
	jfa rendertext {colps, txt0}
	jfa gdgsprit_frame {sprt_data, sprt_list, 0, 0}

	jmr lmain




;
; Simple, slow tile copy
;
; Copies the given tile index (only 0-5 gives a tile) to the passed location
; of the given pitch (width in cells). Uses the copy routine, so the target
; may be formed accordingly, but note that the offset is incremented for lines
; without affecting the page.
;
; param0: Tile index to copy
; param1: Target page
; param2: Target offset
; param3: Pitch (target width) in 16bit units
;
tilecopy:

.stl	equ	0		; Source tile index
.tpg	equ	1		; Target page
.tof	equ	2		; Target offset
.tpt	equ	3		; Target pitch

	mov sp,    7

	; Save CPU regs

	mov [bp +  4], a
	mov [bp +  5], b
	mov [bp +  6], c

	; Check source tile index, convert to offset or exit

	mov a,     [bp + .stl]
	xug 6,     a
	jmr .exit
	shl a,     6		; One tile is 64 words
	add a,     0xA2C	; Start offset within ROPD

	; Prepare copy loop

	mov b,     [bp + .tpt]
	mov c,     16

	; Copy the tile to the target area

.lp:	jfa copy {0, a, [bp + .tpg], [bp + .tof], 0, 4}
	add [bp + .tof], b
	add a,     4
	sub c,     1
	xeq c,     0
	jmr .lp

.exit:	; Restore CPU regs & exit

	mov a,     [bp +  4]
	mov b,     [bp +  5]
	mov c,     [bp +  6]
	rfn



;
; Fills in the position data with sine, to wave stuff
;
; param0: Offset of 30 element buffer to fill in with sine
; param1: Buffer size
; param2: Sine start offset (low 8 bits used)
; param3: Shift for the sine (add)
; param4: Multiplier for the sine (max. 0x100)
; param5: Sine increment
;
sinewave:

.sof	equ	0		; Sine buffer start offset
.siz	equ	1		; Sine buffer size
.sst	equ	2		; Sine start offset
.shf	equ	3		; Shift (add value)
.mul	equ	4		; Multiplier
.inc	equ	5		; Sine increment

	mov sp,    13

	; Save CPU regs

	mov [bp +  6], a
	mov [bp +  7], b
	mov [bp +  8], c
	mov [bp +  9], x2
	mov [bp + 10], x3
	mov [bp + 11], xm
	mov [bp + 12], xh

	; Calculate sine start pointer

	mov xm2,   PTR8
	mov xh2,   0
	mov x2,    [bp + .sst]
	and x2,    0xFF
	add x2,    0x1B00

	; Prepare target and loop count

	mov xm3,   PTR16I
	mov x3,    [bp + .sof]
	mov b,     [bp + .siz]

.lp:	; Load sine, from the small sine table in the ROPD, and center it
	; (2's complement). Then increment sine offset

	mov a,     [x2]
	sub a,     0x80
	add x2,    [bp + .inc]
	xbc x2,    10		; As long as this bit is clear, no wrap
	sub x2,    0x100	; Apply wraparound if needed

	; Apply multiplier, and calculate target value

	mul a,     [bp + .mul]
	asr a,     8
	add a,     [bp + .shf]

	; Save target value, and end loop

	mov [x3],  a
	sub b,     1
	xeq b,     0
	jmr .lp

	; Restore CPU regs & exit

	mov a,     [bp +  6]
	mov b,     [bp +  7]
	mov c,     [bp +  8]
	mov x2,    [bp +  9]
	mov x3,    [bp + 10]
	mov xm,    [bp + 11]
	mov xh,    [bp + 12]
	rfn



;
; Renders the rasterbars
;
; param0: Offset of rasterbar positions
; param1: Rasterbar patterns
;
renderbars:

.rps	equ	0		; Rasterbar positions
.rpt	equ	1		; Rasterbar patterns

	mov sp,    7

	; Save CPU regs

	mov [bp +  2], a
	mov [bp +  3], c
	mov [bp +  4], x2
	mov [bp +  5], x3
	mov [bp +  6], xm

	; 8 rasterbars

	mov xm3,   PTR16I
	mov xm2,   PTR16I
	mov x3,    [bp + .rps]
	mov x2,    [bp + .rpt]
	mov c,     8
.lp:	mov a,     [x2]
	jfa gdgsprit_addbg {sprt_list, a, a, [x3]}
	sub c,     1
	xeq c,     0
	jmr .lp

	; Restore CPU regs & exit

	mov a,     [bp +  2]
	mov c,     [bp +  3]
	mov x2,    [bp +  4]
	mov x3,    [bp +  5]
	mov xm,    [bp +  6]
	rfn



;
; Renders the waving rows
;
; param0: Offset of row positions
;
renderrows:

.rps	equ	0		; Row positions

	mov sp,    7

	; Save CPU regs

	mov [bp +  1], a
	mov [bp +  2], b
	mov [bp +  3], c
	mov [bp +  4], d
	mov [bp +  5], x3
	mov [bp +  6], xm

	; 25 rows of tiles, shift source for scrolling background, so no X,
	; but produce a wrapping position

	mov xm3,   PTR16I
	mov x3,    [bp + .rps]
	mov c,     25
	mov a,     0x4000
	mov d,     0
.lp:	mov b,     [x3]
	and b,     0x03FF	; Low 10 bits are position
	or  b,     0x8000
	jfa gdgspfix_add {sprt_data, sprt_list, a, b, 16, 1, d}
	add a,     16
	add d,     16
	sub c,     1
	xeq c,     0
	jmr .lp

	; Restore CPU regs & exit

	mov a,     [bp +  1]
	mov b,     [bp +  2]
	mov c,     [bp +  3]
	mov d,     [bp +  4]
	mov x3,    [bp +  5]
	mov xm,    [bp +  6]
	rfn



;
; Renders the text by the column positions
;
; param0: Offset of column Y start positions
; param1: Offset of text (2 rows of 30 chars each)
;
rendertext:

.cps	equ	0		; Column positions
.tof	equ	1		; Text start offset

	mov sp,    12

	; Save CPU regs

	mov [bp +  2], a
	mov [bp +  3], b
	mov [bp +  4], c
	mov [bp +  5], d
	mov [bp +  6], x0
	mov [bp +  7], x1
	mov [bp +  8], x2
	mov [bp +  9], x3
	mov [bp + 10], xm
	mov [bp + 11], xh

	; There are 2 rows, 30 characters each text, add those to the display
	; list as needed.

	mov xm3,   PTR16I
	mov xm2,   PTR8I
	mov x2,    [bp + .tof]
	shl c:x2,  1
	mov xh2,   c
	mov d,     2
	mov b,     0
.l0:	mov x3,    [bp + .cps]
	mov c,     30
	mov x1,    22		; X position
.l1:	jfa getcharcomm {[x2]}	; Load character's render command
	mov x0,    [x3]		; Load column position (Y position)
	xne a,     0		; Nonzero: need to create sprite for it
	jmr .nsp
	add x0,    b
	jfa gdgsprit_addsprite {sprt_data, sprt_list, a, 0x8000, 16, 0, x0, x1}
.nsp:	add x1,    20		; X position
	sub c,     1
	xeq c,     0
	jmr .l1
	add b,     40		; For next text row (Y adjust)
	sub d,     1
	xeq d,     0
	jmr .l0

	; Restore CPU regs & exit

	mov a,     [bp +  2]
	mov b,     [bp +  3]
	mov c,     [bp +  4]
	mov d,     [bp +  5]
	mov x0,    [bp +  6]
	mov x1,    [bp +  7]
	mov x2,    [bp +  8]
	mov x3,    [bp +  9]
	mov xm,    [bp + 10]
	mov xh,    [bp + 11]
	rfn



;
; Returns high part of render command to produce a character. Returns 0 if the
; character should not be rendered (should not take a sprite).
;
; param0: Character to produce: ' '; 'A' - 'Z'; '0' - '9'
; Ret. A: High part of render command for the character
;
getcharcomm:

.chr	equ	0		; Character to produce

	mov a,     [bp + .chr]
	xug '0',   a
	jmr .l0
.spc:	mov a,     0
	rfn
.l0:	xug a,     '9'
	jmr .num
	xug 'A',   a
	jmr .l1
	jmr .spc
.l1:	xug a,     'Z'
	jmr .alf
	jmr .spc
.num:	sub a,     '0'
	shl a,     4
	add a,     0x11A0
	rfn
.alf:	sub a,     'A'
	shl a,     4
	add a,     0x1000
	rfn



;
; Additional code modules
;

include "gdgsprit.asm"
include "gdgspfix.asm"
include "copy.asm"
include "rledec.asm"
