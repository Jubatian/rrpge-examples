;
; RRPGE User Library functions - Display List sprites
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;
;
; Simple sprite management system for the Graphics Display Generator. It is
; capable to automatically multiplex sprites. For the proper function the
; Display List Clear should be set up appropriately to clear the managed
; columns.
;
; Uses the following CPU RAM locations:
; 0xF800 - 0xF98F: Occupation data
; 0xFADF: Clear rows (no sprites) on the top. Normally 0.
; 0xFADE: Clear rows (no sprites) on the bottom. Normally 0.
; 0xFADD: Clear columns on the front of the row. Normally 0.
; 0xFADC: Clear columns on the end of the row. Normally 0.
; 0xFADB: Bit0: if clear, indicates the occupation data is dirty.
;
; Also adds a Page flip hook (to clear the occupation data).
;
; Occupation data format:
;
; Low 400 bytes are the bottom limits, High 400 bytes are the top limits (as
; first occupied locations, so the row is full when they equal).
;

include "../rrpge.asm"

section code



;
; Resets display list occupation data (Page flip hook)
;
; Initializes display list occupation data for rendering a new frame according
; to the bounds in the internal data.
;
us_dsprite_reset:
	jma us_dsprite_reset_i



;
; Sets sprite area bounds
;
; Param0: Top rows without sprites
; Param1: Bottom rows without sprites
; Param2: Clear columns on the front of the display list row
; Param3: Clear columns on the end of the display list row
;
us_dsprite_setbounds:
	jma us_dsprite_setbounds_i



