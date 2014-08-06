;
; Text line layout generator
;
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;
;
; Builds a line layout for a text, which can be used to assist the render of
; this text as an index table.
;
; In the text source the following characters are interpreted:
;
; - 0x00: End of text.
;
; - 0x01 - 0x07: Set blit style. These are empty, zero width characters for
;   the purpose of calculating the layout. A render style applies to the
;   remaining characters of the (non-breakable) word in which it is found.
;
; - 0x0A: New line, causing a forced line break (otherwise text is
;   automatically broken down in lines as needed by the available space).
;
; - 0x0C - 0x0F: Set text render style (0x0C: left, 0x0D: right, 0x0E: center,
;   0x0F: justify). The style affects the line it occurs within.
;
; - 0x20: Space, interpreted as break between words. It's minimal width also
;   comes from the font definition.
;
; The font definition contains 256 entries, one for each character, defining
; how to render that character. It is formatted the following way:
;
; Word0: bit  8-15: Pitch (physical width) of the area in VRAM cells.
;        bit  3- 7: Effective width of the character (pixels).
;        bit  0- 2: Width of the area in VRAM cells - 1.
; Word1: bit 14-15: VRAM bank of the area.
;        bit    13: VCK (Colorkey enabled if set).
;        bit 10-12: Pixel barrel rotate right.
;        bit  6- 9: Negative X position (pixels).
;        bit  0- 5: Height of the area in lines - 1.
; Word2: VRAM offset where the tile / sprite starts.
; Word3: bit  8-15: Source AND mask.
;        bit  0- 7: Colorkey value.
;
; Of this here only the Effective width of the character and the Neative X
; position is used.
;
; The negative X position can be used to mark a character to begin closer to
; any previous character. It is only effective if the previous character is
; not white (that is, a rendered character).
;
; The generated line layout composes from the following records (a record
; describing one line of text):
;
; Word0: First character of the line (offset in the given text source)
; Word1: bit 14-15: Text render style (0: left, 1: right, 2: center, 3: just.)
;        bit  0-13: Number of characters belonging to the line
;
; Interface function list
;
; textlgen
;


include "../rrpge.asm"

section code



;
; Generate line layout for a given text.
;
; Using the passed text data and font, generates a stream of line layout
; records to be used later when rendering the text.
;
; Render style for a text initially is Justify.
;
; param0: Text to generate for, start offset
; param1: Font definition offset (1024 words)
; param2: Width in 4 bit pixels to generate for
; param3: Line layout record output start offset
; param4: Maximal number of records to generate (0: no practical limit)
; ret. A: Number of line layout records generated
;
textlgen:

.txo	equ	0		; Text to generate for, start offset
.fdo	equ	1		; Font definition offset
.wdt	equ	2		; Width in pixels to generate for
.ouo	equ	3		; Output offset
.max	equ	4		; Maximal number of records to generate
.flg	equ	5		; Control flag set
.nxr	equ	6		; Next render style
.wsw	equ	7		; Whitespace minimal width
.pro	equ	8		; Previous character offset
.prc	equ	3		; Previous character count (reuses output offset)

	; The control flag set:
	; bit 0: Set if it is the first word, clear otherwise
	; bit 1: Set if previous character was a white, clear otherwise

	mov sp,    17

	; Save CPU regs

	mov [bp +  9], b
	mov [bp + 10], c
	mov [bp + 11], d
	mov [bp + 12], xm
	mov [bp + 13], x2
	mov [bp + 14], x1
	mov [bp + 15], x0
	mov [bp + 16], xh

	; Set up pointer modes:
	; xm0: PTR16I (0x6)
	; xm1: PTR16I (0x6)
	; xm2: PTR8I  (0x8)
	; xm3: PTR16I (0x6)

	mov xm,    0x6866

	; Initialize

	mov c,     1
	shl c:[bp + .txo], c	; Also shift up start offset
	mov x2,    [bp + .txo]
	mov xh2,   c		; 8 bit start offset of text
	mov x1,    [bp + .ouo]
	mov a,     0xF		; Justify
	mov [bp + .nxr], a
	mov x0,    0x80		; 0x20 x 4 (space)
	add x0,    [bp + .fdo]
	mov a,     [x0]
	shr a,     3
	and a,     0x1F		; Width of character in pixels
	mov [bp + .wsw], a	; Whitespace minimal width

	; Algorithm for generating the layout data for a line. This basically
	; requires calculating the number of characters fitting on the line,
	; preferably split at word boundary (it might not be possible if a
	; word is too long to fit on the line).
	;
	; Word widths are calculated, when adding an another word, between
	; them, once the minimal whitespace width is calculated. A line
	; terminates when the next word does not fit in it, or if it is the
	; first word, at the character count fitting in.
	;
	; If the line terminates with a new line character, and the text is
	; to be justified, it will be left aligned instead. Otherwise the text
	; rendering style is left as-is.
	;
	; The first character of the word ignores the negative X position. For
	; all subsequent characters in the word, the negative X position is
	; applied normally (subtracting from the width).

	; Main generator loop. Register usage is as follows:
	; a: Line count
	; b: Work
	; c: Character count (current) on the line
	; d: Summed width (current) on the line
	; x0: Work (used to get character, and address font def.) PTR16I.
	; x1: Line layout output pointer. PTR16I.
	; x2: Current offset in text. PTR8I.
	; x3: Unused

	mov a,     0		; Line count starts at zero
