;
; Graphics Display Generator sprite system extension: fixed layers
;
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;
;
; An extension to the GDG sprite system offering a faster handling of fixed
; (permanent) display list data. Such data may be render commands or
; background patterns.
;
; There are two possible ways to use this extension (along with the
; combination of these):
;
; - Providing an already filled up base display list and occupation data to
;   be used to initialize the display list from (by a DMA copy).
;
; - Using an empty initial display list with a pre-set occupation data, then
;   inserting the contents for the fixed portion of the display list.
;
; The occupation data is the internal data of the GDG sprite library. Here it
; is exposed, to be possible to fill it up if not the entire screen (all it's
; lines) should use the same number of fixed render commands.
;
; The structure of the internal data:
;
; It occupies 2 x 512 bytes (512 words), each 512 byte block specifying
; offsets for 200 or 400 lines depending on double scanning (the rest of the
; bytes being unused).
;
; The first 512 byte block contains the bottom end first free offsets.
; Normally these bytes are set 0x02, to point at the first render command
; (offset 0x00 being the background pattern).
;
; The second 512 byte block contains the top end first occupied offsets.
; Normally these bytes are set to point at the end of the display list line,
; which exact offset depends on the display list size and double scanning.
; For the smallest 4 entry (1 bg pattern + 3 render commands) display list
; this offset would be 0x08.
;
; Interface function list
;
; gdgspfix_reset
; gdgspfix_add
; gdgspfix_addsprite
; gdgspfix_addlist
;


include "../rrpge.asm"

section code




;
; Resets the renderer.
;
; This function has the same role like gdgsprit_reset, offering extra features
; to reset the display list with an initial state different than all clear.
;
; The initialization flags direct how the internal data & display list should
; be initialized:
;
; bit  0: If set, internal object data is taken from the offset specified by
;         the internal object data parameter. Otherwise the parameter
;         specifies the global bottom and top end offsets, high 8 bits for the
;         top end, low 8 bits for the bottom end.
; bit  1: If set, the display list is copied from the given source display
;         list. Otherwise it is initialized normally (to zero), and the
;         parameter may be omitted.
;
; All data must be on continuous pages.
;
; param0: Offset of 1024 word internal object data.
; param1: Offset of Display List (size depends on graphics config.)
; param2: Initialization flags.
; param3: Internal object data parameter.
; param4: Source display list offset.
;
gdgspfix_reset:

.ofi	equ	0		; Internal object data offset
.ofd	equ	1		; Display list offset
.flg	equ	2		; Initialization flags
.sri	equ	3		; Internal object data parameter
.srd	equ	4		; Source display list

	mov sp,    11

	; Save CPU regs

	mov [bp +  5], b
	mov [bp +  6], c
	mov [bp +  7], d
	mov [bp +  8], x3
	mov [bp +  9], x2
	mov [bp + 10], x1

	mov xm1,   PTR16I

	; Load current configuration values:
	; 'c': display list size in 256 word units
	; 'x2': internal data DMA offset
	; 'x3': display list DMA offset

	jfa gdgsprit_i_getconfig {[bp + .ofi], [bp + .ofd]}

	; Determine what to do with the internal data

	xbs [bp + .flg], 0
	jmr .ifl		; To filling with bottom & top offsets

	; Load internal data from given offset, using a CPU <=> CPU DMA

	mov x1,    [bp + .sri]
	shr x1,    8
	mov b,     x1
	and b,     0xF		; Bottom of offset
	shr x1,    4
	add x1,    ROPD_RBK_0
	mov x1,    [x1]		; Load bank
	shl x1,    4		; Shift for DMA
	or  x1,    b		; DMA start offset acquired

	mov [0x1F00], x1	; Bottom offset fill
	mov [0x1F02], x2	; Copy list occupation, bottom
	add x1,    1
	add x2,    1
	mov [0x1F00], x1	; Top offset fill
	mov [0x1F02], x2	; Copy list occupation, top
	jmr .dls

.ifl:	; Fill in internal data with Fill DMA

	mov b,     [bp + .sri]
	and b,     0x00FF
	mov x1,    b
	shl b,     8
	or  b,     x1
	mov [0x1F00], b		; Bottom offset fill
	mov [0x1F01], x2	; Fill list occupation, bottom
	mov b,     [bp + .sri]
	and b,     0xFF00
	mov x1,    b
	shr b,     8
	or  b,     x1
	add x2,    1
	mov [0x1F00], b		; Top offset fill
	mov [0x1F01], x2	; Fill list occupation, top

