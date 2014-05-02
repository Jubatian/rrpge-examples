;
; Wave effect on a 80 cell (640 pixel in 16 color mode) wide display list.
;
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;


include "../rrpge.asm"

section code

;
; Applies wave effect on a display list
;
; The display list has to be on an area accessible by the CPU (banked in).
; Also uses the small sine table within the ROPD (0xD80 - 0xDFF). Assumes a
; Video RAM partition size of 32K 32bit cells.
;
; The mask or colorkey of the display list is left intact.
;
; The wave may be cycled, emphasised, and reduced.
;
; param0: Pixel data start pointer, whole, also selects partition.
; param1: Pixel data start pointer, fraction.
; param2: Sine start offset (low 8 bits used).
; param3: Sine strength (0 - 0x100).
; param4: Offset of display list to build.
;

effwave:

.pph	equ	0		; Pixel data start, high
.ppl	equ	1		; Pixel data start, low
.sst	equ	2		; Sine start
.sml	equ	3		; Sine strength
.dpl	equ	4		; Offset of display list
.svl	equ	5		; Subtract value for sine, low
.svh	equ	6		; Subtract value for sine, high
.par	equ	7		; Partition (bit 15)

	mov sp,    32		; Reserve some space on the stack

	; Save CPU registers & current bank selections

	mov [bp + 16], xm
	mov [bp + 17], x3
	mov xm3,   PTR16I
	mov x3,    18
	mov [bp + x3], xh
	mov [bp + x3], x2
	mov [bp + x3], x1
	mov [bp + x3], x0
	mov [bp + x3], a
	mov [bp + x3], b
	mov [bp + x3], c
	mov [bp + x3], d

	; Sanitize values, and shift multiplier

	mov a,     0xFF
	and [bp + .sst], a
	mov a,     [bp + .sml]
	xug 0x100, a
	mov a,     0x100
	shl a,     5
	mov [bp + .sml], a

	; Prepare sine pointer

	mov xm2,   PTR8I
	mov xh2,   0
	mov x2,    [bp + .sst]
	add x2,    0x1B00

	; Prepare display list pointer

	mov x3,    [bp + .dpl]	; x3 is already 16 bit incrementing

	; Prepare sine subtract value

	mov a,     0x80
	mul c:a,   [bp + .sml]
	mov [bp + .svl], a
	mov [bp + .svh], c

	; Prepare partition

	mov a,     [bp + .pph]
	and a,     0x8000
	mov [bp + .par], a

	; Pre-subtract sine subtract from pointer

	mov x0,    [bp + .svl]
	mov x1,    [bp + .svh]
	sub c:[bp + .ppl], x0
	sbc [bp + .pph], x1

	; Produce display list

	mov d,     400
.l0:	mov x1,    [bp + .pph]	; Load pointer
	mov x0,    [bp + .ppl]
	mov b,     [x2]		; Load sine value
	xne x2,    0x1C00	; Wrap sine
	mov x2,    0x1B00
	mul c:b,   [bp + .sml]
	mov a,     c
	add c:x0,  b
	adc x1,    a
	and x0,    0xFE00
	btc x1,    15
	or  x1,    [bp + .par]
	mov [x3],  x1		; High of pointer into display list
	mov a,     [x3]
	sub x3,    1
	and a,     0x00FF	; Preserve colorkey / mask
	bts a,     8		; Absolute pointer
	or  a,     x0		; Low of pointer into display list
	mov [x3],  a
	mov a,     80		; To next line
	add [bp + .pph], a
	sub d,     1
	xeq d,     0
	jmr .l0

	; Restore CPU registers

	mov xm3,   PTR16D
	mov x3,    26
	mov d,     [bp + x3]
	mov c,     [bp + x3]
	mov b,     [bp + x3]
	mov a,     [bp + x3]
	mov x0,    [bp + x3]
	mov x1,    [bp + x3]
	mov x2,    [bp + x3]
	mov xh,    [bp + x3]
	mov x3,    [bp + x3]
	mov xm,    [bp + 16]

	rfn
