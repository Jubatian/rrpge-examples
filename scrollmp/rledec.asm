;
; Simple RLE decoder
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
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
; Registers C and X3 are not preserved. PRAM pointers 2 and 3 are not
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

	; Enter main decode loop

.mloop:

	; Read a source value

	xne x2,    0
	jms .se0		; 0: to source exhausted test
.sn0:	sub x2,    1
	mov c,     [x0]		; Read value

	; Decode it. 'x3' will hold the value, 'c' the count.

	mov x3,    c
	and x3,    0x3
	shr c,     2
	xne c,     0		; If the high part was zero, needs next
	jms .secv		; Load second value

.dece:	; Source decoded, in 'x3' is the value, and in 'c' the count. First
	; transform it.

	add x3,    .ex0
	mov x3,    [$x3]

	; Write it out as many times as requested

	mov d,     c		; Note: count is nonzero
	xug d,     a		; Fits in destination count low?
	jms .dsub		; There is enough destination (0 is never enough here)
	xeq b,     0		; Destination count high zero?
	jms .dsub		; Nonzero: Sure there is enough destination
	mov d,     a		; Limit to available destination
	xne d,     0
	jms .exit		; Destination ran out
.dsub:	sub c:a,   d		; Available destination shrinks
	sbc b,     0
.oloop:	mov [x1],  x3		; Write the value
	sub d,     1
	xeq d,     0
	jms .oloop

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

	rfn


.secv:	; Need a second source value

	xne x2,    0
	jms .se1		; 0: to source exhausted test
.sn1:	sub x2,    1
	mov c,     [x0]		; Read value

	; Decode the second value

	xug 7,     c		; c: 0-6:  powers of 2.
	jms .dece		; c: 7-15: count.
	add c,     4
	mov d,     1
	shl d,     c
	mov c,     d

	jms .dece

.se0:	; Source value 0 load: source exhaustion check

	mov d,     1
	sub [$.sch], d
	xbs [$.sch], 15		; Turned 2's complement negative: was zero
	jms .sn0
	; jms .exit (No problem just falling through, will exit)

.se1:	; Source value 1 load: source exhaustion check

	mov d,     1
	sub [$.sch], d
	xbs [$.sch], 15		; Turned 2's complement negative: was zero
	jms .sn1
	jms .exit
