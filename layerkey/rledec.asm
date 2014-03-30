;
; Simple RLE decoder
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv1 (version 1 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv1 in the project root.
;
;
; Decodes 2bit RLE source into a 4bit target (suitable for the 16 color
; display).
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
; exhausted early, the remaining destination is not altered. It has no return
; value, all registers are preserved.
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
; param4: Destination start page
; param5: Destination start offset in page (4bit units)
; param6: Source start page
; param7: Source start offset in page (4bit units)
; param8: 2bit -> 4bit expansion table
;

rledec:

.dch	equ	0		; Destination count, high
.dcl	equ	1		; Destination count, low
.sch	equ	2		; Source count, high
.scl	equ	3		; Source count, low
.dpg	equ	4		; Destination page
.dof	equ	5		; Destination offset
.spg	equ	6		; Source page
.sof	equ	7		; Source offset
.ex0	equ	8		; Expansion table, expansion for 0
.ex1	equ	9		; Expansion for 1
.ex2	equ	10		; Expansion for 2
.ex3	equ	11		; Expansion for 3
.exe	equ	12		; End of expansions

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
	mov a,     [ROPD_WBK_8]
	mov [bp + x3], a	; 26
	mov a,     [ROPD_RBK_8]
	mov [bp + x3], a	; 27; Will be used for writing
	mov a,     [ROPD_WBK_12]
	mov [bp + x3], a	; 28
	mov a,     [ROPD_RBK_12]
	mov [bp + x3], a	; 29; Will be used for reading

	; Sanitize input offsets to be within page

	mov a,     0x3FFF
	and [bp + .sof], a
	and [bp + .dof], a

	; Load a "neutral" page in the source write bank, so it will work
	; proper even if a Video RAM page was there

	jsv {kc_mem_bankwr,   12, 0x4000}

	; Load initial source and destination pages

	jsv {kc_mem_bankrd,   12, [bp + .spg]}
	jsv {kc_mem_banksame,  8, [bp + .dpg]}

	; Decode the expansion table (x3 is incrementing 16 bits)

	mov a,     [bp + .ex0]
	mov x3,    .ex0
.l0:	mov b,     a
	and b,     0xF
	mov [bp + x3], b
	shr a,     4
	xeq x3,    .exe
	jmr .l0

	; Set up source and destination pointers. Both are 4bit pointers.
	; 4bit pointers partition the address space to 4 areas accessible
	; without an xh modification, the most suitable pages to work with are
	; so page 0, 4, 8 and 12 (the pointer register being zero points at
	; the begin of the area selected by xh).
	; x0 is the source, x1 is the destination.

	mov xm0,   PTR4I
	mov xm1,   PTR4I
	mov xh0,   0x3		; Pages 12 - 15
	mov xh1,   0x2		; Pages  8 - 11
	mov x0,    [bp + .sof]
	mov x1,    [bp + .dof]

	; Prepare for main decode loop

	mov a,     [bp + .scl]	; 'a' will hold source count low
	mov b,     [bp + .sch]	; 'b' will hold source count high
	mov x2,    0		; 'x2' will be zero to use where immediate is not ok

	; Enter main decode loop

.mloop:

	; Read a source value

	mov d,     1		; To see if source exhausted
	jfa .read
	xne d,     0
	jmr .exit

	; Decode it. 'x3' will hold the value, 'c' the count.

	mov x3,    c
	and x3,    0x3
	shr c,     2
	xeq c,     0		; If the high part was zero, needs next
	jmr .dece		; Otherwise done

	; Need a second source value

	jfa .read
	xne d,     0
	jmr .exit

	; Decode the second value

	xug 7,     c		; c: 0-6:  powers of 2.
	jmr .dece		; c: 7-15: count.
	add c,     4
	mov d,     1
	shl d,     c
	mov c,     d

.dece:	; Source decoded, in 'x3' is the value, and in 'c' the count. First
	; transform it.

	add x3,    .ex0
	mov x3,    [bp + x3]

	; Write it out as many times as requested

	mov d,     c		; Note: count is nonzero
	xeq [bp + .dch], x2	; (x2 is zero)
	jmr .dsub		; Sure there is enough destination
	xug d, [bp + .dcl]
	jmr .dsub		; There is enough destination
	mov d,     [bp + .dcl]	; Limit to available destination
	xne d,     0
	jmr .exit		; Destination ran out
.dsub:	sub c:[bp + .dcl], d	; Available destination shrinks
	sbc [bp + .dch], x2	; (x2 is zero)
	add d,     x1
	and d,     0x3FFF	; Calculate end point (d <= 1024, so OK)
.oloop:	mov [x1],  x3		; Write the value, and update bank if necessary
	xug x1,    0x3FFF	; Incremented past page boundary
	jmr .writ0
	mov x1,    [ROPD_WBK_8]
	add x1,    1
	jsv {kc_mem_banksame, 8, x1}
	mov x1,    0		; Start from begin
.writ0:	xeq x1,    d
	jmr .oloop

	; A run was written, go on with next
	jmr .mloop

.exit:

	; Restore CPU registers & bank selections

	mov xm3,   PTR16D
	mov x3,    30
	jsv {kc_mem_bank, 12, [bp + x3], [bp + x3]}
	jsv {kc_mem_bank,  8, [bp + x3], [bp + x3]}
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



;
; Internal function to read next element of the source. Updates bank if
; necessary.
;
; Inputs:
; b:a: Source remaining, high:low.
; x0:  Source pointer (4 bits incrementing).
;
; Outputs:
; b:a: New source remaining, high:low.
; c:   Value to output (0-15).
; d:   0 if source exhausted, unchanged otherwise.
; x0:  Updated.
;
.read:

	; Is there any source available?

	xeq a,     0
	jmr .reads
	xne b,     0
	jmr .readf

.reads:	; One less source available

	sub c:a,   1
	sbc b,     0

	; Read the value, and update bank if necessary

	mov c,     [x0]
	xug x0,    0x3FFF	; Incremented past page boundary
	rfn			; OK, no increment past, return
	mov x0,    [ROPD_RBK_12]
	add x0,    1
	jsv {kc_mem_bankrd, 12, x0}
	mov x0,    0		; Start from begin
	rfn

.readf:	; Bad return

	mov d,     0
	rfn
