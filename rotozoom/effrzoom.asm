;
; Rotozoom effect using 80 cell (640 pixel in 16 color mode) wide target, and
; an 1024 x 512 full Video RAM bank source.
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;


include "../rrpge.asm"

section code

;
; Applies a rotozoom effect on a source copying it to a destination
;
; To perform the transform, an X and Y step has to be constructed. The X step
; is to be supplied for the accelerator as source increment, while the Y step
; specifies the source increment relative to the previous line rendered.
;
; X step: cos(a) - sin(a)
; Y step: sin(a) + cos(a)
;
; Uses the large sine table from the ROPD (0xE00 - 0xFFF), so rotation is 9
; bits.
;
; It keeps reindexing related accelerator options intact, as well as
; colorkeying, so these should be set up in advance according to the needs.
; Source high should be set up to select the bank to use. Destination start
; should be set up to the upper left corner of the target area.
;
; param0: X effect center
; param1: Y effect center
; param2: Rotation (9 bits)
; param3: Zoom (0x100: 1:1, no zooming)
;
offrzoom:

.xc	equ	0		; X effect center
.yc	equ	1		; Y effect center
.rt	equ	2		; Rotation
.zm	equ	3		; Zoom
.xw	equ	4		; X step, whole
.xf	equ	5		; X step, fraction
.yw	equ	6		; Y step, whole
.yf	equ	7		; Y step, fraction
.t0h	equ	8		; sin(rt)
.t0l	equ	9
.t1h	equ	10		; -sin(rt)
.t1l	equ	11
.t2h	equ	12		; cos(rt)
.t2l	equ	13
.t3h	equ	14		; 1-cos(rt)
.t3l	equ	15
.xh	equ	12		; X effect center high (overlaps cos(rt))
.yh	equ	13		; Y effect center high (overlaps cos(rt))

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

	; Pre-calculate trigonometric functions

	mov x3,    [bp + .rt]
	mov b,     x3
	and x3,    0x1FF
	add x3,    0x0E00
	mov a,     [x3]		; sin(rt)
	mov x3,    b
	add x3,    0x80
	and x3,    0x1FF
	add x3,    0x0E00
	mov b,     [x3]		; cos(rt)
	mov d,     b		; Expand cos(rt) (-0x4000 - 0x4000)
	shl c:d,   2
	xbc c,     1		; Was negative? If so, correct it
	or  c,     0xFFFC
	mov [bp + .t2h], c
	mov [bp + .t2l], d	; cos(rt)
	mov x0,    0
	mov x1,    1
	sub c:x0,  [bp + .t2l]
	sbc x1,    [bp + .t2h]
	mov [bp + .t3h], x1
	mov [bp + .t3l], x0	; 1-cos(rt)
	mov d,     a		; Expand sin(rt) (-0x4000 - 0x4000)
	shl c:d,   2
	xbc c,     1		; Was negative? If so, correct it
	or  c,     0xFFFC
	mov [bp + .t0h], c
	mov [bp + .t0l], d	; sin(rt)
	mov x0,    0
	mov x1,    0
	sub c:x0,  [bp + .t0l]
	sbc x1,    [bp + .t0h]
	mov [bp + .t1h], x1
	mov [bp + .t1l], x0	; -sin(rt)

	; Calculate X and Y steps, produce accelerator increment values, and
	; line step values from these.

	mov x1,    [bp + .t2h]
	mov x0,    [bp + .t2l]	; cos(rt)
	mul c:x0,  [bp + .zm]
	mac x1,    [bp + .zm]	; Zoom applied, x1:x0: cos(rt) * zoom (.8 fixed)
	mov x3,    x1
	mov x2,    x0
	asr c:x3,  11		; 8 + 3; 8 pixels per cell
	src x2,    11
	mov [0x2EEC], x3	; X increment on accelerator
	mov [0x2EED], x2
	asr c:x1,  1		; 8 - 1; Width of data: 128 cells
	src x0,    1
	mov [bp + .yw], x1	; Y step across lines
	mov [bp + .yf], x0
	mov x1,    [bp + .t0h]
	mov x0,    [bp + .t0l]	; sin(rt)
	mul c:x0,  [bp + .zm]
	mac x1,    [bp + .zm]	; Zoom applied, x1:x0: sin(rt) * zoom (.8 fixed)
	mov x3,    x1
	mov x2,    x0
	asr c:x3,  11		; 8 + 3; 8 pixels per cell
	src x2,    11
	mov [bp + .xw], x3	; X step across lines
	mov [bp + .xf], x2
	mov x3,    0
	mov x2,    0
	sub c:x2,  x0		; Negate
	sbc x3,    x1
	asr c:x3,  1		; 8 - 1; Width of data: 128 cells
	src x2,    1
	mov [0x2EEE], x3	; Y increment on accelerator
	mov [0x2EEF], x2
	asr c:x1,  3		; 8 pixels per cell

	; Calculate source start offset. x1:x0 will hold X and b:a will hold Y.

	mov c,     0
	xbc [bp + .xc], 15
	mov c,     0xFFFF
	mov [bp + .xh], c
	mov c,     0
	xbc [bp + .xc], 15
	mov c,     0xFFFF
	mov [bp + .yh], c
	mov x1,    [bp + .t3h]
	mov x0,    [bp + .t3l]	; 1-cos(rt)
	mov d,     x0
	mul d,     [bp + .xh]
	mul c:x0,  [bp + .xc]
	mac x1,    [bp + .xc]
	add x1,    d		; xc * (1-cos(rt))
	mov x3,    [bp + .t1h]
	mov x2,    [bp + .t1l]	; -sin(rt)
	mov d,     x2
	mul d,     [bp + .yh]
	mul c:x2,  [bp + .yc]
	mac x3,    [bp + .yc]
	add x3,    d		; yc * (-sin(rt))
	add c:x0,  x2
	adc x1,    x3		; x1:x0 = (xc * (1-cos(rt)) - (yc * sin(rt))
	mov b,     [bp + .t3h]
	mov a,     [bp + .t3l]	; 1-cos(rt)
	mov d,     a
	mul d,     [bp + .yh]
	mul c:a,   [bp + .yc]
	mac b,     [bp + .yc]
	add b,     d		; yc * (1-cos(rt))
	mov x3,    [bp + .t0h]
	mov x2,    [bp + .t0l]	; sin(rt)
	mov d,     x2
	mul d,     [bp + .xh]
	mul c:x2,  [bp + .xc]
	mac x3,    [bp + .xc]
	add x3,    d		; xc * (sin(rt))
	add c:a,   x2
	adc b,     x3		; b:a = (yc * (1-cos(rt)) + (xc * sin(rt))
	mov d,     x1
	asr d,     15
	mul c:x0,  [bp + .zm]
	mac c:x1,  [bp + .zm]
	mac d,     [bp + .zm]
	asr c:d,   11
	src c:x1,  11
	src x0,    11		; Zoom applied on X; 8 + 3: 8 pixels per cell on X
	mov d,     b
	asr d,     15
	mul c:a,   [bp + .zm]
	mac c:b,   [bp + .zm]
	mac d,     [bp + .zm]
	asr c:d,   1
	src c:b,   1
	src a,     1		; Zoom applied on Y; 8 - 1; 128 cells on Y

	; Zoom compensation, center the image

	mov d,     [bp + .zm]
	sub d,     0x100
	mov x2,    [bp + .xc]
	mov x3,    [bp + .xh]
	mul c:x2,  d
	mac x3,    d
	shl c:x2,  5
	slc x3,    5
	sub c:x0,  x2
	sbc x1,    x3
	mov x2,    [bp + .yc]
	mov x3,    [bp + .yh]
	mul c:x2,  d
	mac x3,    d
	shl c:x2,  15
	slc x3,    15
	sub c:a,   x2
	sbc b,     x3

	; Set up accelerator mode and pixel count

	mov x3,    0x2EF8	; Accelerator mode and colorkey
	mov d,     [x3]
	sub x3,    1
	and d,     0xF2FF
	bts d,     11		; Scaled blit
	mov [x3],  d
	mov d,     640
	mov [x3],  d

	; Set up source split mask and partitioning

	mov d,     0x007F	; 1024x512 source
	mov [0x2EFC], d
	mov d,     0x8000	; Source partition size: 64K * 32bits
	or  [0x2EF7], d
	mov d,     0x0007	; Destination partition size: 64K * 32bits
	mov [0x2EE2], d

	; Prepare x2 for writing accelerator start

	mov xm2,   PTR16
	mov x2,    0x2EFF

	; Everything prepared, output 400 accelerator lines

	mov d,     400
.loop:	mov x3,    0x2EE8	; Source X & Y pointers
	mov [x3],  x1		; This will block until completing prev. line
	mov [x3],  x0
	mov [x3],  b
	mov [x3],  a
	mov [x2],  d		; Just start it (written value is irrevelant)
	add c:x0,  [bp + .xf]
	adc x1,    [bp + .xw]
	add c:a,   [bp + .yf]
	adc b,     [bp + .yw]
	sub d,     1
	xeq d,     0
	jmr .loop

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
