;
; Rotozoom effect using an 1024 x 512 full Peripheral RAM bank (64K cells)
; source.
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;


include "../rrpge.asm"

section code

;
; Applies a rotozoom effect on a source copying it to a destination
;
; To perform the transform, an X and Y step has to be constructed. The X step
; is to be supplied for the accelerator as source increment, while the Y step
; is supplied as source post-add.
;
; X step: cos(a) - sin(a)
; Y step: sin(a) + cos(a)
;
; Uses the large sine table in the CPU RAM (0xFE00 - 0xFFFF), so rotation is 9
; bits.
;
; Only Pointer X and Pointer Y registers are set up (increments, post-adds,
; start offsets) according to the rotation, the rest of the accelerator
; registers are not altered (except for 0x801F, the start trigger, but the
; value written in it is irrelevant for the Scaled Blitter).
;
; The Blit control flags (0x8015) should be set up for Scaled blitter (bit 6
; set, bit 5 clear), and the Partition settings for an 1024 x 512 source
; (0xF6 for the high 8 bits).
;
; param0: X effect center
; param1: Y effect center
; param2: Rotation (9 bits)
; param3: Zoom (0x100: 1:1, no zooming)
;
; Registers C and X3 are not preserved.
;
effrzoom:

.xc	equ	0		; X effect center
.yc	equ	1		; Y effect center
.rt	equ	2		; Rotation
.zm	equ	3		; Zoom
.xh	equ	4		; X effect center high
.yh	equ	5		; Y effect center high
.t0h	equ	6		; sin(rt)
.t0l	equ	7
.t1h	equ	8		; -sin(rt)
.t1l	equ	9
.t2h	equ	10		; cos(rt)
.t2l	equ	11
.t3h	equ	12		; 1-cos(rt)
.t3l	equ	13

	mov sp,    21		; Reserve some space on the stack

	; Save CPU registers

	mov [$14], xm
	mov xm,    0x6466	; x3: PTR16I, x2: PTR16, rest: don't care
	mov x3,    15
	mov [$x3], x2
	mov [$x3], x1
	mov [$x3], x0
	mov [$x3], a
	mov [$x3], b
	mov [$x3], d

	; Pre-calculate trigonometric functions

	mov x3,    [$.rt]
	mov b,     x3
	and x3,    0x1FF
	add x3,    0xFE00
	mov a,     [x3]		; sin(rt)
	mov x3,    b
	add x3,    0x80
	and x3,    0x1FF
	add x3,    0xFE00
	mov b,     [x3]		; cos(rt)
	mov d,     b		; Expand cos(rt) (-0x4000 - 0x4000)
	shl c:d,   2
	xbc c,     1		; Was negative? If so, correct it
	or  c,     0xFFFC
	mov [$.t2h], c
	mov [$.t2l], d		; cos(rt)
	mov x0,    0
	mov x1,    1
	sub c:x0,  [$.t2l]
	sbc x1,    [$.t2h]
	mov [$.t3h], x1
	mov [$.t3l], x0		; 1-cos(rt)
	mov d,     a		; Expand sin(rt) (-0x4000 - 0x4000)
	shl c:d,   2
	xbc c,     1		; Was negative? If so, correct it
	or  c,     0xFFFC
	mov [$.t0h], c
	mov [$.t0l], d		; sin(rt)
	mov x0,    0
	mov x1,    0
	sub c:x0,  [$.t0l]
	sbc x1,    [$.t0h]
	mov [$.t1h], x1
	mov [$.t1l], x0		; -sin(rt)

	; Calculate X and Y steps, produce accelerator increment values, and
	; line step (post-add) values from these.

	mov x1,    [$.t2h]
	mov x0,    [$.t2l]	; cos(rt)
	mul c:x0,  [$.zm]
	mac x1,    [$.zm]	; Zoom applied, x1:x0: cos(rt) * zoom (.8 fixed)
	mov x3,    x1
	mov x2,    x0
	asr c:x3,  11		; 8 + 3; 8 pixels per cell
	src x2,    11
	mov c,     0x800E	; X increment on accelerator
	mov [P_GFIFO_ADDR], c
	mov [P_GFIFO_DATA], x3	; X increment whole
	mov [P_GFIFO_DATA], x2	; X increment fraction
	asr c:x1,  1		; 8 - 1; Width of data: 128 cells
	src x0,    1
	mov c,     0x8008	; Y post-add on accelerator
	mov [P_GFIFO_ADDR], c
	mov [P_GFIFO_DATA], x1	; Y post-add whole
	mov [P_GFIFO_DATA], x0	; Y post-add fraction
	mov x1,    [$.t0h]
	mov x0,    [$.t0l]	; sin(rt)
	mul c:x0,  [$.zm]
	mac x1,    [$.zm]	; Zoom applied, x1:x0: sin(rt) * zoom (.8 fixed)
	mov x3,    x1
	mov x2,    x0
	asr c:x3,  11		; 8 + 3; 8 pixels per cell
	src x2,    11
	mov [P_GFIFO_DATA], x3	; X post-add whole
	mov [P_GFIFO_DATA], x2	; X post-add fraction
	mov x3,    0
	mov x2,    0
	sub c:x2,  x0		; Negate
	sbc x3,    x1
	asr c:x3,  1		; 8 - 1; Width of data: 128 cells
	src x2,    1
	mov [P_GFIFO_DATA], x3	; Y increment whole
	mov [P_GFIFO_DATA], x2	; Y increment fraction

	; Calculate source start offset. x1:x0 will hold X and b:a will hold Y.

	mov c,     0
	xbc [$.xc], 15
	mov c,     0xFFFF
	mov [$.xh], c
	mov c,     0
	xbc [$.xc], 15
	mov c,     0xFFFF
	mov [$.yh], c
	mov x1,    [$.t3h]
	mov x0,    [$.t3l]	; 1-cos(rt)
	mov d,     x0
	mul d,     [$.xh]
	mul c:x0,  [$.xc]
	mac x1,    [$.xc]
	add x1,    d		; xc * (1-cos(rt))
	mov x3,    [$.t1h]
	mov x2,    [$.t1l]	; -sin(rt)
	mov d,     x2
	mul d,     [$.yh]
	mul c:x2,  [$.yc]
	mac x3,    [$.yc]
	add x3,    d		; yc * (-sin(rt))
	add c:x0,  x2
	adc x1,    x3		; x1:x0 = (xc * (1-cos(rt)) - (yc * sin(rt))
	mov b,     [$.t3h]
	mov a,     [$.t3l]	; 1-cos(rt)
	mov d,     a
	mul d,     [$.yh]
	mul c:a,   [$.yc]
	mac b,     [$.yc]
	add b,     d		; yc * (1-cos(rt))
	mov x3,    [$.t0h]
	mov x2,    [$.t0l]	; sin(rt)
	mov d,     x2
	mul d,     [$.xh]
	mul c:x2,  [$.xc]
	mac x3,    [$.xc]
	add x3,    d		; xc * (sin(rt))
	add c:a,   x2
	adc b,     x3		; b:a = (yc * (1-cos(rt)) + (xc * sin(rt))
	mov d,     x1
	asr d,     15
	mul c:x0,  [$.zm]
	mac c:x1,  [$.zm]
	mac d,     [$.zm]
	asr c:d,   11
	src c:x1,  11
	src x0,    11		; Zoom applied on X; 8 + 3: 8 pixels per cell on X
	mov d,     b
	asr d,     15
	mul c:a,   [$.zm]
	mac c:b,   [$.zm]
	mac d,     [$.zm]
	asr c:d,   1
	src c:b,   1
	src a,     1		; Zoom applied on Y; 8 - 1; 128 cells on Y

	; Zoom compensation, center the image

	mov d,     [$.zm]
	sub d,     0x100
	mov x2,    [$.xc]
	mov x3,    [$.xh]
	mul c:x2,  d
	mac x3,    d
	shl c:x2,  5
	slc x3,    5
	sub c:x0,  x2
	sbc x1,    x3
	mov x2,    [$.yc]
	mov x3,    [$.yh]
	mul c:x2,  d
	mac x3,    d
	shl c:x2,  15
	slc x3,    15
	sub c:a,   x2
	sbc b,     x3

	; Submit source start to the accelerator

	mov x2,    P_GFIFO_DATA	; FIFO data receive offset. Will save some words below.
	mov c,     0x8010	; Pointer Y whole
	mov [P_GFIFO_ADDR], c
	mov [x2],  b		; Whole
	mov [x2],  a		; Fraction
	mov c,     0x801A	; Pointer X whole
	mov [P_GFIFO_ADDR], c
	mov [x2],  x1		; Whole
	mov [x2],  x0		; Fraction

	; Start operation

	mov c,     0x801F
	mov [P_GFIFO_ADDR], c
	mov [x2],  c		; FIFO starts, accelerator blits

	; Restore CPU registers & Exit

	mov x3,    15
	mov x2,    [$x3]
	mov x1,    [$x3]
	mov x0,    [$x3]
	mov a,     [$x3]
	mov b,     [$x3]
	mov d,     [$x3]
	mov xm,    [$14]

	rfn
