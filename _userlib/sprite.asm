;
; RRPGE User Library functions - Display List sprite manager
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;
;
; Simple sprite management system for the Graphics Display Generator. For the
; proper function the Display List Clear should be set up appropriately to
; clear the managed columns.
;
; Uses the following CPU RAM locations:
; 0xFADC: Bit0: if clear, indicates the occupation data is dirty.
; 0xFADB: First column to use.
; 0xFADA: Count of columns to use.
; 0xFAD9: Current first occupied column on the top.
; 0xFAD8: Current first non-occupied column on the bottom.
;
; Also adds a Page flip hook (to clear the occupation data).
;

include "../rrpge.asm"

section code



;
; Resets display list occupation data (Page flip hook)
;
; Initializes display list occupation data for rendering a new frame according
; to the bounds in the internal data.
;
us_sprite_reset:
	jma us_sprite_reset_i



;
; Sets sprite area bounds
;
; Param0: Column where the sprite region starts
; Param1: Number of columns used by sprites
;
; Registers C and X3 are not preserved.
;
us_sprite_setbounds:
	jma us_sprite_setbounds_i



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
us_sprite_add:
	jma us_sprite_add_i



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
us_sprite_addxy:
	jma us_sprite_addxy_i



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
us_sprite_addlist:
	jma us_sprite_addlist_i



; 0xFADC: Dirty flag on bit 0: clear if dirty.
us_sprite_df	equ	0xFADC
; 0xFADB: Column to start at
us_sprite_cs	equ	0xFADB
; 0xFADA: Count of columns
us_sprite_cc	equ	0xFADA
; 0xFAD9: Current top column
us_sprite_pt	equ	0xFAD9
; 0xFAD8: Current start column
us_sprite_ps	equ	0xFAD8



;
; Implementation of us_sprite_reset
;
us_sprite_reset_i:

	; Check dirty, do nothing unless it is necessary to clear

	xbc [us_sprite_df], 0
	rfn			; No need to clear, already OK
	bts [us_sprite_df], 0

	; Get total height & Display list size

	mov c,     [P_GDG_DLDEF]
	mov x3,    4		; Smallest display list size is normally 4 entries
	xbc c,     13		; Double scan?
	mov x3,    8		; But 8 entries when double scanned
	and c,     3
	shl x3,    c		; 'x3': Count of entries on a display list row

	; Calculate bottom end value

	mov c,     [us_sprite_cs]
	xug x3,    c
	mov c,     x3		; Too large: constrain
	mov [us_sprite_ps], c

	; Calculate top end value

	add c,     [us_sprite_cc]
	xug x3,    c
	mov c,     x3		; Too large: constrain
	mov [us_sprite_pt], c

	; Done

	rfn



;
; Implementation of us_sprite_setbounds
;
us_sprite_setbounds_i:

.cls	equ	0		; Start column
.clc	equ	1		; Count of columns

	mov c,     [$.cls]
	mov [us_sprite_cs], c
	mov c,     [$.clc]
	mov [us_sprite_cc], c
	btc [us_sprite_df], 0	; Mark dirty
	rfn



;
; Implementation of us_sprite_add
;
us_sprite_add_i:

.rch	equ	0		; Render command, high
.rcl	equ	1		; Render command, low
.hgt	equ	2		; Height
.btp	equ	3		; Bottom or Top add (bit 0 zero: bottom)
.psy	equ	4		; Y position (2's complement)

	; Set jump target

	mov x3,    us_dlist_db_add

.e:	; Mark dirty

	btc [us_sprite_df], 0

	; Determine column to use

	xbs [$.btp], 0
	jms .b			; To add bottom

.t:	; Add to top

	mov c,     [us_sprite_pt]
	xne c,     [us_sprite_ps]
	rfn			; Equal: can not add more sprites
	sub c,     1
	mov [$.btp], c		; Column is excepted here
	mov [us_sprite_pt], c
	jma x3

.b:	; Add to bottom

	mov c,     [us_sprite_ps]
	xne c,     [us_sprite_pt]
	rfn			; Equal: can not add more sprites
	mov [$.btp], c		; Column is excepted here
	add c,     1
	mov [us_sprite_ps], c
	jma x3



;
; Implementation of us_sprite_addxy
;
us_sprite_addxy_i:

.rch	equ	0		; Render command, high
.rcl	equ	1		; Render command, low
.hgt	equ	2		; Height
.btp	equ	3		; Bottom or Top add (bit 0 zero: bottom)
.psx	equ	4		; X position (2's complement)
.psy	equ	5		; Y position (2's complement)

	; Set jump target & jump common

	mov x3,    us_dlist_db_addxy
	jms us_sprite_add_i.e



;
; Implementation of us_sprite_addlist
;
us_sprite_addlist_i:

.clh	equ	0		; Command list offset, high
.cll	equ	1		; Command list offset, low
.hgt	equ	2		; Height
.btp	equ	3		; Bottom or Top add (bit 0 zero: bottom)
.psy	equ	4		; Y position (2's complement)

	; Set jump target & jump common

	mov x3,    us_dlist_db_addlist
	jms us_sprite_add_i.e
