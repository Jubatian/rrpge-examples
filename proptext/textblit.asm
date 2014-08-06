;
; Text blitter
;
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;
;
; Generates text output using a 256 element font definition, and optionally a
; line layout (may be prepared using textlgen.asm).
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
; Render styles are simply blit definitions to be passed to the blitter. Even
; the mirroring settings may be used.
;
; Character codes not listed here act as normal characters. While it is
; possible to use ASCII, it is not mandatory: the layout of the characters can
; be arbitrary as far as the above codes are respected (so there are 242
; arbitrary characters).
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
; This is basically a source area definition with specifics added for
; characters. Character images may be up to 64x64 in size (4 bit pixels),
; their effective width may range from 0-31, and their negative X position may
; range from 0-15.
;
; The negative X position can be used to mark a character to begin closer to
; any previous character. It is only effective if the previous character is
; not white (that is, a rendered character).
;
; Interface function list
;
; textblit
; textblit_block
;


include "../rrpge.asm"

section code



;
; Outputs a single line of text to the given destination.
;
; The text output is generated according to the passed destination width and
; start position, however fitting is not guaranteed, the text may "spill".
;
; Text render styles:
;
; 0: Left aligned
; 1: Right aligned
; 2: Centered
; 3: Justified
;
; Destination constraints:
;
; bit 13-15: Pixel start offset on destination (0-7)
; bit  0-12: Width of area to place text on
;
; param0: Text to render, start offset
; param1: First character of the text to render (8 bit offset)
; param2: bits 14-15: text render style, bits 0-13: number of characters
; param3: Font definition offset (1024 words)
; param4: Blit styles (8 words, first is the base style)
; param5: Destination area definition, 0
; param6: Destination area definition, 1
; param7: Destination area definition, 2
; param8: Destination constraints
; param9: Y position
; param10: Blitter function to use (for example blit in blit.asm)
;
textblit:

