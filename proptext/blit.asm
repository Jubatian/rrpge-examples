;
; Block Blitter functions
;
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;
;
; Some guides for blitter usage:
;
; Note that the source can not be clipped accurately to the destination: it
; will be constrained to be within it, clipped at source cell boundaries. This
; implies that an 1-7 4 bit pixel wide gap may show at the horizontal edges
; depending on the X position. To eliminate this showing, a wider destination
; has to be used than displayed.
;
; If the application has a larger portion of static graphics (such as a tile
; map background) which needs to be rendered and re-rendered fast, keeping
; this graphics on cell boundary should be considered since that way it may
; be rendered faster. To achieve this, the destination surface might need to
; be scrolled with the static background layer.
;
; Usage guides for blit_src, blit_src64, blit_def and blit_def64:
;
; These functions blit a source identified by an index, using tables for the
; blit. In these blits the source bank select is always used. The format of
; the tables are as follows:
;
; Source area table record:
;
; Word0: bit  8-15: Pitch (physical width) of the area in VRAM cells.
;        bit  0- 7: Width of the area in VRAM cells.
; Word1: bit 14-15: VRAM bank of the area.
;        bit    13: VCK (Colorkey enabled if set).
;        bit 10-12: Pixel barrel rotate right.
;        bit  0- 9: Height of the area in lines.
; Word2: VRAM offset where the tile / sprite starts.
; Word3: bit  8-15: Source AND mask.
;        bit  0- 7: Colorkey value.
;
; 64x64 constrained soucre area record:
;
; Word0: bit  8-15: Pitch (physical width) of the area in VRAM cells.
;        bit  3- 7: Unused (available for other uses).
;        bit  0- 2: Width of the area in VRAM cells - 1.
; Word1: bit 14-15: VRAM bank of the area.
;        bit    13: VCK (Colorkey enabled if set).
;        bit 10-12: Pixel barrel rotate right.
;        bit  6- 9: Unused (available for other uses).
;        bit  0- 5: Height of the area in lines - 1.
; Word2: VRAM offset where the tile / sprite starts.
; Word3: bit  8-15: Source AND mask.
;        bit  0- 7: Colorkey value.
;
; Definition table record:
;
; Word0: bit    15: Y mirror if set
;        bit    14: X mirror if set
;        bit    13: VDR (Reindex by destination for Accelerator)
;        bit    12: VRE (Reindex enable for Accelerator)
;        bit  6-11: Source OR mask (for bits 0-5)
;        bit     5: Mode: If set, bits 6-13 are the OR mask, with no VRE
;        bit  0- 4: Reindex bank select
; Word1: Index of the Source area table entry
;
; Excepts CPU page 1 being the User Peripheral Page.
;
; Interface function list
;
; blit
; blit_src
; blit_def
; blit_src64
; blit_def64
;


include "../rrpge.asm"

section code




;
; Clips area to fit & populates Accelerator with positioning data, then starts
; a Block Blitter blit.
;
; Assumes that the Accelerator will operate using only Source X and
; Destination, and no partitioning will be used. Populates registers 0x006,
; 0x00C - 0x00E, and 0x016 - 0x1D, then starts a Block Blitter blit.
;
; The format of the area definitions:
; Word0: bit  8-15: Pitch (physical width) of the area in VRAM cells.
;        bit  0- 7: Width of the area in VRAM cells.
; Word1: bit 14-15: VRAM bank of the area.
;        bit  0-13: Height of the area in lines.
; Word2: Start offset of the area in the VRAM bank in cells.
;
; The X and Y positions are interpreted as 2's complement, so negative values,
; if the source is visible, will cause it positioned crossing the upper left
; edge of the destination area.
;
; For the source the VRAM bank select is always used. For the destination, it
; is ignored, and must be set zero.
;
; From the Blit control flags for the Accelerator only bits 0-7, 12, 13
; and 14 pass in the Accelerator, the rest are given by this function. The
; mirroring settings are as follows:
;
; bit 14: X mirror (VMR)
; bit 15: Y mirror
;
; param0: Source area definition, 0
; param1: Source area definition, 1
; param2: Source area definition, 2
; param3: Destination area definition, 0
; param4: Destination area definition, 1
; param5: Destination area definition, 2
; param6: X position
; param7: Y position
; param8: The Blit control flags for the Accelerator & Mirroring
;
blit:

