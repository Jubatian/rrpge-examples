;
; Block Blitter, non-clipping blit functions
;
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;
;
; These non-clipping blit functions work mostly like the blit functions of
; blit.asm except that they don't parform any visibility testing or clipping.
; These may be useful for working together with a GDG sprite system to build
; scrolling game fields.
;
; Excepts CPU page 1 being the User Peripheral Page.
;
; Interface function list
;
; blitnc
;


include "../rrpge.asm"

section code




;
; Populates Accelerator with positioning data, then starts a Block Blitter
; blit.
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
; For the destination Width, Height and Destination bank is unused.
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
blitnc:

.sa0	equ	0		; Source area 0: Width
.sa1	equ	1		; Source area 1: Height
.sa2	equ	2		; Source area 2: Start offset
.da0	equ	3		; Destination area 0: Width
.da1	equ	4		; Destination area 1: (Unused here)
.da2	equ	5		; Destination area 2: Start offset
.psx	equ	6		; X position
.psy	equ	7		; Y position
.ccf	equ	8		; Blit control flags & Mirroring
.sa3	equ	4		; Source area 3: Pitch, replaces unused da1
.da3	equ	3		; Destination area 3: Pitch, replaces width

	mov sp,    14

	; Save CPU regs

	mov [bp +  9], a
	mov [bp + 10], c
	mov [bp + 11], x0
	mov [bp + 12], x1
	mov [bp + 13], xm

.entr:	mov xm,    0x4444	; Set all to PTR16
	mov x0,    0x1E02	; Graphics FIFO command
	mov x1,    0x1E03	; Graphics FIFO data

	; Set source bank & clean up the height member of it.

	mov a,     0x006
	mov [x0],  a
	mov a,     [bp + .sa1]
	shl c:a,   14
	mov [x1],  a
	shl c,     2
	mov [bp + .sa1], c

	; Move off pitch from the source / destination area widths

	mov c,     0xFF
	mov a,     [bp + .sa0]
	and [bp + .sa0], c
	shr a,     8
	mov [bp + .sa3], a
	mov a,     8
	shr [bp + .da0], a	; Generate pitch (.da3), dropping width

	; Prepare and fill up Accelerator for the blit

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

	mov a,     [bp +  9]
	mov c,     [bp + 10]
	mov x0,    [bp + 11]
	mov x1,    [bp + 12]
	mov xm,    [bp + 13]
	rfn