.llp:	bts [bp + .flg], 0	; First word of line
	bts [bp + .flg], 1	; Previous character was white
	mov b,     x2
	sub b,     [bp + .txo]
	mov [x1],  b		; First entry of line layout record: start offset
	mov [bp + .pro], x2
	add a,     1		; Line count
	mov c,     0		; Character count on line
	mov [bp + .prc], c
	mov d,     0		; Summed width on line

	; Character fetch loop

.clp:	mov x0,    [x2]		; Get next character
	add c,     1		; Increment char. count

	; Check character to determine it's effect

	xne x0,    0x20
	jmr .spc		; To whitespace
	xug 0x10,  x0
	jmr .ch0		; To normal character (x0 >= 0x10)
	xne x0,    0x0A
	jmr .nln		; To new line
	xne x0,    0
	jmr .eot		; To end of text
	xbs x0,    3
	jmr .nch		; To set blit style (ignored, proceeds to next char)
	xbc x0,    2
	jmr .srs		; To set text render style

	; Normal character

	; Retrieve the width of the character x0, with negative X position
	; applied unless previous character was a white.

.ch0:	shl x0,    2		; To offset in font definition
	add x0,    [bp + .fdo]
	mov b,     [x0]
	shr b,     3
	and b,     0x1F		; Width of character in pixels
	mov x0,    [x0]
	shr x0,    6
	and x0,    0x0F		; Negative width to apply
	xbs [bp + .flg], 1
	sub b,     x0		; Apply negative width unless after a white
	btc [bp + .flg], 1	; Clear "previous character was white"

	; Add to width, and check for width overrun

	add d,     b
	xug d,     [bp + .wdt]
	jmr .nch		; Width not overran yet
	mov b,     [bp + .nxr]
	jmr .wov		; Width overran: terminate the record

	; Set text render style

.srs:	mov [bp + .nxr], x0	; Render styles: C/D/E/F (left/right/center/just)
	jmr .nch		; To next character

	; Whitespace within a line. This starts a new word, saving the last
	; word's end situation. Witespace minimal width is calculated towards
	; the new word (as that requires it). If previous character was a
	; white, then does nothing.

.spc:	xbc [bp + .flg], 1
	jmr .nch		; Previous was a white - do nothing (to next char)
	btc [bp + .flg], 0	; Not the first word any more
	bts [bp + .flg], 1	; Previous character was a white set
	mov [bp + .pro], x2	; Previous char. offset saved (in case next word will overrun)
	mov [bp + .prc], c	; Previous char. count saved
	add d,     [bp + .wsw]	; Whitespace minimal width added
				; (Note: no width overrun test, line may terminate with whites)

	; To next character. Set blit style also redirects here as there is
	; no processing here for it.

.nch:	xbs [bp + .flg], 0	; First word?
	jmr .clp
	mov [bp + .pro], x2	; If so, update the char count & offset, so
	mov [bp + .prc], c	; a word break happens after a width overrun
	jmr .clp		; To next character loop

	; New line or end of text. If reached this point, it means the width
	; was never overran. In the case of justify render style, it has to be
	; reverted to left aligned.

.eot:	mov [bp + .max], a	; Set line count limit to this line
.nln:	mov b,     [bp + .nxr]
	xne b,     0xF		; Justify?
	mov b,     0xC		; Revert to left align (for this line only)
	mov [bp + .pro], x2	; No width overflow, so previous offset and count may update
	mov [bp + .prc], c

	; Generate line layout record second entry. If x0 is zero, or the
	; record count is exhausted, exit here. Excepts text render style in
	; register 'b'.

.wov:	shl b,     14		; Text render style: only low 2 bits will have effect
	or  b,     [bp + .prc]
	mov [x1],  b		; Save text render style and character count
	mov x2,    [bp + .pro]	; Revert offset to last fitting word's
	xeq a,     [bp + .max]
	jmr .llp		; To next line loop

	; Restore CPU regs & exit

	mov b,     [bp +  9]
	mov c,     [bp + 10]
	mov d,     [bp + 11]
	mov xm,    [bp + 12]
	mov x2,    [bp + 13]
	mov x1,    [bp + 14]
	mov x0,    [bp + 15]
	mov xh,    [bp + 16]
	rfn
