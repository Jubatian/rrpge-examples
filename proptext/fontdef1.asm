;
; Font definition for 1 bit fonts
;
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;
;
; Support functions for compact 1 bit fonts, to be used by the text libraries
; textblit.asm and textlgen.asm.
;
; 1 bit fonts are the easiest to work with since they don't have any alpha
; (they can't have any), and they may be colored easily even without using any
; reindexing. This package provides for a compact definition to expand an 1024
; word font definition from it, conserving some space in binaries.
;
; The font definition format, for 4 bit mode:
;
; Word0: bit  8-15: Height of font in lines (1 - 64 valid)
;        bit  0- 7: Pitch of font source in cells
; Word1: bit  8-15: First defined character
;        bit  0- 7: Number of defined characters
; Word2: Definition of undefined characters
;
; Then the defined character's definitions come, as many as requested.
;
; The character definitions:
;
; bit 14-15: Rotate (bit plane on which the character image is)
; bit  8-13: Character start offset in cells
; bit  6- 7: Character image width in cells -1 (1 - 4)
; bit  4- 5: Negative X position (0 - 3 pixels)
; bit  0- 3: Character effective width in pixels: img. width + 4 - this value
;
; For 8 bit mode the difference is in the character definitions as follows:
;
; bit 13-15: Rotate (bit plane on which the character image is)
; bit  8-12: Character start offset in cells
;
; The Negative X position and Character effective width is also interpreted in
; 8 bit pixel units instead of 4 bit pixel units.
;
; Interface function list
;
; fontdef1_m4
; fontdef1_m8
;


include "../rrpge.asm"

section code




;
; Converts a 4 bit mode font definition
;
; param0: Offset of source compact font definition
; param1: Offset of 1024 word target font definition
; param2: VRAM bank of the area where the font is loaded (0-3)
; param3: VRAM start offset of the area where the font is loaded
;
fontdef1_m4:

	mov sp,    15
	mov [bp + 6], a
	mov a,     fontdef1_common.fde4
	jmr fontdef1_common




;
; Converts a 8 bit mode font definition
;
; param0: Offset of source compact font definition
; param1: Offset of 1024 word target font definition
; param2: VRAM bank of the area where the font is loaded (0-3)
; param3: VRAM start offset of the area where the font is loaded
;
fontdef1_m8:

	mov sp,    15
	mov [bp + 6], a
	mov a,     fontdef1_common.fde8
	jmr fontdef1_common






;
; Common part for the fontdef1 functions. This is not an interface, neither an
; actual function! The fontdef_m4 and fontdef_m8 functions use this as common
; body after they set up the font definition expand routine to use. Excepts
; the decoder to use in register 'a', and 'sp' already set up to 15. Register
; 'a' must be saved at [bp + 6].
;
fontdef1_common:

.src	equ	0		; Offset of source compact font def
.dst	equ	1		; Offset of target font def
.vbk	equ	2		; VRAM bank of the font image
.vso	equ	3		; VRAM start offset of the font image
.fd0	equ	2		; Font definition word 0 base (reuses .vbk)
.fd1	equ	0		; Font definition word 1 base (reuses .src)
.ret	equ	4		; Return address for internal part
.ent	equ	5		; Entry point into the internal part

	; Save CPU regs

	mov [bp +  7], b
	mov [bp +  8], c
	mov [bp +  9], d
	mov [bp + 10], x0
	mov [bp + 11], x1
	mov [bp + 12], x2
	mov [bp + 13], x3
	mov [bp + 14], xm

	; Set decoder function

	mov [bp + .ent], a

	; Set up pointer modes:
	; xm0: PTR16I (0x6)
	; xm1: PTR16I (0x6)
	; xm2: PTR16I (0x6)
	; xm3: PTR16I (0x6)

	mov xm,    0x6666

	; Load font properties
	; Word2 of the font definition will be generated from .vso.
	; Word3 is always 0x0101 (1 bit font with colorkey set to 1).

	mov x3,    [bp + .src]
	mov a,     [x3]
	mov c,     a
	shr c,     8
	sub c,     1
	and c,     0x3F
	mov [bp + .fd1], c	; Font height
	mov c,     [bp + .vbk]
	shl c,     14
	or  [bp + .fd1], c	; VRAM bank of font image
	bts [bp + .fd1], 13	; Colorkey enabled
	shl a,     8
	mov [bp + .fd0], a	; Pitch of the font image area
	mov a,     [x3]		; First def. character; No. of chars
	mov c,     [x3]		; Undefined char's definition

	; Prepare undefined character's font definition entry

	mov x2,    .ufr
	mov [bp + .ret], x2
	jma [bp + .ent]
.ufr:

	; Fill up target with undefined character definition

	mov x2,    [bp + .dst]
	mov c,     1024
.ufl:	mov [x2],  x0
	mov [x2],  x1
	mov [x2],  b
	mov [x2],  d
	sub c,     1
	xeq c,     0
	jmr .ufl

	; Extract first character & no. of characters

	mov c,     a
	shr c,     8		; First defined character
	sub a,     1
	and a,     0xFF		; Count of characters (0 transforms to 256)
	add a,     1
	add a,     c
	xug 256,   a
	mov a,     256		; Limit to 256 characters (to fit in 1024 words)
	sub a,     c

	; Fill up defined characters

	mov x2,    .dfr
	mov [bp + .ret], x2
	mov x2,    [bp + .dst]
	shl c,     2
	add x2,    c		; First character's offset in the font def.
.dfl:	mov c,     [x3]
	jma [bp + .ent]
.dfr:	mov [x2],  x0
	mov [x2],  x1
	mov [x2],  b
	mov [x2],  d
	sub a,     1
	xeq a,     0
	jmr .dfl

	; Restore CPU regs & exit

	mov a,     [bp +  6]
	mov b,     [bp +  7]
	mov c,     [bp +  8]
	mov d,     [bp +  9]
	mov x0,    [bp + 10]
	mov x1,    [bp + 11]
	mov x2,    [bp + 12]
	mov x3,    [bp + 13]
	mov xm,    [bp + 14]
	rfn

	; Internal part to expand a compact font definition. Prepares into
	; x0, x1, b, and d. Register c is the source compact definition.
	; Returns to address in [bp + .ret]. Clobbers c.

.fde8:	mov x0,    [bp + .fd0]
	mov d,     c
	shr d,     6		; Width of font image in cells
	and d,     3
	or  x0,    d
	add d,     1
	shl d,     3		; Width of font image in 4 bit pixels
	mov b,     c
	and b,     0xF
	shl b,     1		; To 8 bit pixels
	sub d,     b
	add d,     8		; Effective width of character
	shl d,     3
	or  x0,    d		; Font definition word 0 complete
	mov x1,    [bp + .fd1]
	mov d,     c
	shr d,     13		; Rotate (bit plane) of char. image
	shl d,     10
	or  x1,    d
	mov d,     c
	and d,     0x0030	; Negative X position
	shl d,     3		; 8 bit pixel units (shl (2 + 1))
	shr c,     8
	and c,     0x1F
.fdee:	or  x1,    d
	mov b,     [bp + .vso]
	add b,     c		; Character start offset in VRAM
	mov d,     0x0101	; AND mask & Colorkey
	jma [bp + .ret]

	; Internal part to expand a compact font definition. Prepares into
	; x0, x1, b, and d. Register c is the source compact definition.
	; Returns to address in [bp + .ret]. Clobbers c.

.fde4:	mov x0,    [bp + .fd0]
	mov d,     c
	shr d,     6		; Width of font image in cells
	and d,     3
	or  x0,    d
	add d,     1
	shl d,     3		; Width of font image in pixels
	mov b,     c
	and b,     0xF
	sub d,     b
	add d,     4		; Effective width of character
	shl d,     3
	or  x0,    d		; Font definition word 0 complete
	mov x1,    [bp + .fd1]
	mov d,     c
	shr d,     14		; Rotate (bit plane) of char. image
	shl d,     10
	or  x1,    d
	mov d,     c
	and d,     0x0030	; Negative X position
	shl d,     2
	shr c,     8
	and c,     0x3F
	jmr .fdee