.txo	equ	0		; Text to generate for, start offset
.ly0	equ	1		; First char of text to render (line layout #0)
.ly1	equ	2		; Text render style & number of characters (l.l. #1)
.fdo	equ	3		; Font definition offset
.bso	equ	4		; Blit styles offset
.da0	equ	5		; Destination area def. 0
.da1	equ	6		; Destination area def. 1
.da2	equ	7		; Destination area def. 2
.dco	equ	8		; Destination constraints
.yps	equ	9		; Y position
.blt	equ	10		; Blitter function
.eto	equ	11		; End of string offset
.flg	equ	12		; Control flag set
.rwd	equ	13		; Remaining width (justify)
.wsw	equ	14		; Whitespace minimal width

	mov sp,    256		; Also allocate for a 224 word data area

	; Save CPU regs

	mov [bp + 15], xm
	mov [bp + 16], x3
	mov xm3,   PTR16I
	mov x3,    17
	mov [bp + x3], a
	mov [bp + x3], b
	mov [bp + x3], c
	mov [bp + x3], d
	mov [bp + x3], x0
	mov [bp + x3], x1
	mov [bp + x3], x2
	mov [bp + x3], xh

	; Algorithm for outputting text. First the minimal width of the text
	; has to be calculated. Then subtracting it from the available width
	; (if it fits) the number of pixels available for positioning can be
	; acquired. Then the rendering itself may proceed on two branches: for
	; non-justified text it is a simple straightforward render, for
	; justified text after each word the remaining extra space has to be
	; divided up, and the appropriate fraction has to be added to the
	; whitespace between words.
	;
	; To increase efficiency, the stack is used as temporary storage for
	; preparing characters to render. A word array is placed on the stack
	; containing position deltas after every character, so position does
	; not need to be re-calculated for the render.

	; Set up pointer modes:
	; xm0: PTR16I (0x6)
	; xm1: PTR16I (0x6)
	; xm2: PTR8I  (0x8)
	; xm3: PTR16I (0x6)

	mov xm,    0x6866

	; Initialize

	mov x2,    [bp + .txo]
	shl c:x2,  1		; To 8 bit offset
	mov a,     c
	add c:x2,  [bp + .ly0]	; Start character offset
	adc a,     0
	mov xh2,   a
	mov c,     [bp + .ly1]
	and c,     0x3FFF
	xne c,     0
	jmr .exit		; Nothing to output
	xug 224,   c		; 224 words on stack, so maximize at this
	mov c,     224
	add c,     x2		; Make terminating offset
	mov [bp + .eto], c
	mov x0,    0x80		; 0x20 x 4 (space)
	add x0,    [bp + .fdo]
	mov a,     [x0]
	shr a,     3
	and a,     0x1F		; Width of character in pixels
	mov [bp + .wsw], a	; Whitespace minimal width

	; Width calculation & stack fill loop. Register usage is as follows:
	; a: Work (mostly delta for stack fill)
	; b: Whitespace count between words (used for justifying)
	; c: Unused
	; d: Summed width (current) on the line
	; x0: Work (used to get character, and address font def.) PTR16I.
	; x1: Unused
	; x2: Current offset in text. PTR8I.
	; x3: Stack delta fill pointer. PTR16I.

	bts [bp + .flg], 1	; Previous character was white
	mov d,     0		; Summed width on line
	mov b,     0		; Whitespace count between words
	mov x3,    32		; Start location in stack

	; Character fetch loop

.clp:	mov x0,    [x2]		; Get next character
	mov a,     0		; Prepare zero width for ignored chars

	; Check character to determine it's effect

	xne x0,    0x20
	jmr .spc		; Space
	xug 0x10,  x0
	jmr .ch0		; Normal character
	xne x0,    0xA
	jmr .spc		; New line ignored, just a space
	xne x0,    0
	jmr .eot		; To end of text
	xbs x0,    3
	jmr .nch		; To set blit style (ignored)
	xbc x0,    2
	jmr .nch		; To set text render style (ignored)
	jmr .ch0		; Normal character otherwise

	; Whitespace within a line. This starts a new word, saving the last
	; word's end situation. Witespace minimal width is calculated towards
	; the new word (as that requires it). If previous character was a
	; white, then does nothing.

.spc:	xbc [bp + .flg], 1
	jmr .nch		; Already acknowledged a whitespace
	mov a,     [bp + .wsw]	; Whitespace minimal width for first space of a group
	add b,     1		; One extra whitespace
	bts [bp + .flg], 1	; Previous character was a white set
	jmr .nch

	; End of text. Update termination condition to match.

.eot:	mov [bp + .eto], x2
	jmr .nch

	; Normal character

	; Retrieve the width of the character x0, with negative X position
	; applied unless previous character was a white.

.ch0:	shl x0,    2		; To offset in font definition
	add x0,    [bp + .fdo]
	mov a,     [x0]
	shr a,     3
	and a,     0x1F		; Width of character in pixels
	mov x0,    [x0]
	shr x0,    6
	and x0,    0x0F		; Negative width to apply
	xbs [bp + .flg], 1
	sub a,     x0		; Apply negative width unless after a white
	btc [bp + .flg], 1	; Clear "previous character was white"

	; To next character.

.nch:	add d,     a
	mov [bp + x3], a	; Save delta on stack for this character
	xeq x2,    [bp + .eto]	; End of string?
	jmr .clp		; If not, go on fetching characters

	; Remove trailing whites if necessary. This will get a negative if the
	; line was empty, but don't care as then nothing will render.

	xbc [bp + .flg], 1	; Last was white?
	sub d,     [bp + .wsw]
	xbc [bp + .flg], 1
	sub b,     1
	xbc b,     15
	jmr .exit		; Negative count of whites: indicates it was empty

	; Re-initialize text start

	mov x2,    [bp + .txo]
	shl c:x2,  1		; To 8 bit offset
	mov a,     c
	add c:x2,  [bp + .ly0]	; Start character offset
	adc a,     0
	mov xh2,   a

	; Using the width and the text render style, calculate start offset on
	; destination, and pass the remaining width for justified text.

	mov a,     [bp + .dco]
	and a,     0x1FFF	; Width for the string
	sub a,     d		; Extra width to distribute
	mov d,     a
	mov a,     [bp + .dco]
	shr a,     13		; Start X offset on destination
	mov c,     [bp + .ly1]
	shr c,     14		; Text render style
	xne c,     1
	add a,     d		; Right alignment: add all extra width
	mov x3,    d
	shr x3,    1
	xne c,     2
	add a,     x3		; Centered: add half of the extra width

	; Further inits for the render

	mov x3,    32		; Start location in stack for deltas
	mov [bp + .rwd], d	; Remaining width for justifying
	mov d,     a		; X position for next character
	mov x0,    [bp + .bso]

	; Branch off: justified or non-justified blit

	xne c,     3
	jmr .jst		; To justified text

	; Non-justified text render loop. Register usage is as follows:
	; a: Work
	; b: Unused (whitespaces generated for justify)
	; c: Current blit control flags
	; d: Position for next character
	; x0: Work (used for font def) PTR16I.
	; x1: Work (also used for blit control flags) PTR16I.
	; x2: Current offset in text. PTR8I.
	; x3: Stack delta read pointer. PTR16I.

	mov c,     [x0]

	; Character fetch loop

.tclp:	mov x0,    [x2]		; Get next character

	; Check character to determine it's effect

	xne x0,    0x20
	jmr .tspc		; Space
	xug 0x10,  x0
	jmr .tch0		; Normal character
	xne x0,    0xA
	jmr .tspc		; New line ignored, just a space
	xbs x0,    3
	jmr .tbst		; Blit style select
	xbc x0,    2
	jmr .tnch		; Text render style (0xC - 0xF) ignored
	jmr .tch0		; Normal character otherwise

	; Whitespace within a line. This clears the blit control flags to the
	; defaults, and no render happens.

.tspc:	mov x1,    [bp + .bso]
	mov c,     [x1]
	jmr .tnch

	; Blit control flag set

.tbst:	mov x1,    [bp + .bso]
	add x1,    x0
	mov c,     [x1]
	jmr .tnch

	; Normal character

.tch0:	jfa blit_src64 {x0, [bp + .fdo], c, [bp + .da0], [bp + .da1], [bp + .da2], d, [bp + .yps], [bp + .blt]}

	; To next character.

.tnch:	add d,     [bp + x3]	; Add delta
	xeq x2,    [bp + .eto]	; End of string?
	jmr .tclp		; If not, go on fetching characters
	jmr .exit

	; Justified text render loop. Register usage is as follows:
	; a: Work
	; b: Remaining whitespace count
	; c: Current blit control flags
	; d: Position for next character
	; x0: Work (used for font def) PTR16I.
	; x1: Work (also used for blit control flags) PTR16I.
	; x2: Current offset in text. PTR8I.
	; x3: Stack delta read pointer. PTR16I.

.jst:	mov c,     [x0]

	; Character fetch loop

.jclp:	mov x0,    [x2]		; Get next character

	; Check character to determine it's effect

	xne x0,    0x20
	jmr .jspc		; Space
	xug 0x10,  x0
	jmr .jch0		; Normal character
	xne x0,    0xA
	jmr .jspc		; New line ignored, just a space
	xbs x0,    3
	jmr .jbst		; Blit style select
	xbc x0,    2
	jmr .jnch		; Text render style (0xC - 0xF) ignored
	jmr .jch0		; Normal character otherwise

	; Whitespace within a line. This clears the blit control flags to the
	; defaults, and no render happens. Also here is the main part of
	; justifying: if the delta is nonzero, then assume it is the case of a
	; new whitespace (this is the case since in every whitespace block
	; only the first gets a nonzero delta), and calculate the share of
	; remaining width for it.

.jspc:	mov x1,    [bp + .bso]
	mov c,     [x1]
	mov a,     [bp + x3]
	xne a,     0
	jmr .jncd		; Zero delta, nothing to do
	xne b,     0
	jmr .exit		; Trailing whites, no need to render any more
	add d,     a		; Add the whitespace's width from delta
	mov a,     [bp + .rwd]
	div a,     b		; Divide remaining width between remaining spaces
	add d,     a		; Add the share for this space
	sub [bp + .rwd], a	; Remove it from the remaining width
	sub b,     1		; One less whitespaces to go
	jmr .jncd

	; Blit control flag set

.jbst:	mov x1,    [bp + .bso]
	add x1,    x0
	mov c,     [x1]
	jmr .jnch

	; Normal character

.jch0:	jfa blit_src64 {x0, [bp + .fdo], c, [bp + .da0], [bp + .da1], [bp + .da2], d, [bp + .yps], [bp + .blt]}

	; To next character.

.jnch:	add d,     [bp + x3]	; Add delta
.jncd:	xeq x2,    [bp + .eto]	; End of string?
	jmr .jclp		; If not, go on fetching characters

	; Restore CPU regs & exit

.exit:	mov xm3,   PTR16D
	mov x3,    25
	mov xh,    [bp + x3]
	mov x2,    [bp + x3]
	mov x1,    [bp + x3]
	mov x0,    [bp + x3]
	mov d,     [bp + x3]
	mov c,     [bp + x3]
	mov b,     [bp + x3]
	mov a,     [bp + x3]
	mov x3,    [bp + x3]
	mov xm,    [bp + 15]
	rfn





;
; Outputs a block of text (multiple lines) to the given destination.
;
; Uses textblit to produce multiple lines of text from a line layout. The
; line layout records have 2 words each, first for param1, then param2 of the
; textblit function.
;
; param0: Text to render, start offset
; param1: Line layout start offset
; param2: Line height
; param3: Count of lines to render
; param4: Font definition offset (1024 words)
; param5: Blit styles (8 words, first is the base style)
; param6: Destination area definition, 0
; param7: Destination area definition, 1
; param8: Destination area definition, 2
; param9: Destination constraints
; param10: Start Y position
; param11: Blitter function to use (for example blit in blit.asm)
;
textblit_block:

.txo	equ	0		; Text to generate for, start offset
.lyo	equ	1		; Line layout start offset
.lhg	equ	2		; Line height
.lco	equ	3		; Count of lines to render
.fdo	equ	4		; Font definition offset
.bso	equ	5		; Blit styles offset
.da0	equ	6		; Destination area def. 0
.da1	equ	7		; Destination area def. 1
.da2	equ	8		; Destination area def. 2
.dco	equ	9		; Destination constraints
.yps	equ	10		; Y position
.blt	equ	11		; Blitter function

	mov sp,    16

	; Save CPU regs

	mov [bp + 12], a
	mov [bp + 13], c
	mov [bp + 14], x3
	mov [bp + 15], xm

	; Walk the line layout, and render each text line

	mov xm3,   PTR16I
	mov x3,    [bp + .lyo]
	mov c,     [bp + .lco]
	mov a,     [bp + .yps]
.lp:	xne c,     0
	jmr .exit
	jfa textblit {[bp + .txo], [x3], [x3], [bp + .fdo], [bp + .bso], [bp + .da0], [bp + .da1], [bp + .da2], [bp + .dco], a, [bp + .blt]}
	add a,     [bp + .lhg]
	sub c,     1
	jmr .lp

	; Restore CPU regs & exit

.exit:	mov a,     [bp + 12]
	mov c,     [bp + 13]
	mov x3,    [bp + 14]
	mov xm,    [bp + 15]
	rfn