;
; Adds a graphics component to sprite area.
;
; The display list's configuration is taken from us_dbuf_getlist. The source
; line positions are generated automatically for lines after the first using
; the requested source's configuaration in the GDG registers.
;
; Param0: Render command high word
; Param1: Render command low word
; Param2: Height in lines
; Param3: Bit 0 nonzero to add to top, zero for bottom
; Param4: Y position (signed 2's complement, can be off-screen)
;
; Registers C and X3 are not preserved. PRAM pointer 3 is used and not
; preserved. XM3 is assumed to be PTR16I.
;
us_dsprite_add:
	jma us_dsprite_add_i



;
; Adds a graphics component to sprite area at a given X:Y position.
;
; The display list's configuration is taken from us_dbuf_getlist. The source
; line positions are generated automatically for lines after the first using
; the requested source's configuaration in the GDG registers. X position is
; used for the render command's low 10 bits. It is compensated in 8 bit mode,
; so on-screen coordinates are 0 - 319 this case.
;
; Param0: Render command high word
; Param1: Render command low word
; Param2: Height in lines
; Param3: Bit 0 nonzero to add to top, zero for bottom
; Param4: X position (signed 2's complement, can be off-screen)
; Param5: Y position (signed 2's complement, can be off-screen)
;
; Registers C and X3 are not preserved. PRAM pointer 3 is used and not
; preserved. XM3 is assumed to be PTR16I.
;
us_dsprite_addxy:
	jma us_dsprite_addxy_i



;
; Adds render command list to sprite area.
;
; The display list's configuration is taken from us_dbuf_getlist.
;
; Param0: PRAM word offset of render command list, high
; Param1: PRAM word offset of render command list, low
; Param2: Height in lines
; Param3: Bit 0 nonzero to add to top, zero for bottom
; Param4: Y position (signed 2's complement, can be off-screen)
;
; Registers C and X3 are not preserved. PRAM pointers 2 and 3 are used and not
; preserved. XM3 is assumed to be PTR16I.
;
us_dsprite_addlist:
	jma us_dsprite_addlist_i



; 0xF800 - 0xF98F: Occupation data
us_dsprite_ola	equ	0xF800
us_dsprite_ola8	equ	0xF000	; us_dsprite_ola << 1
us_dsprite_ole	equ	0xF8C8
us_dsprite_ole8	equ	0xF190	; us_dsprite_ole << 1
us_dsprite_oha	equ	0xF8C8
us_dsprite_oha8	equ	0xF190	; us_dsprite_oha << 1
us_dsprite_ohe	equ	0xF990
us_dsprite_ohe8	equ	0xF320	; us_dsprite_ohe << 1
; 0xFADF: Clear rows on top
us_dsprite_rt	equ	0xFADF
; 0xFADE: Clear rows on bottom
us_dsprite_rb	equ	0xFADE
; 0xFADD: Clear graphics cols on the front
us_dsprite_cf	equ	0xFADD
; 0xFADC: Clear graphics cols on the end
us_dsprite_ce	equ	0xFADC
; 0xFADB: Dirty flag on bit 0: clear if dirty.
us_dsprite_df	equ	0xFADB



;
; Internal function to set up display list pointer.
;
; Param1: Y position
; Param0: Display List Definition
; Ret.X3: Display list row size in bits (used to advance rows)
;
; The display list pointer is set up to stationary 16 bits.
;
us_dsprite_setptr_i:

.psy	equ	0		; Y position
.dld	equ	1		; Display List Definition
.shf	equ	0		; Temp. storage for shift (reuses Y position)

	mov sp,    5

	; Save CPU regs

	mov [$2],  a
	mov [$3],  b
	mov [$4],  d

	; Load display list size & prepare masks

	mov a,     [$.dld]
	and a,     3		; Display list entry size
	not d,     0x0003	; Loads 0xFFFC
	shl d,     a
	and d,     0x07FC	; Mask for display list offset
	xbc [$.dld], 13		; Double scan?
	add a,     1		; 0 / 1 / 2 / 3 / 4
	add a,     7		; 0 => 4 * 32 bit entries etc.

	; Calculate bit offset within display list

	shl c:[$.psy], a	; Bit add value for start offset by Y position
	mov b,     c		; Y high in 'b'

	; Calculate absolute display list offset

	and d,     [$.dld]	; Apply mask on display list def. into the mask
	shl c:d,   14		; Bit offset of display list
	add b,     c
	add c:d,   [$.psy]
	add b,     c		; Start offset in b:d acquired

	; Prepare PRAM pointer fill. In 'c' prepares a zero for incr. high

	mov [$.shf], a		; Save shift for generating return
	mov c,     0
	mov a,     4		; 16 bit pointer, always increment

	; Fill PRAM pointer 3

	mov x3,    P3_AH
	mov [x3],  b		; P3_AH
	mov [x3],  d		; P3_AL
	mov [x3],  c		; P3_IH
	mov [x3],  c		; P3_IL
	mov [x3],  a		; P3_DS

	mov x3,    1
	shl x3,    [$.shf]	; Return value (display list size in bits)

	; Restore CPU regs & exit

	mov a,     [$2]
	mov b,     [$3]
	mov d,     [$4]
	rfn



;
; Internal function to reset an area of the occupation list
;
; Param0: Start row
; Param1: Count of rows
; Param2: Low bound (1 for first graphics column)
; Param3: High bound (first non-usable column)
;
us_dsprite_clear_i:

.sta	equ	0		; Start row
.cnt	equ	1		; Count of rows (must not be 0)
.bnl	equ	2		; Low bound
.bnh	equ	3		; High bound

	mov sp,    6

	; Save CPU regs

	xch a,     [$.bnl]	; Load low bound & save 'a'
	mov c,     [$.bnh]	; Load high bound
	xch x0,    [$.sta]	; Load start row & save 'x0'
	mov [$4],  xm
	mov [$5],  xh

	; Init pointers

	mov xm,    0x8888	; PTR8I for all
	mov xh,    0x1111	; 8 bit pointers, they are on the high end
	add x0,    us_dsprite_ola8
	mov x3,    x0
	add x3,    400		; High bounds offset

	; Init loop

	add [$.cnt], x0		; Termination point

	; Clear. Not much optimized, it could be faster with some unrolling or
	; word operations instead of byte, but for no much gain: the overall
	; bottleneck is rather the output of sprites.

.lp:	mov [x0],  a
	mov [x3],  c
	xeq x0,    [$.cnt]
	jms .lp

	; Restore CPU regs & exit

	mov a,     [$.bnl]
	mov x0,    [$.sta]
	mov xm,    [$4]
	mov xh,    [$5]
	rfn



;
; Implementation of us_dsprite_reset
;
us_dsprite_reset_i:

	; Check dirty, do nothing unless it is necessary to clear

	xbc [us_dsprite_df], 0
	rfn			; No need to clear, already OK
	bts [us_dsprite_df], 0

	; Save CPU regs

	mov sp,    3
	mov [$0],  a
	mov [$1],  b
	mov [$2],  d

	; Get total height

	mov d,     200
	xbs [P_GDG_DLDEF], 13	; Double scanned display?
	shl d,     1		; Make it 400 lines if not double scanned

	; Clear top part

	mov a,     [us_dsprite_rt]
	xug d,     a
	mov a,     d
	xeq a,     0
	jfa us_dsprite_clear_i {0, a, 0, 0}

	; Clear mid part using the column bounds

	mov b,     [us_dsprite_ce]
	mov c,     [P_GDG_DLDEF]
	mov x3,    4		; Smallest display list size is normally 4 entries
	xbc c,     13		; Double scan?
	mov x3,    8		; But 8 entries when double scanned
	and c,     3
	shl x3,    c		; Count of entries on a display list row
	xug x3,    b
	mov b,     x3
	sub x3,    b		; End bound in 'x3' (first non-available column)
	mov c,     [us_dsprite_rb]
	mov b,     d		; 'd': 200 / 400 total lines
	sub b,     a		; Previous (top excluded part) count
	xug b,     c		; Bottom excluded part count
	mov b,     c
	sub b,     c		; Count of rows in 'b'
	mov c,     [us_dsprite_cf]
	xne c,     0
	mov c,     1		; Background column can never be used
	xug x3,    c		; Can not be larger than the end bound
	mov c,     x3		; Front bound in 'c' (first available column)
	xeq b,     0
	jfa us_dsprite_clear_i {a, b, c, x3}

	; Clear bottom part

	add a,     b		; Start offset
	sub d,     a		; Count: all what is remaining ('d': 200 / 400 total lines)
	xeq d,     0
	jfa us_dsprite_clear_i {a, d, 0, 0}

;jfa us_dsprite_clear_i {0, 400, 9, 22}

	; Restore CPU regs & exit

	mov a,     [$0]
	mov b,     [$1]
	mov d,     [$2]
	rfn



;
; Implementation of us_dsprite_setbounds
;
us_dsprite_setbounds_i:

.trn	equ	0		; Top rows without sprites
.brn	equ	1		; Bottom rows without sprites
.fcn	equ	2		; Front columns without sprites
.ecn	equ	3		; End columns without sprites

	mov c,     [$.trn]
	mov [us_dsprite_rt], c
	mov c,     [$.brn]
	mov [us_dsprite_rb], c
	mov c,     [$.fcn]
	mov [us_dsprite_cf], c
	mov c,     [$.ecn]
	mov [us_dsprite_ce], c
	btc [us_dsprite_df], 0	; Mark dirty
	rfn



;
; Implementation of us_dsprite_add
;
us_dsprite_add_i:

.rch	equ	0		; Render command, high
.rcl	equ	1		; Render command, low
.hgt	equ	2		; Height
.btp	equ	3		; Bottom or Top add (bit 0 zero: bottom)
.psy	equ	4		; Y position (2's complement)
.mul	equ	5		; Width multiplier
.dld	equ	6		; Display list definition

	mov sp,    15

	; Save CPU regs

	mov [$7],  a
	mov [$8],  b
	mov [$9],  d
	mov [$10], x0
	mov [$11], x1
	mov [$12], x2
	mov [$13], xm
	mov [$14], xh

	; Load display list definition

	jfa us_dbuf_getlist
	mov [$.dld], x3

	; Calculate source width multiplier so to know how many to add to the
	; source line select to advance one line.

	mov x3,    [$.rch]
	shr x3,    12
	and x3,    7		; Source definition select
	add x3,    P_GDG_SA0
	mov d,     [x3]		; Load source definition
	and d,     0xF
	shl d,     1
	add d,     1		; Width multiplier: 1 to 31, odd
	mov [$.mul], d

.entr:	; Clip the graphics component if needed. If partial from the top, the
	; render command itself also alters so respecting the first visible
	; line.

	mov x3,    200
	xbs [$.dld], 13		; Double scanned if set
	shl x3,    1		; Make 400 if not double scanned
	xbs [$.psy], 15
	jms .ntc		; Positive or zero: no top clip required
	mov a,     [$.psy]
	add [$.hgt], a		; New height
	xbc [$.hgt], 15
	jms .exit		; Turned negative: off screen to the top
	mul a,     [$.mul]	; For new source line select
	sub [$.rch], a		; OK, new source start calculated
	mov a,     0
	mov [$.psy], a		; New Y start (0)
.ntc:	xug x3,    [$.psy]	; Completely off screen to the bottom?
	jms .exit
	mov a,     x3
	sub a,     [$.psy]	; Number of px. available for the source
	xug a,     [$.hgt]
	mov [$.hgt], a		; Truncate height if necessary (may become 0)
	xne a,     0
	jms .exit		; Exit on zero (not handled in the main loop)

	; Rows will be added, so dirty flag will indicate the need to clear

	btc [us_dsprite_df], 0

	; Set up PRAM pointer 3

	jfa us_dsprite_setptr_i {[$.psy], [$.dld]}

	; Set up X0 and X1 for pointing into the occupation data

	mov xh,    0x1111	; 8 bit pointers, they are on the high end
	mov x0,    us_dsprite_ola8
	add x0,    [$.psy]	; Low bounds offset
	mov x1,    x0
	add x1,    400		; High bounds offset

	; Init data to add

	mov a,     [$.rch]	; Start of high part
	mov b,     [$.rcl]	; Low part (does not change)

	; Loop init (in x3 the add value for display list row walking was
	; prepared by us_dsprite_setptr_i)

	add [$.hgt], x0		; Top bound by offset
	mov d,     x3
	mov x2,    P3_AL
	mov x3,    P3_RW
	xbc [$.btp], 0		; Add to bottom if 0
	jms .t			; Add to top if 1

.b:	; Add to bottom end

	mov xm,    0x448C	; X3: PTR16, X2: PTR16, X1: PTR8I, X0: PTR8W
.lpb:	mov c,     [x0]
	xne c,     [x1]
	jms .lxb		; Equal column offsets: row has no more sprites free
	shl c,     5		; Bit offset of display list column
	xch [x2],  c		; Save original P3_AL to restore it after the add
	add [x2],  c		; To high word of display list column entry
	mov [x3],  a
	bts [x2],  4		; To low word of display list column entry
	mov [x3],  b
	mov [x2],  c
	mov c,     1
	add [x0],  c
.leb:	add c:[x2], d
	add [P3_AH], c
	add a,     [$.mul]
	xeq x0,    [$.hgt]
	jms .lpb
	jms .exit

.lxb:	add x0,    1
	jms .leb
.lxt:	add x1,    1
	jms .let

.t:	; Add to top end

	mov xm,    0x44C8	; X3: PTR16, X2: PTR16, X1: PTR8W, X0: PTR8I
.lpt:	mov c,     [x1]
	xne c,     [x0]
	jms .lxt		; Equal column offsets: row has no more sprites free
	sub c,     1
	mov [x1],  c
	shl c,     5		; Bit offset of display list column
	xch [x2],  c		; Save original P3_AL to restore it after the add
	add [x2],  c		; To high word of display list column entry
	mov [x3],  a
	bts [x2],  4		; To low word of display list column entry
	mov [x3],  b
	mov [x2],  c
.let:	add c:[x2], d
	add [P3_AH], c
	add a,     [$.mul]
	xeq x0,    [$.hgt]
	jms .lpt

.exit:	; Restore CPU regs & exit

	mov a,     [$7]
	mov b,     [$8]
	mov d,     [$9]
	mov x0,    [$10]
	mov x1,    [$11]
	mov x2,    [$12]
	mov xm,    [$13]
	mov xh,    [$14]
	rfn



;
; Implementation of us_dsprite_addxy
;
us_dsprite_addxy_i:

.rch	equ	0		; Render command, high
.rcl	equ	1		; Render command, low
.hgt	equ	2		; Height
.btp	equ	3		; Bottom or Top add (bit 0 zero: bottom)
.psx	equ	4		; X position (2's complement)
.psy	equ	5		; Y position (2's complement)
.mul	equ	5		; Width multiplier
.dld	equ	6		; Display list definition

	mov sp,    15

	; Save CPU regs

	mov [$7],  a
	mov [$8],  b
	mov [$9],  d
	mov [$10], x0
	mov [$11], x1
	mov [$12], x2
	mov [$13], xm
	mov [$14], xh

	; Push stuff around a bit to make it right for jumping into
	; us_dlist_add_i: load X position in A, and fill the Y position in
	; it's place.

	mov a,     [$.psy]
	xch a,     [$.psx]

	; Load display list definition

	jfa us_dbuf_getlist
	mov [$.dld], x3

	; Calculate source width multiplier so to know how many to add to the
	; source line select to advance one line. Shift source is not checked
	; (in this routine using a shift source is useless).

	mov x3,    [$.rch]
	shr x3,    12
	and x3,    7		; Source definition select
	add x3,    P_GDG_SA0
	mov d,     [x3]		; Load source definition
	and d,     0xF
	shl d,     1
	add c:d,   1		; Width multiplier: 1 to 31, odd (c is zeroed)
	mov [$.mul], d

	; Set C to one for 8 bit mode, to be used in subsequend mode specific
	; adjustments.

	xbc [$.dld], 12		; 4 bit mode if clear
	mov c,     1		; 1 in 8 bit mode, 0 in 4 bit mode

	; Calculate X high limit

	mov x3,    640
	shr x3,    c		; 320 in 8 bit mode

	; Check on-screen

	xug x3,    a		; Off-screen to the right?
	jms us_dsprite_add_i.exit
	xbs a,     15		; Signed? If so, maybe partly on-screen on left.
	jms .onsc

	; Negative X: possibly partly on-screen. Need to check this situation.

	mov x3,    [$.rch]
	shl x3,    5
	and x3,    7		; Source line size shift
	sbc x3,    0xFFFD	; Adjust: +3 (8 pixels / cell) for 4 bit, +2 (4 pixels / cell) for 8 bit mode
	mov d,     [$.mul]
	shl d,     x3		; Width of graphic element in pixels
	add d,     a
	xsg d,     0		; 1 or more (signed): graphics is on-screen
	jms us_dsprite_add_i.exit

	; Graphics on-screen, render it

.onsc:	shl a,     c		; Double X position for 8 bit mode
	and a,     0x03FF	; 10 bits for shift / position
	mov d,     0xFC00	; Preserve high part of command
	and [$.rcl], d
	or  [$.rcl], a
	jms us_dsprite_add_i.entr



;
; Implementation of us_dsprite_addlist
;
us_dsprite_addlist_i:

.clh	equ	0		; Command list offset, high
.cll	equ	1		; Command list offset, low
.hgt	equ	2		; Height
.btp	equ	3		; Bottom or Top add (bit 0 zero: bottom)
.psy	equ	4		; Y position (2's complement)
.dld	equ	5		; Display list definition

	mov sp,    14

	; Save CPU regs

	mov [$6],  a
	mov [$7],  b
	mov [$8],  d
	mov [$9],  x0
	mov [$10], x1
	mov [$11], x2
	mov [$12], xm
	mov [$13], xh

	; Load display list definition

	jfa us_dbuf_getlist
	mov [$.dld], x3

	; Clip the graphics component if needed. If partial from the top, the
	; render command itself also alters so respecting the first visible
	; line.

	mov x3,    200
	xbs [$.dld], 13		; Double scanned if set
	shl x3,    1		; Make 400 if not double scanned
	xbs [$.psy], 15
	jms .ntc		; Positive or zero: no top clip required
	mov a,     [$.psy]
	add [$.hgt], a		; New height
	xbc [$.hgt], 15
	jms .exit		; Turned negative: off screen to the top
	shl a,     1		; To command list offset
	sub c:[$.cll], a
	sub [$.clh], c		; Adjust command list start
	mov a,     0
	mov [$.psy], a		; New Y start (0)
.ntc:	xug x3,    [$.psy]	; Completely off screen to the bottom?
	jms .exit
	mov a,     x3
	sub a,     [$.psy]	; Number of px. available for the source
	xug a,     [$.hgt]
	mov [$.hgt], a		; Truncate height if necessary (may become 0)
	xne a,     0
	jms .exit		; Exit on zero (not handled in the main loop)

	; Rows will be added, so dirty flag will indicate the need to clear

	btc [us_dsprite_df], 0

	; Set up PRAM pointers

	jfa us_dsprite_setptr_i {[$.psy], [$.dld]}
	jfa us_ptr_set16i {2, [$.clh], [$.cll]}

	; Set up X0 and X1 for pointing into the occupation data

	mov xh,    0x1111	; 8 bit pointers, they are on the high end
	mov x0,    us_dsprite_ola8
	add x0,    [$.psy]	; Low bounds offset
	mov x1,    x0
	add x1,    400		; High bounds offset

	; Loop init (in x3 the add value for display list row walking was
	; prepared by us_dsprite_setptr_i)

	add [$.hgt], x0		; Top bound by offset
	mov d,     x3
	mov x2,    P3_AL
	mov x3,    P3_RW
	xbc [$.btp], 0		; Add to bottom if 0
	jms .t			; Add to top if 1

.b:	; Add to bottom end

	mov xm,    0x448C	; X3: PTR16, X2: PTR16, X1: PTR8I, X0: PTR8W
.lpb:	mov a,     [P2_RW]
	mov b,     [P2_RW]
	mov c,     [x0]
	xne c,     [x1]
	jms .lxb		; Equal column offsets: row has no more sprites free
	shl c,     5		; Bit offset of display list column
	xch [x2],  c		; Save original P3_AL to restore it after the add
	add [x2],  c		; To high word of display list column entry
	mov [x3],  a
	bts [x2],  4		; To low word of display list column entry
	mov [x3],  b
	mov [x2],  c
	mov c,     1
	add [x0],  c
.leb:	add c:[x2], d
	add [P3_AH], c
	xeq x0,    [$.hgt]
	jms .lpb
	jms .exit

.lxb:	add x0,    1
	jms .leb
.lxt:	add x1,    1
	jms .let

.t:	; Add to top end

	mov xm,    0x44C8	; X3: PTR16, X2: PTR16, X1: PTR8W, X0: PTR8I
.lpt:	mov a,     [P2_RW]
	mov b,     [P2_RW]
	mov c,     [x1]
	xne c,     [x0]
	jms .lxt		; Equal column offsets: row has no more sprites free
	sub c,     1
	mov [x1],  c
	shl c,     5		; Bit offset of display list column
	xch [x2],  c		; Save original P3_AL to restore it after the add
	add [x2],  c		; To high word of display list column entry
	mov [x3],  a
	bts [x2],  4		; To low word of display list column entry
	mov [x3],  b
	mov [x2],  c
.let:	add c:[x2], d
	add [P3_AH], c
	xeq x0,    [$.hgt]
	jms .lpt

.exit:	; Restore CPU regs & exit

	mov a,     [$6]
	mov b,     [$7]
	mov d,     [$8]
	mov x0,    [$9]
	mov x1,    [$10]
	mov x2,    [$11]
	mov xm,    [$12]
	mov xh,    [$13]
	rfn
