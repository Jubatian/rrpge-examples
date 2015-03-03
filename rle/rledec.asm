;
; Simple RLE decoder
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2015, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;
;
; Decodes 2bit RLE source into a 4bit target (suitable for the 16 color
; display) within the Peripheral RAM.
;
; The RLE format used:
;
; 4 bits compose one data unit.
;
; The low 2 bits of this specify the value to decode into (0 - 3).
; The high 2 bits are either count or extra unit requirement:
; 0: Extra unit required
; 1: No repeat (single position occurrence).
; 2: 2 positions.
; 3: 3 positions.
;
; If an extra unit is required, the next 4bit unit is used to encode the
; repeat count as follows:
; 7 - 15: 7 - 15 positions.
; 0 - 6:  2 ^ (unit + 4) positions (so 16 - 1024).
;


include "../rrpge.asm"

section code

;
; Decodes RLE stream
;
; Decodes a source RLE stream filling up to a given amount of values from it,
; taking at most up to a given number of source values. If the source is
; exhausted early, the remaining destination is not altered.
;
; The 2bit -> 4bit expansion table is used to write the destination. It's
; layout is as follows:
; bit 12-15: Conversion for a source value of 3.
; bit  8-11: Conversion for a source value of 2.
; bit  4- 7: Conversion for a source value of 1.
; bit  0- 3: Conversion for a source value of 0.
;
; param0: Number of destination values to generate, high
; param1: Number of destination values to generate, low
; param2: Number of source values available, high
; param3: Number of source values available, low
; param4: Destination start high (bit offset)
; param5: Destination start low (bit offset)
; param6: Source start high (bit offset)
; param7: Source start low (bit offset)
; param8: 2bit -> 4bit expansion table
;
; Registers C and X3 are set zero. PRAM pointers 2 and 3 are not
; preserved.
;

rledec:

.tch	equ	0		; Destination count, high
.tcl	equ	1		; Destination count, low
.sch	equ	2		; Source count, high
.scl	equ	3		; Source count, low
.tgh	equ	4		; Destination (target), high
.tgl	equ	5		; Destination (target), low
.srh	equ	6		; Source, high
.srl	equ	7		; Source, low
.ex0	equ	8		; Expansion table, expansion for 0
.ex1	equ	9		; Expansion for 1
.ex2	equ	10		; Expansion for 2
.ex3	equ	11		; Expansion for 3
.exe	equ	12		; End of expansions

	mov sp,    19		; Reserve space on the stack

	; Save CPU registers & current bank selections

	mov [$12], xm
	mov xm,    0x6444	; 'x3': PTR16I, rest: PTR16
	mov x3,    13
	mov [$x3], x2
	mov [$x3], x1
	mov [$x3], x0
	mov [$x3], a
	mov [$x3], b
	mov [$x3], d

	; Decode the expansion table (x3 is incrementing 16 bits)

	mov a,     [$.ex0]
	mov x3,    .ex0
.l0:	mov [$x3], a		; Don't care for high bits, they won't show.
	shr a,     4
	xeq x3,    .exe
	jms .l0

	; Set up source and destination pointers. Both are 4bit pointers.

	jfa us_ptr_set4i {2, [$.tgh], [$.tgl]}
	mov x1,    x3		; Destination (target)
	jfa us_ptr_set4i {3, [$.srh], [$.srl]}
	mov x0,    x3		; Source

	; Prepare for main decode loop

	mov a,     [$.tcl]	; 'a' will hold destination count low
	mov b,     [$.tch]	; 'b' will hold destination count high
	mov x2,    [$.scl]	; 'x2' will hold source count low
	mov c,     1		; 'c' will hold 1

	; Enter main decode loop

.mloop:	; Read a source value

	jnz x2,    .sn0		; Source count low reached zero?
	sub [$.sch], c		; 'c' holds 1
	xbc [$.sch], 15		; Turned 2's complement negative: was zero
	jms .exit
.sn0:	sub x2,    1
	mov d,     [x0]		; Read value

	; Decode it. 'x3' will hold the value, 'd' the count.

	mov x3,    d
	and x3,    0x3
	shr d,     2
	jnz d,     .dece	; Unless high part was zero, done

	; Needs a second source value

	jnz x2,    .sn1		; Source count low reached zero?
	sub [$.sch], c		; 'c' is still 1
	xbc [$.sch], 15		; Turned 2's complement negative: was zero
	jms .exit
.sn1:	sub x2,    1
	mov d,     [x0]		; Read value

	; Decode the second value (count into 'd')

	xug 7,     d		; d: 0-6:  powers of 2.
	jms .dece		; d: 7-15: count.
	add d,     4
	shl c,     d		; 'c' is still 1
	mov d,     c

.dece:	; Source decoded, in 'x3' is the value, and in 'd' the count (which is
	; nonzero). First transform it.

	add x3,    .ex0
	mov x3,    [$x3]

	; Write it out as many times as requested

	jnz b,     .dsub	; Destination count high zero?
	xul d,     a		; Fits in destination count low?
	mov d,     a		; Limit to available destination
	xne d,     0
	jms .exit		; Destination ran out
.dsub:	sub c:a,   d		; Available destination shrinks
	sbc b,     0
.oloop:	mov [x1],  x3		; Write the value
	sub d,     1
	jnz d,     .oloop
	mov c,     1		; Restore 'c' to hold 1

	; A run was written, go on with next

	jms .mloop

.exit:	; Restore CPU registers & exit

	mov x3,    13
	mov x2,    [$x3]
	mov x1,    [$x3]
	mov x0,    [$x3]
	mov a,     [$x3]
	mov b,     [$x3]
	mov d,     [$x3]
	mov xm,    [$12]

	rfn c:x3,  0