.sa0	equ	0		; Source area 0: Width
.sa1	equ	1		; Source area 1: Height
.sa2	equ	2		; Source area 2: Start offset
.da0	equ	3		; Destination area 0: Width
.da1	equ	4		; Destination area 1: Height
.da2	equ	5		; Destination area 2: Start offset
.psx	equ	6		; X position
.psy	equ	7		; Y position
.ccf	equ	8		; Blit control flags & Mirroring
.sa3	equ	9		; Source area 3: Pitch
.da3	equ	10		; Destination area 3: Pitch

	mov sp,    16

	; Save CPU regs

	mov [bp + 11], a
	mov [bp + 12], c
	mov [bp + 13], x0
	mov [bp + 14], x1
	mov [bp + 15], xm

	; Set source bank & clean up the height member of it.

	mov a,     0x006
	mov [0x1E02], a
	mov a,     [bp + .sa1]
	shl c:a,   14
	mov [0x1E03], a
	shl c,     2
	mov [bp + .sa1], c

	; Move off pitch from the source / destination area widths

	mov c,     0xFF
	mov a,     [bp + .sa0]
	and [bp + .sa0], c
	shr a,     8
	mov [bp + .sa3], a
	mov a,     [bp + .da0]
	and [bp + .da0], c
	shr a,     8
	mov [bp + .da3], a

	; Y clipping

	mov x0,    [bp + .psy]	; Y position
	mov x1,    [bp + .sa1]	; Height
	xbc [bp + .ccf], 15
	jmr .ymr		; Mirrored on Y

	xbs x0,    15
	jmr .ntc0		; Positive or zero: no top clip required
	add x1,    x0		; New height
	xbc x1,    15
	jmr .exit		; Turned negative: off destination
	mov a,     x0
	mul a,     [bp + .sa3]	; For new source line select
	sub [bp + .sa2], a	; New start offset
	mov x0,    0
.ntc0:	xug [bp + .da1], x0	; Completely off destination to the bottom?
	jmr .exit
	mov a,     [bp + .da1]
	sub a,     x0		; Number of px. avaliable for the source
	xug a,     x1
	mov x1,    a		; Truncate height if necessary
	jmr .yend

.ymr:	xbs x0,    15
	jmr .ntc1		; Positive or zero: no top clip required
	add x1,    x0		; New height
	xbc x1,    15
	jmr .exit		; Turned negative: off destination
	mov x0,    0
.ntc1:	xug [bp + .da1], x0	; Completely off destination to the bottom?
	jmr .exit
	mov a,     [bp + .da1]
	sub a,     x0		; Number of px. avaliable for the source
	xug x1,    a
	jmr .yend		; No need for truncating
	sub x1,    a		; Number of lines to truncate
	mul x1,    [bp + .sa3]	; For new source line select
	sub [bp + .sa2], x1	; New start offset
	mov x1,    a		; New height is the no. of available pixels