.dls:	; Determine what to do with the display list

	xbs [bp + .flg], 1
	jmr .dfl		; To zero filling

	; Load display list from a given offset, using a CPU <=> CPU DMA

	mov x1,    [bp + .srd]
	shr x1,    8
	mov b,     x1
	and b,     0xF		; Bottom of offset
	shr x1,    4
	add x1,    ROPD_RBK_0
	mov x1,    [x1]		; Load bank
	shl x1,    4		; Shift for DMA
	or  x1,    b		; DMA start offset acquired

.l0:	mov [0x1F00], x1
	mov [0x1F02], x3
	add x1,    1
	add x3,    1
	sub c,     1
	xeq c,     0
	jmr .l0
	jmr .exit

.dfl:	; Zero fill display list with Fill DMA

	mov d,     0
	mov [0x1F00], d
.l1:	mov [0x1F01], x3
	add x3,    1
	sub c,     1
	xeq c,     0
	jmr .l1

.exit:	; Restore CPU regs & exit

	mov b,     [bp +  5]
	mov c,     [bp +  6]
	mov d,     [bp +  7]
	mov x3,    [bp +  8]
	mov x2,    [bp +  9]
	mov x1,    [bp + 10]
	rfn






;
; Adds a rectangular graphics component.
;
; Adds a normal rectangular graphics component to the display list to the
; given display list column. Only the first line's render command needs to be
; provided and the height, subsequent render commands are generated
; accordingly assuming sequentally following source lines. The source line
; select of the sprite must not wrap around during the drawing, or the next
; source definition must be set up in a way it continues the previous block.
;
; param0: Offset of 512 word internal object data.
; param1: Offset of Display List (size depends on requested config.)
; param2: Render command high word
; param3: Render command low word
; param4: Height in lines
; param5: Display list column to add to
; param6: Y position (signed 2's complement, can be partly off-screen)
;
gdgspfix_add:

.ofi	equ	0		; Internal object data offset
.ofd	equ	1		; Display list offset
.rch	equ	2		; Render command, high
.rcl	equ	3		; Render command, low
.hgt	equ	4		; Height
.lcl	equ	5		; Display list column
.psy	equ	6		; Y position
.esz	equ	0		; Display list entry size in words

	mov sp,    13

	; Save CPU regs

	mov [bp +  7], a
	mov [bp +  8], b
	mov [bp +  9], c
	mov [bp + 10], d
	mov [bp + 11], xm
	mov [bp + 12], x3

.entr:	mov xm3,   PTR16I

	; Calculate source width multiplier (as far as possible) so to know
	; how many to add to the source line select to advance one line. The
	; multiplier stays one if the source is a shift source.

	mov x3,    [bp + .rch]
	shr x3,    12
	and x3,    7		; Source definition select
	add x3,    0x1E08
	mov a,     [x3]		; Load source definition
	mov d,     1
	xbc a,     7
	jmr .shfs
	mov d,     a
	and d,     0x7F
	shr a,     8
	and a,     7
	shr d,     a
.shfs:

	; Clip the graphics component if needed. If partial from the top, the
	; render command itself also alters so respecting the first visible
	; line.

	mov x3,    200
	xbs [0x1E04], 15	; Double scanned if set
	shl x3,    1		; Make 400 if not double scanned
	mov c,     0		; Prepare a zero for use where needed
	xbs [bp + .psy], 15
	jmr .ntc		; Positive or zero: no top clip required
	mov a,     [bp + .psy]
	add [bp + .hgt], a	; New height
	xbc [bp + .hgt], 15
	jmr .exit		; Turned negative: off screen to the top
	mul a,     d		; For new source line select
	sub [bp + .rch], a	; OK, new source start calculated
	mov [bp + .psy], c	; New Y start (0)
.ntc:	xug x3,    [bp + .psy]	; Completely off screen to the bottom?
	jmr .exit
	mov a,     x3
	sub a,     [bp + .psy]	; Number of px. available for the source
	xug a,     [bp + .hgt]
	mov [bp + .hgt], a	; Truncate height if necessary
	xne [bp + .hgt], c
	jmr .exit		; Height might have started as or turned zero

	; Add new graphics element to each line.

	mov a,     [0x1E05]
	and a,     3		; Display list entry size
	mov x3,    8		; Base size (for 4 entries)
	shl x3,    a		; 4 / 8 / 16 / 32 entries
	xbc [0x1E04], 15
	shl x3,    1		; Double scan doubles it once more
	mov [bp + .esz], x3
	mov a,     2
	sub [bp + .esz], a	; To counter the post increments
	mul x3,    [bp + .psy]
	add x3,    [bp + .ofd]	; Base offset in display list, for the line
	add x3,    [bp + .lcl]	; Select column to add to
	add x3,    [bp + .lcl]
	mov c,     [bp + .hgt]	; Count of lines to render
	xch d,     [bp + .rch]	; Swap so no need to load in reg. in the loop
	mov a,     [bp + .rcl]
	xbs c,     0
	jmr .c02
	xbs c,     1
	jmr .c1
	add c,     1		; Low bits of 'c': 11
	jmr .lt1
.c1:	add c,     3		; Low bits of 'c': 01
	jmr .lt3
.c02:	xbs c,     1
	jmr .lt0
	add c,     2		; Low bits of 'c': 10
	jmr .lt2

.lt0:	mov [x3],  d
	mov [x3],  a
	add d,     [bp + .rch]	; Add to source line select for the next line
	add x3,    [bp + .esz]	; To next line in display list
.lt1:	mov [x3],  d
	mov [x3],  a
	add d,     [bp + .rch]	; Add to source line select for the next line
	add x3,    [bp + .esz]	; To next line in display list
.lt2:	mov [x3],  d
	mov [x3],  a
	add d,     [bp + .rch]	; Add to source line select for the next line
	add x3,    [bp + .esz]	; To next line in display list
.lt3:	mov [x3],  d
	mov [x3],  a
	add d,     [bp + .rch]	; Add to source line select for the next line
	add x3,    [bp + .esz]	; To next line in display list
	sub c,     4
	xeq c,     0
	jmr .lt0

	; Restore CPU regs & exit

.exit:	mov a,     [bp +  7]
	mov b,     [bp +  8]
	mov c,     [bp +  9]
	mov d,     [bp + 10]
	mov xm,    [bp + 11]
	mov x3,    [bp + 12]
	rfn





;
; Adds a sprite.
;
; A more user friendly variant of gdgspfix_add. It takes a sprite X coordinate
; of which it calculates the appropriate position amount for the render
; command, or determine that the sprite is off display. Note that the X
; coordinate always ranges from 0 - 639 (in 8 bit mode the low bit of this is
; ignored) while Y may range from 0 - 199 (in double scanned mode).
;
; param0: Offset of 512 word internal object data.
; param1: Offset of Display List (size depends on requested config.)
; param2: Render command high word
; param3: Render command low word
; param4: Height in lines
; param5: Display list column to add to
; param6: Y position (signed 2's complement, can be partly off-screen)
; param7: X position (signed 2's complement, can be partly off-screen)
;
gdgspfix_addsprite:

.ofi	equ	0		; Internal object data offset
.ofd	equ	1		; Display list offset
.rch	equ	2		; Render command, high
.rcl	equ	3		; Render command, low
.hgt	equ	4		; Height
.lcl	equ	5		; Display list column
.psy	equ	6		; Y position
.psx	equ	7		; X position

	mov sp,    13

	; Save CPU regs

	xch [bp +  7], a	; Load X position in 'a' while saving
	mov [bp +  8], b
	mov [bp +  9], c
	mov [bp + 10], d
	mov [bp + 11], xm
	mov [bp + 12], x3

	; Check X position, determine if the sprite should be displayed or
	; not.

	xug 640,   a		; Off-screen to the right
	jmr gdgspfix_add.exit
	xbs a,     15		; Only calculate a mess if partly off on the left
	jmr .onsc
	mov xm3,   PTR16
	mov x3,    [bp + .rch]
	shr x3,    12
	and x3,    7		; Source definition select
	add x3,    0x1E08
	mov b,     [x3]		; Load source definition
	mov x3,    b
	xbc x3,    5
	mov x3,    0		; Shift source: multiplier will be 1
	shr x3,    2
	and x3,    6		; Multiplier: 0, 2, 4, 6
	add x3,    1		; Multiplier: 1, 3, 5, 7
	and b,     7		; Width
	shl x3,    b		; Total width of sprite in cells
	shl x3,    3		; Total width in 4 bit pixels
	add a,     x3
	xsg a,     0		; 1 or more (signed): sprite is on-screen
	jmr gdgspfix_add.exit
	sub a,     x3		; Restore .psx

	; Sprite on screen, render it

.onsc:	and a,     0x03FF	; 10 bits for shift / position
	mov b,     0xFC00
	and [bp + .rcl], b
	or  [bp + .rcl], a
	jmr gdgspfix_add.entr





;
; Adds a render command list.
;
; Adds a render command list to the display list to the given display list
; column. The source line select of the render command list should be
; identical, or otherwise point to identically configured sources.
;
; param0: Offset of 512 word internal object data.
; param1: Offset of Display List (size depends on requested config.)
; param2: Render command list offset
; param3: Height in lines
; param4: Display list column to add to
; param5: Y position (signed 2's complement, can be partly off-screen)
;
gdgspfix_addlist:

.ofi	equ	0		; Internal object data offset
.ofd	equ	1		; Display list offset
.orc	equ	2		; Render command list offset
.hgt	equ	3		; Height
.lcl	equ	4		; Display list column
.psy	equ	5		; Y position
.esz	equ	0		; Display list entry size in words

	mov sp,    13

	; Save CPU regs

	mov [bp +  6], a
	mov [bp +  7], b
	mov [bp +  8], c
	mov [bp +  9], d
	mov [bp + 10], xm
	mov [bp + 11], x3
	mov [bp + 12], x2

	mov xm2,   PTR16I
	mov xm3,   PTR16I

	; Clip the graphics component if needed. If partial from the top, the
	; render command itself also alters so respecting the first visible
	; line.

	mov x3,    200
	xbs [0x1E04], 15	; Double scanned if set
	shl x3,    1		; Make 400 if not double scanned
	mov c,     0		; Prepare a zero for use where needed
	xbs [bp + .psy], 15
	jmr .ntc		; Positive or zero: no top clip required
	mov a,     [bp + .psy]
	add [bp + .hgt], a	; New height
	xbc [bp + .hgt], 15
	jmr .exit		; Turned negative: off screen to the top
	shl a,     1
	sub [bp + .orc], a	; New render command list start offset
	mov [bp + .psy], c	; New Y start (0)
.ntc:	xug x3,    [bp + .psy]	; Completely off screen to the bottom?
	jmr .exit
	mov a,     x3
	sub a,     [bp + .psy]	; Number of px. available for the source
	xug a,     [bp + .hgt]
	mov [bp + .hgt], a	; Truncate height if necessary
	xne [bp + .hgt], c
	jmr .exit		; Height might have started as or turned zero

	; Add new graphics element to each line.

	mov a,     [0x1E05]
	and a,     3		; Display list entry size
	mov x3,    8		; Base size (for 4 entries)
	shl x3,    a		; 4 / 8 / 16 / 32 entries
	xbc [0x1E04], 15
	shl x3,    1		; Double scan doubles it once more
	mov [bp + .esz], x3
	mov a,     2
	sub [bp + .esz], a	; To counter the post increments
	mul x3,    [bp + .psy]
	add x3,    [bp + .ofd]	; Base offset in display list, for the line
	add x3,    [bp + .lcl]	; Select column to add to
	add x3,    [bp + .lcl]
	mov x2,    [bp + .orc]
	mov c,     [bp + .hgt]	; Count of lines to render
	xbs c,     0
	jmr .c02
	xbs c,     1
	jmr .c1
	add c,     1		; Low bits of 'c': 11
	jmr .lt1
.c1:	add c,     3		; Low bits of 'c': 01
	jmr .lt3
.c02:	xbs c,     1
	jmr .lt0
	add c,     2		; Low bits of 'c': 10
	jmr .lt2

.lt0:	mov a,     [x2]
	mov [x3],  a
	mov a,     [x2]
	mov [x3],  a
	add x3,    [bp + .esz]	; To next line in display list
.lt1:	mov a,     [x2]
	mov [x3],  a
	mov a,     [x2]
	mov [x3],  a
	add x3,    [bp + .esz]	; To next line in display list
.lt2:	mov a,     [x2]
	mov [x3],  a
	mov a,     [x2]
	mov [x3],  a
	add x3,    [bp + .esz]	; To next line in display list
.lt3:	mov a,     [x2]
	mov [x3],  a
	mov a,     [x2]
	mov [x3],  a
	add x3,    [bp + .esz]	; To next line in display list
	sub c,     4
	xeq c,     0
	jmr .lt0

	; Restore CPU regs & exit

.exit:	mov a,     [bp +  6]
	mov b,     [bp +  7]
	mov c,     [bp +  8]
	mov d,     [bp +  9]
	mov xm,    [bp + 10]
	mov x3,    [bp + 11]
	mov x2,    [bp + 12]
	rfn
