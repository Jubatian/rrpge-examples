;
; Generic copy
;
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;
;
; Generic any to any copy, using DMA if possible.
;
; Excepts CPU page 1 being the User Peripheral Page, and page 0 being the
; ROPD.
;


include "../rrpge.asm"

section code


;
; Generic copy between any two locations.
;
; Copies between any two locations, any number of words, without changing the
; CPU page layout. Attempts to use DMA if the addresses suggest that. The page
; selectors can be used to specify the type of address:
;
; - 0x4000 - 0x41BF: CPU RAM pages (only low 12 bits of offset are effective)
; - 0x41C0:          ROPD (only low 12 bits of offset are effective)
; - 0x8000 - 0x807F: VRAM pages (only low 12 bits of offset are effective)
; - 0x0400 - 0x041B: CPU RAM pages (as high part with a 16 bit offset)
; - 0x041C:          ROPD (as high part with a 16 bit offset)
; - 0x0800 - 0x0807: VRAM pages (as high part with a 16 bit offset)
; - 0x0000 - 0x000F: Pages within CPU address space (offset is 16 bits)
;
; The offset part is interpreted as 12 or 16 bits depending on the style of
; page selection. Note that in the case of using the CPU address space, the
; offset is translated to CPU page first, before fetching the actual memory
; page used. If the copy spans multiple pages, these pages are always walked
; incrementally.
;
; Note that no ranges are checked! Invalid parameters likely result in a
; kernel trap.
;
; In the case of a Video RAM destination the write masks should be set all
; ones to produce consistent results (DMA ignores the write mask while plain
; copy does not). VRAM <=> VRAM copies are not accelerated.
;
; param0: Source page selector
; param1: Source offset
; param2: Destination page selector
; param3: Destination offset
; param4: Number of words to copy, high
; param5: Number of words to copy, low
;
copy:

.spg	equ	0		; Source page select
.sof	equ	1		; Source offset
.dpg	equ	2		; Destination page select
.dof	equ	3		; Destination offset
.cnh	equ	4		; Count of words to copy, high
.cnl	equ	5		; Count of words to copy, low
.rpe	equ	6		; Read page 0xE
.wpe	equ	7		; Write page 0xE
.rpf	equ	8		; Read page 0xF
.wpf	equ	9		; Write page 0xF

	mov sp,    19		; Reserve some space on the stack

	; Save CPU registers

	mov [bp + 10], xm
	mov [bp + 11], x3
	mov xm3,   PTR16I
	mov x3,    12
	mov [bp + x3], x2
	mov [bp + x3], x1
	mov [bp + x3], x0
	mov [bp + x3], a
	mov [bp + x3], b
	mov [bp + x3], c
	mov [bp + x3], d
	mov xm2,   PTR16I

	; If CPU pages are selected, convert them to real pages

	mov x3,    [bp + .spg]
	xug 0x10,  x3
	jmr .snc		; Not a CPU page
	shl x3,    12
	add x3,    [bp + .sof]	; CPU offset, now select page for it
	shr x3,    12
	add x3,    ROPD_RBK_0
	mov a,     [x3]		; OK, source page acquired
	mov [bp + .spg], a
	mov a,     0x0FFF
	and [bp + .sof], a	; Also limit start offset within the page
.snc:	mov x3,    [bp + .dpg]
	xug 0x10,  x3
	jmr .dnc		; Not a CPU page
	shl x3,    12
	add x3,    [bp + .dof]	; CPU offset, now select page for it
	shr x3,    12
	add x3,    ROPD_WBK_0
	mov a,     [x3]		; OK, destination page acquired
	mov [bp + .dpg], a
	mov a,     0x0FFF
	and [bp + .dof], a	; Also limit start offset within the page
.dnc:

	; Determine if DMA based copy is possible or not. It is done in a
	; simple manner only giving DMA if the offset and the length matches
	; for a full DMA copy.

	mov c,     1		; DMA possible? (Set if so)
	mov a,     [bp + .sof]
	and a,     0xFF
	xeq a,     0
	mov c,     0		; Source offset not a 256 word page
	mov a,     [bp + .dof]
	and a,     0xFF
	xeq a,     0
	mov c,     0		; Destination offset not a 256 word page
	mov a,     [bp + .cnl]
	and a,     0xFF
	xeq a,     0
	mov c,     0		; Not a 256 word multiple to copy
	mov a,     [bp + .spg]
	xne a,     0x41C0
	mov c,     0		; Source is the ROPD
	xne a,     0x041C
	mov c,     0		; Source is the ROPD
	xeq c,     1
	jmr .slow		; Slow plain copy (no DMA possible)

	; Convert pages for DMA, to high part of offset form

	mov a,     [bp + .spg]
	xug a,     0x0FFF
	jmr .nds
	shl a,     12
	add [bp + .sof], a
	mov a,     [bp + .spg]
	shr a,     4
.nds:	mov b,     [bp + .dpg]
	xug b,     0x0FFF
	jmr .ndd
	shl b,     12
	add [bp + .dof], b
	mov b,     [bp + .dpg]
	shr b,     4