.yend:	xne x1,    0
	jmr .exit		; If height ended up zero, no blit
	mov [bp + .psy], x0
	mov [bp + .sa1], x1

	; X clipping. If X position is on cell boundary, it is very similar to
	; Y clipping. Otherwise X has to be truncated and width extended by 1
	; so the "fits in destination" condition is met.

	mov x0,    [bp + .psx]	; X position
	mov x1,    [bp + .sa0]	; Width
	mov c,     x0
	and c,     7
	xeq c,     0
	add x1,    1		; Not on cell boundary: temporary width increment
	asr x0,    3		; X position to cells (2's complement signed)

	xbc [bp + .ccf], 14
	jmr .xmr		; Mirrored on X

	xbs x0,    15
	jmr .nlc0		; Positive or zero: no left clip required
	add x1,    x0		; New width
	xbc x1,    15
	jmr .exit		; Turned negative: off destination
	sub [bp + .sa2], x0	; New start offset
	mov x0,    0
.nlc0:	xug [bp + .da0], x0	; Completely off destination to the right?
	jmr .exit
	mov a,     [bp + .da0]
	sub a,     x0		; Number of cells avaliable for the source
	xug a,     x1
	mov x1,    a		; Truncate width if necessary
	jmr .xend

.xmr:	xbs x0,    15
	jmr .nlc1		; Positive or zero: no left clip required
	add x1,    x0		; New width
	xbc x1,    15
	jmr .exit		; Turned negative: off destination
	mov x0,    0
.nlc1:	xug [bp + .da0], x0	; Completely off destination to the right?
	jmr .exit
	mov a,     [bp + .da0]
	sub a,     x0		; Number of cells avaliable for the source
	xug x1,    a
	jmr .xend		; No need for truncating
	sub x1,    a		; Number of cells to truncate
	sub [bp + .sa2], x1	; New start offset
	mov x1,    a		; New width is the no. of available pixels

.xend:	xeq c,     0
	sub x1,    1		; Not on cell boundary: restore width
	xsg x1,    0
	jmr .exit		; If width ended up zero or negative, no blit
	slc x0,    3		; Return to pixel X position (also adding 'c')
	mov [bp + .psx], x0
	mov [bp + .sa0], x1

	; Clipping done, prepare and fill up Accelerator for the blit

	xbs [bp + .ccf], 15
	jmr .noym		; No Y mirroring
	mov a,     [bp + .sa1]	; Height
	sub a,     1
	mul a,     [bp + .sa3]
	add [bp + .sa2], a	; Bottom to top instead of top to bottom
.noym:	xbs [bp + .ccf], 14
	jmr .noxm		; No X mirroring
	mov a,     [bp + .sa0]	; Width
	sub a,     1
	add [bp + .sa2], a	; Right to left instead of left to right
.noxm:

	mov xm,    0x4444	; Set all to PTR16
	mov x0,    0x1E02	; Graphics FIFO command
	mov x1,    0x1E03	; Graphics FIFO data

	mov c,     0x00C	; Start with blit control flags
	mov [x0],  c
	mov a,     [bp + .ccf]
	and a,     0x70FF
	mov [x1],  a
	mov a,     [bp + .sa1]	; Height
	mov c,     [bp + .sa0]	; Width in cells
	shl c,     3		; Width in pixels
	mov [x1],  a		; Count of Accelerator rows
	mov [x1],  c		; Number of pixels per Accelerator row

	mov c,     0x016	; Start with source X whole
	mov [x0],  c
	mov a,     [bp + .sa2]
	mov [x1],  a		; Source X whole
	mov [x0],  x0		; Skip source X fraction
	mov a,     1
	xbc [bp + .ccf], 14
	sub a,     2		; -1 if X mirrored
	mov [x1],  a
	mov [x0],  x0		; Skip source X increment fraction
	mov a,     [bp + .sa3]	; Source pitch
	xbs [bp + .ccf], 15
	mov [x1],  a		; Source X post-add whole: +pitch
	xbc [bp + .ccf], 15
	sub [x1],  a		; Source X post-add whole: -pitch (reads zero!)
	mov [x0],  x0		; Skip source X post-add fraction
	mov c,     3
	shr c:[bp + .psx], c	; Convert position to cells, saving fraction
	mov a,     [bp + .psy]
	mul a,     [bp + .da3]
	add a,     [bp + .psx]
	add a,     [bp + .da2]
	mov [x1],  a		; Destination whole part
	mov [x1],  c		; Destination fractional part

	; Fire the blit

	mov c,     0x00F	; Accelerator trigger
	mov [x0],  c
	mov [x1],  a		; Start! (Value irrelevant)

	; Restore CPU regs & exit

.exit:	mov a,     [bp + 11]
	mov c,     [bp + 12]
	mov x0,    [bp + 13]
	mov x1,    [bp + 14]
	mov xm,    [bp + 15]
	rfn




;
; Blits by a Source area table
;
; Uses the index to index into the passed source area table (the table may
; span multiple pages, the CPU's address space should be set up accordingly).
;
; The blit configuration is of the same layout like the Definition table's
; Word0.
;
; param0: Index into the source area table
; param1: Start offset of source area table
; param2: Blit configuration
; param3: Destination area definition, 0
; param4: Destination area definition, 1
; param5: Destination area definition, 2
; param6: X position
; param7: Y position
; param8: Blitter function to use (normally blit)
;
blit_src:

.sti	equ	0		; Index into source area table
.sof	equ	1		; Source area table start offset
.bcf	equ	2		; Blit configuration
.da0	equ	3		; Destination area def. 0
.da1	equ	4		; Destination area def. 1
.da2	equ	5		; Destination area def. 2
.psx	equ	6		; X position
.psy	equ	7		; Y position
.blt	equ	8		; Blitter function to use
.ccf	equ	8		; For passing to blit: Colorkey & Control flags
.sa0	equ	0		; For passing to blit: Source area 0
.sa1	equ	1		; For passing to blit: Source area 1
.sa2	equ	2		; For passing to blit: Source area 2
.ble	equ	9		; Blitter function is copied here for transfer

	mov sp,    15

	; Save CPU regs.

	mov [bp + 11], a
	mov [bp + 12], c
	mov [bp + 13], x0
	mov [bp + 14], xm

	mov xm0,   PTR16I
	mov x0,    [bp + .sti]

	; Prepare for feeding the Graphics FIFO

.entr:	mov a,     0x009
	mov [0x1E02], a		; Start with source barrel rotate / colorkey enable

	; Load source area table while building the accelerator parameters

	shl x0,    2
	add x0,    [bp + .sof]	; Source area table offset
	mov a,     [x0]
	mov [bp + .sa0], a
	mov a,     [x0]
	mov c,     a
	shr c,     10		; Source barrel rot & colorkey enable in place
	mov [0x1E03], c		; (Don't care for bits 4 and 5, they are unused)
	and a,     0xC3FF
.en64:	mov [bp + .sa1], a
	mov c,     [bp + .bcf]	; Will be overwritten by .sa2
	mov a,     [x0]
	mov [bp + .sa2], a
	mov a,     [x0]
	mov [0x1E03], a		; Source AND mask & Colorkey

	; Finalize the blit control flags & reindex bank select, then transfer

	mov a,     [bp + .blt]	; The blitter entry point to use
	mov [bp + .ble], a	; Copy it to get it out of the way of the .ccf parameter
	mov a,     c		; Blit configuration (from .bcf)
	shr c,     6		; For OR mask
	mov [0x1E03], a		; Reindex bank select (high bits unused, so don't care)
	xbc a,     5		; Mode bit
	jmr .orms		; OR mask mode if set
	and a,     0xF000
	mov [bp + .ccf], a
	and c,     0x003F	; OR mask
	or  [bp + .ccf], c
	jmr .orme
.orms:	and a,     0xC000
	mov [bp + .ccf], a
	and c,     0x00FF	; OR mask
	or  [bp + .ccf], c
.orme:

	; Transfer: restore registers to get a state like a normal function
	; call. The parameter sequence on the stack matches the called
	; function, so no actual call is required.

	mov a,     [bp + 11]
	mov c,     [bp + 12]
	mov x0,    [bp + 13]
	mov xm,    [bp + 14]
	jma [bp + .ble]




;
; Blits by a Definition table
;
; Uses the index to index into the passed definition table (the table may
; span multiple pages, the CPU's address space should be set up accordingly).
;
; param0: Index into the definition table
; param1: Start offset of source area table
; param2: Start offset of definition area table
; param3: Destination area definition, 0
; param4: Destination area definition, 1
; param5: Destination area definition, 2
; param6: X position
; param7: Y position
; param8: Blitter function to use (normally blit)
;
blit_def:

.dfi	equ	0		; Index into definition table
.sof	equ	1		; Source area table start offset
.dof	equ	2		; Definition table start offset
.da0	equ	3		; Destination area def. 0
.da1	equ	4		; Destination area def. 1
.da2	equ	5		; Destination area def. 2
.psx	equ	6		; X position
.psy	equ	7		; Y position
.blt	equ	8		; Blitter function to use

	mov sp,    15

	; Save CPU regs.

	mov [bp + 11], a
	mov [bp + 12], c
	mov [bp + 13], x0
	mov [bp + 14], xm

	mov xm0,   PTR16I

	; Load the definition table

	mov x0,    [bp + .dfi]
	shl x0,    1
	add x0,    [bp + .dof]	; Definition table offset
	mov a,     [x0]
	mov [bp + .dof], a	; blit_src excepts it in this position
	mov x0,    [x0]		; blit_src uses x0 to index the source area table

	; Pass over

	jmr blit_src.entr




;
; Blits by a 64x64 source area table
;
; Uses the index to index into the passed source area table (the table may
; span multiple pages, the CPU's address space should be set up accordingly).
;
; The blit configuration is of the same layout like the Definition table's
; Word0.
;
; param0: Index into the source area table
; param1: Start offset of source area table
; param2: Blit configuration
; param3: Destination area definition, 0
; param4: Destination area definition, 1
; param5: Destination area definition, 2
; param6: X position
; param7: Y position
; param8: Blitter function to use (normally blit)
;
blit_src64:

.sti	equ	0		; Index into source area table
.sof	equ	1		; Source area table start offset
.bcf	equ	2		; Blit configuration
.da0	equ	3		; Destination area def. 0
.da1	equ	4		; Destination area def. 1
.da2	equ	5		; Destination area def. 2
.psx	equ	6		; X position
.psy	equ	7		; Y position
.blt	equ	8		; Blitter function to use
.ccf	equ	8		; For passing to blit: Colorkey & Control flags
.sa0	equ	0		; For passing to blit: Source area 0
.sa1	equ	1		; For passing to blit: Source area 1
.sa2	equ	2		; For passing to blit: Source area 2
.ble	equ	9		; Blitter function is copied here for transfer

	mov sp,    15

	; Save CPU regs.

	mov [bp + 11], a
	mov [bp + 12], c
	mov [bp + 13], x0
	mov [bp + 14], xm

	mov xm0,   PTR16I
	mov x0,    [bp + .sti]

	; Prepare for feeding the Graphics FIFO

.entr:	mov a,     0x009
	mov [0x1E02], a		; Start with source barrel rotate / colorkey enable

	; Load source area table while building the accelerator parameters

	shl x0,    2
	add x0,    [bp + .sof]	; Source area table offset
	mov a,     [x0]
	and a,     0xFF07
	add a,     1
	mov [bp + .sa0], a
	mov a,     [x0]
	mov c,     a
	shr c,     10		; Source barrel rot & colorkey enable in place
	mov [0x1E03], c		; (Don't care for bits 4 and 5, they are unused)
	and a,     0xC03F
	add a,     1
	jmr blit_src.en64




;
; Blits by a Definition table, using a 64x64 source area table
;
; Uses the index to index into the passed definition table (the table may
; span multiple pages, the CPU's address space should be set up accordingly).
;
; param0: Index into the definition table
; param1: Start offset of source area table
; param2: Start offset of definition area table
; param3: Destination area definition, 0
; param4: Destination area definition, 1
; param5: Destination area definition, 2
; param6: X position
; param7: Y position
; param8: Blitter function to use (normally blit.entr)
;
blit_def64:

.dfi	equ	0		; Index into definition table
.sof	equ	1		; Source area table start offset
.dof	equ	2		; Definition table start offset
.da0	equ	3		; Destination area def. 0
.da1	equ	4		; Destination area def. 1
.da2	equ	5		; Destination area def. 2
.psx	equ	6		; X position
.psy	equ	7		; Y position
.blt	equ	8		; Blitter function to use

	mov sp,    15

	; Save CPU regs.

	mov [bp + 11], a
	mov [bp + 12], c
	mov [bp + 13], x0
	mov [bp + 14], xm

	mov xm0,   PTR16I

	; Load the definition table

	mov x0,    [bp + .dfi]
	shl x0,    1
	add x0,    [bp + .dof]	; Definition table offset
	mov a,     [x0]
	mov [bp + .dof], a	; blit_src excepts it in this position
	mov x0,    [x0]		; blit_src uses x0 to index the source area table

	; Pass over

	jmr blit_src64.entr
