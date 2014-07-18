;
; Graphics Display Generator sprite system
;
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;
;
; A generic library for realizing a sprite based display using the Graphics
; Display Generator. It supports all GDG configurations (double scanning and
; display list entry sizes).
;
; The intended workflow:
;
; - gdgsprit_init: Initializes or resets the library, also setting the
;   Graphics Display Generator to the appropriate mode.
;
; - gdgsprit_add: Adds a sprite to the display.
;
; - gdgsprit_frame: Waits for Vertical Blank, then outputs the composed
;   display list.
;
; - gdgsprit_reset: Resets display list and internal data, so drawing next
;   frame may start.
;
; Note that gdgsprit_init not necessarily have to be called for the library to
; work; you may set up the graphics display generator's configuration by other
; means. Calling gdgsprit_reset is sufficient this case to initialize the
; internal data in a suitable manner for the library.
;
; The library excepts CPU page 1 being the User Peripheral Page, and page 0
; being the ROPD.
;
; If there are components to be built using the Accelerator, they typically
; should be started after calling gdgsprit_frame, to give the Accelerator the
; most time to work asynchronously. Only then should gdgsprit_reset be called.
;
; Interface function list:
;
; gdgsprit_init
; gdgsprit_add
; gdgsprit_addsprite
; gdgsprit_addlist
; gdgsprit_addbg
; gdgsprit_addbglist
; gdgsprit_frame
; gdgsprit_reset
;


include "../rrpge.asm"

section code





;
; Initializes or resets the library.
;
; Display list size depends on the passed Graphics Display Generator
; configuration, the followings are possible:
;
; 3200 words (1 page) for 4/8 entry / line.
; 6400 words (2 pages) for 8/16 entry / line.
; 12800 words (4 pages) for 16/32 entry / line.
; 25600 words (7 pages) for 32/64 entry / line.
;
; The display list must be in CPU RAM. It must begin on 256 word boundary:
; the low 8 bits of the offset are dropped. The internal data also must begin
; on 256 word boundary.
;
; In the case of 4/8 entry / line the actual number of words used is 3328.
;
; All data must be on continuous pages.
;
; param0: Offset of 512 word internal object data.
; param1: Offset of Display List (size depends on requested config.)
; param2: Offset of Graphics Display Generator configuration (12 words).
;
gdgsprit_init:

.ofi	equ	0		; Internal object data offset
.ofd	equ	1		; Display list offset
.ofc	equ	2		; GDG configuration offset

; The internal object data contains occupation information in the following
; manner:
;
; Word 0x000 - 0xC7: Bottom end first free offsets
; Word 0x100 - 01C7: Top end first occupied offsets
;
; In a clear 16 entry display list for all lines these would form as 0x02 for
; the bottom end first free, and 0x1E for the top end first free.

	mov sp,    7

	; Save CPU regs

	mov [bp + 3], c
	mov [bp + 4], xm
	mov [bp + 5], x3
	mov [bp + 6], x2

	; Initialize the Graphics Display Generator

	mov xm3,   PTR16I
	mov x3,    0x1E04
	mov xm2,   PTR16I
	mov x2,    [bp + .ofc]
.l0:	mov c,     [x2]
	mov [x3],  c
	xeq x3,    0x1E10
	jmr .l0

	; Reset so rendering may start

	jfa gdgsprit_reset {[bp + .ofi], [bp + .ofd]}

	; Restore CPU regs & exit

	mov c,     [bp + 3]
	mov xm,    [bp + 4]
	mov x3,    [bp + 5]
	mov x2,    [bp + 6]
	rfn





