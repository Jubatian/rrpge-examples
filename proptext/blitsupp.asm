;
; Block Blitter support functions
;
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;
;
; Excepts CPU page 1 being the User Peripheral Page.
;
; Interface function list
;
; blitsupp_reset
; blitsupp_setrei
; blitsupp_fillrei
; blitsupp_setdest
;


include "../rrpge.asm"

section code



;
; Resets the Accelerator for block blitting
;
; Initializes Accelerator registers 0x004 - 0x00B for the most common blits.
; These are all bits enabled by the VRAM write mask, zero for the bank &
; partition selects, all partitioning turned off, Y disabled by the X/Y split
; (so only Source X is effective), no substitutions, no source barrel
; rotating, no source masking (OR mask zero, AND mask all set).
;
blitsupp_reset:

	mov sp,    1
	mov [bp + 0], a

	mov a,     0x004
	mov [0x1E02], a
	mov a,     0xFFFF
	mov [0x1E03], a		; VRAM Write mask high
	mov [0x1E03], a		; VRAM Write mask low
	mov a,     0
	mov [0x1E03], a		; Source bank & partition
	mov [0x1E03], a		; Destination bank & partition
	mov a,     0xFFF0
	mov [0x1E03], a		; Partitioning settings
	mov a,     0
	mov [0x1E03], a		; Substitution & source barrel rotate
	mov a,     0xFF00
	mov [0x1E03], a		; Source AND mask & Colorkey
	mov a,     0
	mov [0x1E03], a		; Reindex bank select

	mov a,     [bp + 0]
	rfn




;
; Sets up a reindex bank
;
; Sets up the 16 reindex values in a given reindex bank. The source offset
; must point to 16 reindex byte (8 bit) values (so 8 words).
;
; param0: Target reindex bank to fill in (only low 5 bits used)
; param1: Reindex value source offset (8 words)
;
blitsupp_setrei:

	mov sp,    3

	; Save CPU regs (some xch to load parameters the same time)

	xch [bp + 0], a
	xch [bp + 1], x3
	mov [bp + 2], xm

	; Transfer

	and a,     0x1F
	shl a,     3
	bts a,     8		; Start offset of the reindex bank in Accelerator
	mov xm3,   PTR16I
	mov [0x1E02], a
	mov a,     [x3]		; Transfer 8 words
	mov [0x1E03], a
	mov a,     [x3]
	mov [0x1E03], a
	mov a,     [x3]
	mov [0x1E03], a
	mov a,     [x3]
	mov [0x1E03], a
	mov a,     [x3]
	mov [0x1E03], a
	mov a,     [x3]
	mov [0x1E03], a
	mov a,     [x3]
	mov [0x1E03], a
	mov a,     [x3]
	mov [0x1E03], a

	; Restore CPU regs & exit

	mov a,     [bp + 0]
	mov x3,    [bp + 1]
	mov xm,    [bp + 2]
	rfn




;
; Sets up a portion of the reindex table
;
; Sets up part of the reindex table from the beginning. Typically may be used
; to fill the first 16 banks for 4 bit mode by destination reindexing, or all
; 32 banks for 8 bit mode, or in general for initializing the entire table.
; One reindex bank takes 8 words.
;
; param0: Reindex value source offset (8 x banks words)
; param1: Number of banks to fill (low 5 bits used, 0 interpreted as 32)
;
blitsupp_fillrei:

	mov sp,    5

	; Save CPU regs (some xch to load parameters the same time)

	xch [bp + 0], x3
	xch [bp + 1], c
	mov [bp + 2], a
	mov [bp + 3], x0
	mov [bp + 4], xm

	; Transfer

	mov xm3,   PTR16I
	mov xm0,   PTR16
	mov x0,    0x1E03	; Data word for Graphics FIFO
	mov a,     0x100	; First reindex entry
	mov [0x1E02], a
	sub c,     1
	and c,     0x1F		; Low 5 bits used of the number of banks to fill
	add c,     1		; 1 - 32 to fill
	shl c,     3		; Make it number of banks
	add c,     x3		; Termination point for the loop
.lp:	mov a,     [x3]		; Transfer 8 words (one bank) / iteration
	mov [x0],  a
	mov a,     [x3]
	mov [x0],  a
	mov a,     [x3]
	mov [x0],  a
	mov a,     [x3]
	mov [x0],  a
	mov a,     [x3]
	mov [x0],  a
	mov a,     [x3]
	mov [x0],  a
	mov a,     [x3]
	mov [x0],  a
	mov a,     [x3]
	mov [x0],  a
	xeq x3,    c
	jmr .lp

	; Restore CPU regs & exit

	mov x3,    [bp + 0]
	mov c,     [bp + 1]
	mov a,     [bp + 2]
	mov x0,    [bp + 3]
	mov xm,    [bp + 4]
	rfn




;
; Sets up destination for blitting
;
; Prepares the destination, setting it's bank & partition select and partition
; size (register 0x007 and 0x008), it's increments (registers 0x01E and 0x01F)
; and other permanent registers (0x017, 0x019, 0x01B: source fractions)
;
; param0: Destination pitch
; param1: Destination bank & partition select (as for 0x007)
; param2: Destination partitioning (0: 4 Words - 15: 128 Kwords)
;
blitsupp_setdest:

	mov sp,    4

	xch [bp + 0], a
	xch [bp + 1], b
	xch [bp + 2], d
	mov [bp + 3], c

	mov c,     0x007
	mov [0x1E02], c
	mov [0x1E03], b		; Destination bank
	and d,     0xF
	shl d,     4
	or  d,     0xFF00	; Partitioning settings
	mov [0x1E03], d

	mov c,     0x01E
	mov [0x1E02], c
	mov c,     1
	mov [0x1E03], c		; Destination increment
	mov [0x1E03], a		; Destination post-add

	mov c,     0x017
	mov [0x1E02], c
	mov a,     0
	mov [0x1E03], a		; Source X fraction
	add c,     2
	mov [0x1E02], c
	mov [0x1E03], a		; Source X increment fraction
	add c,     2
	mov [0x1E02], c
	mov [0x1E03], a		; Source X post-add fraction

	mov a,     [bp + 0]
	mov b,     [bp + 1]
	mov d,     [bp + 2]
	mov c,     [bp + 3]
	rfn