.ndd:

	; Calculate DMA start offsets & copy counts ('a' and 'b' holding the
	; source & destination pages shift right by 8)

	mov x0,    [bp + .sof]
	shr c:a,   8
	src x0,    8		; DMA start offset, source
	mov x1,    [bp + .dof]
	shr c:b,   8
	src x1,    8		; DMA start offset, destination
	mov c,     [bp + .cnh]
	mov d,     [bp + .cnl]
	shr c:c,   8
	src d,     8		; DMA count of 256 word blocks to copy

	; Diverge for the 3 possible DMA variations: CPU <=> CPU, CPU => VRAM
	; and VRAM => CPU (VRAM <=> VRAM will fall back to slow copy).

	xug 0x08,  a
	jmr .vsr		; VRAM source
	xug 0x08,  b
	jmr .vds		; CPU RAM source, VRAM destination

	; CPU <=> CPU copy

.ccc:	mov [0x1F00], x0	; DMA source
	mov [0x1F02], x1	; DMA destination, CPU <=> CPU start
	add x0,    1
	add x1,    1
	sub d,     1
	xeq d,     0
	jmr .ccc
	jmr .exit

.vsr:	; VRAM => CPU copy. But first check destination, fall back if VRAM
	; CPU => VRAM also here, just enter into the loop.

	xug 0x08,  b
	jmr .slow		; VRAM <=> VRAM: Slow copy
	bts x1,    15		; Set VRAM => CPU direction
.vds:	mov [0x1F00], x0	; DMA source
	mov [0x1F03], x1	; DMA destination, CPU <=> VRAM start
	add x0,    1
	add x1,    1
	sub d,     1
	xeq d,     0
	jmr .vds
	jmr .exit

.slow:	; Plain slow copy using the CPU. Needs to use CPU pages, in general
	; being careful to work in any configuration.

	mov a,     [ROPD_RBK_14]
	mov [bp + .rpe], a
	mov a,     [ROPD_WBK_14]
	mov [bp + .wpe], a
	mov a,     [ROPD_RBK_15]
	mov [bp + .rpf], a
	mov a,     [ROPD_WBK_15]
	mov [bp + .wpf], a
	jsv {kc_mem_bankwr, 14, 0x4000}	; Neutral page (if 14 was VRAM)

	; CPU page 14 will be the source, page 15 the destination. This is an
	; arbitrary copy, pages may need to be switched after any word, the
	; source and the destination asynchronously at that.

	; Convert pages for page:offset format (12 bit offset)

	mov a,     [bp + .spg]
	xug 0x1000, a
	jmr .nss
	mov c,     [bp + .sof]
	shr c,     12
	slc a,     4
.nss:	mov b,     [bp + .dpg]
	xug 0x1000, b
	jmr .nsd
	mov c,     [bp + .dof]
	shr c,     12
	slc b,     4
.nsd:

	; Calculate initial offsets, setting up pointers for the copy

	mov x2,    [bp + .sof]
	and x2,    0x0FFF
	or  x2,    0xE000
	mov x3,    [bp + .dof]
	and x3,    0x0FFF
	or  x3,    0xF000

	; Load count

	mov x0,    [bp + .cnh]
	mov x1,    [bp + .cnl]
	add c:x1,  0xFFFF
	adc x0,    0		; End of loop when x0 decrements to zero

	; Bank in initial pages

	jsv {kc_mem_bankrd,   14, a}	; Source
	jsv {kc_mem_banksame, 15, b}	; Destination
	jmr .cl3

	; Perform the copy

.cl0:	mov x2,    0xE000	; Source page step
	add a,     1
	jsv {kc_mem_bankrd,   14, a}	; Source
	jmr .cl1
.cl2:	mov x3,    0xF000	; Destination page step
	add b,     1
	jsv {kc_mem_banksame, 15, b}	; Destination
	jmr .cl3
.clw:	xbc x2,    12		; Remained clear - no source wrap
	jmr .cl0
.cl1:	xbs x3,    12		; Remained set - no destination wrap
	jmr .cl2
.cl3:	xug x1,    0xE		; Check for fast block possibility
	jmr .clp
	xug 0xEFF1, x2
	jmr .clp
	xug 0xFFF1, x3
	jmr .clp
	sub x1,    15		; Pre-subtract the 15 extra copies (no wrap to high part here)
	mov c,     [x2]
	mov [x3],  c
	mov c,     [x2]
	mov [x3],  c
	mov c,     [x2]
	mov [x3],  c
	mov c,     [x2]
	mov [x3],  c
	mov c,     [x2]
	mov [x3],  c
	mov c,     [x2]
	mov [x3],  c
	mov c,     [x2]
	mov [x3],  c
	mov c,     [x2]
	mov [x3],  c
	mov c,     [x2]
	mov [x3],  c
	mov c,     [x2]
	mov [x3],  c
	mov c,     [x2]
	mov [x3],  c
	mov c,     [x2]
	mov [x3],  c
	mov c,     [x2]
	mov [x3],  c
	mov c,     [x2]
	mov [x3],  c
	mov c,     [x2]
	mov [x3],  c
.clp:	mov c,     [x2]
	mov [x3],  c
	sub c:x1,  1
	sbc x0,    0
	xeq x0,    0
	jmr .clw

	; Exit slow copy: Restore stuff

	jsv {kc_mem_bank, 14, [bp + .rpe], [bp + .wpe]}
	jsv {kc_mem_bank, 15, [bp + .rpf], [bp + .wpf]}

.exit:	; Restore CPU registers & exit

	mov xm3,   PTR16D
	mov x3,    19
	mov d,     [bp + x3]
	mov c,     [bp + x3]
	mov b,     [bp + x3]
	mov a,     [bp + x3]
	mov x0,    [bp + x3]
	mov x1,    [bp + x3]
	mov x2,    [bp + x3]
	mov x3,    [bp + x3]
	mov xm,    [bp + 10]
	rfn