;
; Adds a rectangular graphics component.
;
; Adds a normal rectangular graphics component to the display list, either to
; the bottom or the top end. Only the first line's render command needs to be
; provided and the height, subsequent render commands are generated
; accordingly assuming sequentally following source lines. If the display list
; for a line is full, the line is simply omitted. The source line select of
; the sprite must not wrap around during the drawing, or the next source
; definition must be set up in a way it continues the previous block.
;
; param0: Offset of 512 word internal object data.
; param1: Offset of Display List (size depends on requested config.)
; param2: Render command high word
; param3: Render command low word
; param4: Y position (signed 2's complement, can be partly off-screen)
; param5: Height in lines
; param6: 0: add to bottom; 1: add to top (only lowest bit effective)
;
gdgsprit_add:

.ofi	equ	0		; Internal object data offset
.ofd	equ	1		; Display list offset
.rch	equ	2		; Render command, high
.rcl	equ	3		; Render command, low
.psy	equ	4		; Y position
.hgt	equ	5		; Height
.btp	equ	6		; Bottom / top add select
.esz	equ	0		; Display list entry size in words

	mov sp,    17

	; Save CPU regs

	mov [bp +  7], a
	mov [bp +  8], b
	mov [bp +  9], c
	mov [bp + 10], d
	mov [bp + 11], xm
	mov [bp + 12], x3
	mov [bp + 13], x2
	mov [bp + 14], x1
	mov [bp + 15], x0
	mov [bp + 16], xh

	; Load the source width multiplier so to know how many to add to the
	; source line select to advance one line. The multiplier stays one if
	; the source is a shift source (multiplier ignored).

	mov xm3,   PTR16I
	mov x3,    [bp + .rch]
	shr x3,    12
	and x3,    7		; Source definition select
	add x3,    0x1E08
	mov a,     [x3]		; Load source definition
	mov x2,    a
	shr x2,    2
	and x2,    6		; Multiplier: 0, 2, 4, 6
	add x2,    1		; Multiplier: 1, 3, 5, 7
	xbc a,     5
	mov x2,    1		; Shift source: multiplier is 1

	; Clip the graphics component if needed. If partial from the top, the
	; render command itself also alters so respecting the first visible
	; line.

	mov x3,    200
	xbs [0x1E04], 15	; Double scanned if set
	shl x3,    1		; Make 400 if not double scanned
	xbs [bp + .psy], 15
	jmr .ntc		; Positive or zero: no top clip required
	mov a,     0
	sub a,     [bp + .psy]
	sub [bp + .hgt], a	; New height
	xbc [bp + .hgt], 15
	jmr .exit		; Turned negative: off screen to the top
	mul a,     x2		; For new source line select
	add [bp + .rch], a	; OK, new source start calculated
	mov a,     0
	mov [bp + .psy], a	; New Y start
.ntc:	xug x3,    [bp + .psy]	; Completely off screen to the bottom?
	jmr .exit
	mov a,     [bp + .psy]
	add a,     [bp + .hgt]
	xug x3,    a
	mov a,     x3		; Truncate sprite on the bottom
	sub a,     [bp + .psy]
	mov [bp + .hgt], a
	xne a,     0
	jmr .exit		; Height might have started as or turned zero

	; Add to each line. If the top & bottom pointers equal, it can not be
	; added (the list is full). Otherwise add to the appropriate end, and
	; increment (bottom end) / decrement (top end) the pointer.

	mov xm0,   PTR8
	mov xm1,   PTR8
	mov x0,    [bp + .ofi]	 ; Calculate bottom / top end start offsets
	shl c:x0,  1
	mov xh0,   c
	mov xh1,   c
	add x0,    [bp + .psy]
	mov x1,    x0
	add x1,    512
	mov a,     [0x1E05]
	and a,     3		; Display list entry size
	mov b,     8		; Base size (for 4 entries)
	shl b,     a		; 4 / 8 / 16 / 32 entries
	xbc [0x1E04], 15
	shl b,     1		; Double scan doubles it once more
	mov [bp + .esz], b
	mul b,     [bp + .psy]
	add b,     [bp + .ofd]	; Base offset in display list, for the line
	mov d,     [bp + .hgt]
	mov c,     2		; Prepare for offset increments / decrements

	xbs [bp + .btp], 0
	jmr .abt		; Add to bottom

.atp:	mov xm0,   PTR8I	; Add to top
	sub b,     2		; Alter base offset to get the right pointers
.lt:	mov x3,    [x1]
	xne x3,    [x0]
	jmr .lte		; Equal offsets: no more space remained.
	add x3,    b		; Offset in display list
	mov a,     [bp + .rch]
	mov [x3],  a
	mov a,     [bp + .rcl]
	mov [x3],  a
	sub [x1],  c		; Decremented bottom offset
.lte:	add [bp + .rch], x2	; Add to source line select for the next line
	add b,     [bp + .esz]	; To next line in display list
	add x1,    1		; To next line in pointer list
	sub d,     1
	xeq d,     0		; End of sprite
	jmr .lt
	jmr .exit

.abt:	mov xm1,   PTR8I	; Add to bottom
.lb:	mov x3,    [x0]
	xne x3,    [x1]
	jmr .lbe		; Equal offsets: no more space remained.
	add x3,    b		; Offset in display list
	mov a,     [bp + .rch]
	mov [x3],  a
	mov a,     [bp + .rcl]
	mov [x3],  a
	add [x0],  c		; Incremented bottom offset
.lbe:	add [bp + .rch], x2	; Add to source line select for the next line
	add b,     [bp + .esz]	; To next line in display list
	add x0,    1		; To next line in pointer list
	sub d,     1
	xeq d,     0		; End of sprite
	jmr .lb

	; Restore CPU regs & exit

.exit:	mov a,     [bp +  7]
	mov b,     [bp +  8]
	mov c,     [bp +  9]
	mov d,     [bp + 10]
	mov xm,    [bp + 11]
	mov x3,    [bp + 12]
	mov x2,    [bp + 13]
	mov x1,    [bp + 14]
	mov x0,    [bp + 15]
	mov xh,    [bp + 16]
	rfn





;
; Adds a sprite.
;
; A more user friendly variant of gdgsprit_add. It takes a sprite X coordinate
; of which it calculates the appropriate position amount for the render
; command, or determine that the sprite is off display. Note that the X
; coordinate always ranges from 0 - 639 (in 8 bit mode the low bit of this is
; ignored) while Y may range from 0 - 199 (in double scanned mode).
;
; param0: Offset of 512 word internal object data.
; param1: Offset of Display List (size depends on requested config.)
; param2: Render command high word
; param3: Render command low word
; param4: X position (signed 2's complement, can be partly off-screen)
; param5: Y position (signed 2's complement, can be partly off-screen)
; param6: Height in lines
; param7: 0: add to bottom; 1: add to top (only lowest bit effective)
;
gdgsprit_addsprite:

.ofi	equ	0		; Internal object data offset
.ofd	equ	1		; Display list offset
.rch	equ	2		; Render command, high
.rcl	equ	3		; Render command, low
.psx	equ	4		; X position
.psy	equ	5		; Y position
.hgt	equ	6		; Height
.btp	equ	7		; Bottom / top add select

	mov sp,    12

	; Save CPU regs

	mov [bp +  8], a
	mov [bp +  9], b
	mov [bp + 10], xm
	mov [bp + 11], x3

	; Check X position, determine if the sprite should be displayed or
	; not.

	mov a,     [bp + .psx]
	xug 640,   a
	jmr .exit		; Off-screen to the right
	xbs a,     15		; Only calculate a mess if partly off on the left
	jmr .onsc
	mov xm3,   PTR16
	mov x3,    [bp + .rch]
	shr x3,    12
	and x3,    7		; Source definition select
	add x3,    0x1E08
	mov b,     [x3]		; Load source definition
	mov x3,    b
	shr x3,    2
	and x3,    6		; Multiplier: 0, 2, 4, 6
	add x3,    1		; Multiplier: 1, 3, 5, 7
	xbc b,     5
	mov x3,    1		; Shift source: multiplier is 1
	and b,     7		; Width
	shl x3,    b		; Total width of sprite in cells
	shl x3,    3		; Total width in 4 bit pixels
	add a,     x3
	xsg a,     0		; 1 or more (signed): sprite is on-screen
	jmr .exit
	sub a,     x3		; Restore .psx

	; Sprite on screen, render it

.onsc:	and a,     0x03FF	; 10 bits for shift / position
	mov b,     [bp + .rcl]
	and b,     0xFC00
	or  a,     b		; Created .rcl (render command low) to send
	jfa gdgsprit_add {[bp + .ofi], [bp + .ofd], [bp + .rch], a, [bp + .psy], [bp + .hgt], [bp + .btp]}

	; Restore CPU regs & exit

.exit:	mov a,     [bp +  8]
	mov b,     [bp +  9]
	mov xm,    [bp + 10]
	mov x3,    [bp + 11]
	rfn





;
; Adds a render command list.
;
; Adds a render command list to the display list, either to the bottom or the
; top end. If the display list for a line is full, the line is simply omitted.
; The source line select of the render command list should be identical, or
; otherwise point to identically configured sources.
;
; param0: Offset of 512 word internal object data.
; param1: Offset of Display List (size depends on requested config.)
; param2: Render command list offset
; param3: Y position (signed 2's complement, can be partly off-screen)
; param4: Height in lines
; param5: 0: add to bottom; 1: add to top (only lowest bit effective)
;
gdgsprit_addlist:

.ofi	equ	0		; Internal object data offset
.ofd	equ	1		; Display list offset
.orc	equ	2		; Render command list offset
.psy	equ	3		; Y position
.hgt	equ	4		; Height
.btp	equ	5		; Bottom / top add select
.esz	equ	0		; Display list entry size in words

	mov sp,    16

	; Save CPU regs

	mov [bp +  6], a
	mov [bp +  7], b
	mov [bp +  8], c
	mov [bp +  9], d
	mov [bp + 10], xm
	mov [bp + 11], x3
	mov [bp + 12], x2
	mov [bp + 13], x1
	mov [bp + 14], x0
	mov [bp + 15], xh

	; Clip the graphics component if needed. If partial from the top, the
	; render command itself also alters so respecting the first visible
	; line.

	mov x3,    200
	xbs [0x1E04], 15	; Double scanned if set
	shl x3,    1		; Make 400 if not double scanned
	xbs [bp + .psy], 15
	jmr .ntc		; Positive or zero: no top clip required
	mov a,     0
	sub a,     [bp + .psy]
	sub [bp + .hgt], a	; New height
	xbc [bp + .hgt], 15
	jmr .exit		; Turned negative: off screen to the top
	shl a,     1
	add [bp + .orc], a	; New render command list start offset
	mov a,     0
	mov [bp + .psy], a	; New Y start
.ntc:	xug x3,    [bp + .psy]	; Completely off screen to the bottom?
	jmr .exit
	mov a,     [bp + .psy]
	add a,     [bp + .hgt]
	xug x3,    a
	mov a,     x3		; Truncate sprite on the bottom
	sub a,     [bp + .psy]
	mov [bp + .hgt], a
	xne a,     0
	jmr .exit		; Height might have started as or turned zero

	; Add to each line. If the top & bottom pointers equal, it can not be
	; added (the list is full). Otherwise add to the appropriate end, and
	; increment (bottom end) / decrement (top end) the pointer.

	mov xm0,   PTR8
	mov xm1,   PTR8
	mov x0,    [bp + .ofi]	 ; Calculate bottom / top end start offsets
	shl c:x0,  1
	mov xh0,   c
	mov xh1,   c
	add x0,    [bp + .psy]
	mov x1,    x0
	add x1,    512
	mov a,     [0x1E05]
	and a,     3		; Display list entry size
	mov b,     8		; Base size (for 4 entries)
	shl b,     a		; 4 / 8 / 16 / 32 entries
	xbc [0x1E04], 15
	shl b,     1		; Double scan doubles it once more
	mov [bp + .esz], b
	mul b,     [bp + .psy]
	add b,     [bp + .ofd]	; Base offset in display list, for the line
	mov d,     [bp + .hgt]
	mov c,     2		; Prepare for offset increments / decrements
	mov x2,    [bp + .orc]
	mov xm2,   PTR16I	; Prepare source command list pointer

	xbs [bp + .btp], 0
	jmr .abt		; Add to bottom

.atp:	mov xm0,   PTR8I	; Add to top
	sub b,     2		; Alter base offset to get the right pointers
.lt:	mov x3,    [x1]
	xne x3,    [x0]
	jmr .ltx		; Equal offsets: no more space remained.
	add x3,    b		; Offset in display list
	mov a,     [x2]
	mov [x3],  a
	mov a,     [x2]
	mov [x3],  a
	sub [x1],  c		; Decremented bottom offset
.lte:	add b,     [bp + .esz]	; To next line in display list
	add x1,    1		; To next line in pointer list
	sub d,     1
	xeq d,     0		; End of sprite
	jmr .lt
	jmr .exit
.ltx:	add x2,    2		; Skip source line
	jmr .lte

.abt:	mov xm1,   PTR8I	; Add to bottom
.lb:	mov x3,    [x0]
	xne x3,    [x1]
	jmr .lbx		; Equal offsets: no more space remained.
	add x3,    b		; Offset in display list
	mov a,     [x2]
	mov [x3],  a
	mov a,     [x2]
	mov [x3],  a
	add [x0],  c		; Incremented bottom offset
.lbe:	add b,     [bp + .esz]	; To next line in display list
	add x0,    1		; To next line in pointer list
	sub d,     1
	xeq d,     0		; End of sprite
	jmr .lb
	jmr .exit
.lbx:	add x2,    2		; Skip source line
	jmr .lbe

	; Restore CPU regs & exit

.exit:	mov a,     [bp +  6]
	mov b,     [bp +  7]
	mov c,     [bp +  8]
	mov d,     [bp +  9]
	mov xm,    [bp + 10]
	mov x3,    [bp + 11]
	mov x2,    [bp + 12]
	mov x1,    [bp + 13]
	mov x0,    [bp + 14]
	mov xh,    [bp + 15]
	rfn





;
; Adds a single background pattern entry.
;
; Adds a bg. pattern entry to the display list. One pattern is 32 bits.
;
; param1: Offset of Display List (size depends on requested config.)
; param2: Background pattern, high
; param3: Background pattern, low
; param4: Line to add it to
;
gdgsprit_addbg:

.ofd	equ	0		; Display list offset
.bgh	equ	1		; Background pattern, high
.bgl	equ	2		; Background pattern, low
.psy	equ	3		; Line to add it to (Y position)

	mov sp,    7

	; Save CPU regs

	mov [bp + 4], a
	mov [bp + 5], xm
	mov [bp + 6], x3

	; Check if line is valid for the display list

	mov a,     200
	xbs [0x1E04], 15	; Double scanned if set
	shl a,     1		; Make 400 if not double scanned
	xug a,     [bp + .psy]
	jmr .exit		; Not valid (Y not less than line max)

	; Add pattern to line

	mov a,     [0x1E05]
	and a,     3		; Display list entry size
	mov x3,    8		; Base size (for 4 entries)
	shl x3,    a		; 4 / 8 / 16 / 32 entries
	xbc [0x1E04], 15
	shl x3,    1		; Double scan doubles it once more
	mul x3,    [bp + .psy]
	add x3,    [bp + .ofd]	; Position to the line

	mov xm3,   PTR16I
	mov a,     [bp + .bgh]
	mov [x3],  a
	mov a,     [bp + .bgl]
	mov [x3],  a

	; Restore CPU regs & exit

.exit:	mov a,     [bp + 4]
	mov xm,    [bp + 5]
	mov x3,    [bp + 6]
	rfn





;
; Adds a background pattern list.
;
; Adds a background pattern list (200 or 400 entries depending on double scan)
; to the display list. One pattern is 32 bits, high word first.
;
; param1: Offset of Display List (size depends on requested config.)
; param2: Background pattern list (400 or 800 words).
;
gdgsprit_addbglist:

.ofd	equ	0		; Display list offset
.obg	equ	1		; Background pattern list
.esz	equ	0		; Display list entry size in words

	mov sp,    7

	; Save CPU regs

	mov [bp + 2], a
	mov [bp + 3], b
	mov [bp + 4], xm
	mov [bp + 5], x3
	mov [bp + 6], x2

	; Load pointers

	mov xm3,   PTR16I
	mov xm2,   PTR16I
	mov x3,    [bp + .ofd]
	mov x2,    [bp + .obg]

	; Add pattern to each line.

	mov a,     [0x1E05]
	and a,     3		; Display list entry size
	mov b,     8		; Base size (for 4 entries)
	shl b,     a		; 4 / 8 / 16 / 32 entries
	xbc [0x1E04], 15
	shl b,     1		; Double scan doubles it once more
	sub b,     2		; Remove the 2 increments which will happen
	mov [bp + .esz], b
	mov b,     200
	xbs [0x1E04], 15	; Double scanned if set
	shl b,     1		; Make 400 if not double scanned

.lp:	mov a,     [x2]
	mov [x3],  a
	mov a,     [x2]
	mov [x3],  a
	add x3,    [bp + .esz]	; To next line in display list
	mov a,     [x2]
	mov [x3],  a
	mov a,     [x2]
	mov [x3],  a
	add x3,    [bp + .esz]	; To next line in display list
	sub b,     2
	xeq b,     0		; End of display list
	jmr .lp

	; Restore CPU regs & exit

	mov a,     [bp + 2]
	mov b,     [bp + 3]
	mov xm,    [bp + 4]
	mov x3,    [bp + 5]
	mov x2,    [bp + 6]
	rfn





;
; Submits a display list to the display.
;
; Waits for VBlank and Graphics FIFO finish, then copies the list to the Video
; RAM, to the area where the Graphics Display Generator excepts it, finally
; preparing for a new frame.
;
; All data must be on continuous pages.
;
; param0: Offset of 1024 word internal object data.
; param1: Offset of Display List (size depends on graphics config.)
;
gdgsprit_frame:

.ofi	equ	0		; Internal object data offset
.ofd	equ	1		; Display list offset

	mov sp,    10

	; Save CPU regs

	mov [bp + 3], a
	mov [bp + 4], b
	mov [bp + 5], c
	mov [bp + 6], d
	mov [bp + 7], xm
	mov [bp + 8], x3
	mov [bp + 9], x2

	; Load current configuration values:
	; 'b': display list DMA offset in VRAM (target)
	; 'c': display list size in 256 word units
	; 'x3': display list DMA offset (source)

	jfa gdgsprit_i_getconfig {[bp + .ofi], [bp + .ofd]}

	; Wait graphics FIFO end, and a line within VBlank. By the kernel's
	; timing limitations hitting in a 16 line tall area is guaranteed,
	; here a safe 20 line area is targeted (minimal VBlank is 49 lines).

	jmr .l0
.lw:	jsv {kc_dly_delay, 700}
.l0:	mov a,     [0x1E01]	; Check the Graphics FIFO
	xbc a,     0		; FIFO busy?
	jmr .lw
	jsv {kc_vid_getline}
	add a,     29		; Wait for a line sufficiently within VBlank
	xbs a,     15		; If positive, not in VBlank, so wait
	jmr .lw

	; Copy into VRAM & clear source (this might not finish before the
	; frame starts to be drawn, but performs faster than the beam, so OK).
	; Rough cycle estimations:
	; List  4/ 8 entries:  13 * 256 words;  3700 cycles ( 9 lines)
	; List  8/16 entries:  25 * 256 words;  7125 cycles (19 lines)
	; List 16/32 entries:  50 * 256 words; 14250 cycles (36 lines)
	; List 32/64 entries: 100 * 256 words; 28500 cycles (71 lines)

.l1:	mov [0x1F00], x3	; Source display list
	mov [0x1F03], b		; Target in VRAM, direction: CPU => VRAM, go
	add x3,    1
	add b,     1
	sub c,     1
	xeq c,     0
	jmr .l1

	; Restore CPU regs & exit

	mov a,     [bp + 3]
	mov b,     [bp + 4]
	mov c,     [bp + 5]
	mov d,     [bp + 6]
	mov xm,    [bp + 7]
	mov x3,    [bp + 8]
	mov x2,    [bp + 9]
	rfn





;
; Resets the renderer.
;
; Resets the display list & the internal state so building the next display
; list may start.
;
; All data must be on continuous pages.
;
; param0: Offset of 1024 word internal object data.
; param1: Offset of Display List (size depends on graphics config.)
;
gdgsprit_reset:

.ofi	equ	0		; Internal object data offset
.ofd	equ	1		; Display list offset

	mov sp,    10

	; Save CPU regs

	mov [bp + 4], b
	mov [bp + 5], c
	mov [bp + 6], d
	mov [bp + 8], x3
	mov [bp + 9], x2

	; Load current configuration values:
	; 'd': top offset for occupation list
	; 'c': display list size in 256 word units
	; 'x2': internal data DMA offset
	; 'x3': display list DMA offset

	jfa gdgsprit_i_getconfig {[bp + .ofi], [bp + .ofd]}

	; Fill in internal data with Fill DMA

	mov b,     0x0202
	mov [0x1F00], b		; Bottom offset fill
	mov [0x1F01], x2	; Fill list occupation, bottom
	add x2,    1
	mov [0x1F00], d		; Top offset fill
	mov [0x1F01], x2	; Fill list occupation, top

	; Zero fill display list with Fill DMA

	mov d,     0
	mov [0x1F00], d
.l1:	mov [0x1F01], x3
	add x3,    1
	sub c,     1
	xeq c,     0
	jmr .l1

	; Restore CPU regs & exit

	mov b,     [bp + 4]
	mov c,     [bp + 5]
	mov d,     [bp + 6]
	mov x3,    [bp + 8]
	mov x2,    [bp + 9]
	rfn





;
; Internal function to query the current configuration
;
; param0: Offset of 1024 word internal object data.
; param1: Offset of Display List (size depends on graphics config.)
; Ret. b: DMA start offset for destination display list (in VRAM)
; Ret. c: Display list size in 256 word units
; Ret. d: Initializing top offset for occupation data
; Ret.x2: DMA start offset for internal data
; Ret.x3: DMA start offset for source display list
;
gdgsprit_i_getconfig:

.ofi	equ	0		; Internal object data offset
.ofd	equ	1		; Display list offset

	mov sp,    4

	; Save CPU regs

	mov [bp + 2], a
	mov [bp + 3], xm

	; Prepare initializing top-end list occupation data in 'd'

	mov b,     [0x1E05]	; Display list definition; bit 0-1: size.
	and b,     0x3		; Display list size
	mov d,     8
	shl d,     b		; Apply display list size
	xbc [0x1E04], 15	; If double scanned, double once more
	shl d,     1		; 'd' is 8 / 16 / 32 / 64 / 128 here
	mov c,     d		; It will be top end first occupied
	shl c,     8
	or  d,     c		; Replicate it to bits 8-15

	; Calculate mask for display list def. start offset

	mov x3,   0x01FC
	shl x3,   b		; Low bits of start unused depending on size
	and x3,   0x01FC

	; Calculate display list size in 256 word blocks in 'c'

	mov a,     25		; 128 * 25 = 3200
	shl a,     b		; Apply size, but now in 128 word units
	mov c,     a
	and c,     1		; Will be 1 if size was 0.
	shr a,     1
	add c,     a		; 13 * 256 words if size is 0.

	; Reload display list def. to produce DMA start offset in VRAM to 'b'

	mov b,     [0x1E05]	; Display list definition; bit 2-8: offset.
	and b,     x3		; So far in 512 VRAM cell units.
	shl b,     2		; Now in 128 VRAM cell units, for DMA.

	; Prepare x3 to be used as pointer

	mov xm3,   PTR16

	; Prepare DMA start offset for internal data in 'x2'

	mov x3,    [bp + .ofi]
	shr x3,    8
	mov x2,    x3
	and x2,    0xF		; Bottom of offset
	shr x3,    4
	add x3,    ROPD_RBK_0
	mov x3,    [x3]		; Load bank
	shl x3,    4		; Shift for DMA
	or  x2,    x3		; DMA start offset acquired

	; Prepare DMA start offset for display list data in 'x3'

	mov x3,    [bp + .ofd]
	shr x3,    8
	mov a,     x3
	and a,     0xF		; Bottom of offset
	shr x3,    4
	add x3,    ROPD_RBK_0
	mov x3,    [x3]		; Load bank
	shl x3,    4		; Shift for DMA
	or  x3,    a		; DMA start offset acquired

	; Restore CPU regs & exit

	mov a,     [bp + 2]
	mov xm,    [bp + 3]
	rfn
