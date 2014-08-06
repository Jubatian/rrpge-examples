;
; Accelerator and Text output
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;
;
; Introduces a small proportional text output library demonstrating some uses
; of the Accelerator.
;


include "../rrpge.asm"
bindata "font16pd.bin" h, 0x300
bindata "font16pi.bin" h, 0x380

section cons

	db "RPA\n"
	db "\nAppAuth: Jubatian        "
	db "\nAppName: Example program: Proportional text"
	db "\nVersion: 00.000.000"
	db "\nEngSpec: 00.009.001"
	db "\nLicense: RRPGEv2\n\n"
	db 0

	; Blit styles for the text. Just specifies colors:
	; Default is bright gray
	; 1: White
	; 2: Green
	; 3: Red
	; 4: Bright yellow
	; 5: Yellow
	; 6: Bright blue
	; 7: Brown

blits:	dw 0x0040, 0x00C0, 0x0140, 0x0180, 0x01C0, 0x02C0, 0x0300, 0x03C0

	; Output text. Note that 'db' pads to word boundary, so by editing you
	; might introduce terminators (zero byte) unintentionally. Note that
	; multiple spaces are ignored, treated as a single space, so by this
	; the lines may be padded as necessary.
	;
	; Control codes:
	; 1-7: Change blit style for subsequent characters of a word.
	; 12: Left align line in which it occurs.
	; 13: Right align line in which it occurs.
	; 14: Center line in which it occurs.
	; 15: Justify line in which it occurs.

txt:	db 14, 1, "Proportional ", 1, "text ", 1, "demo\n\n"
	db 15, "This example demonstrates proportional text output in RRPGE, "
	db "using the ", 4, "Graphics ", 4, "Accelerator for blitting the "
	db "characters. The example contains some generic libraries for "
	db "both text output and generic blitting.\n\n"
	db "The RRPGE system's development in it's current form was started "
	db "in the summer of 2013, and opened to the public on the 1st  "
	db "April of 2014; however about a decade of earlier experiences  "
	db "were incorporated in this process. The primary goal of the  "
	db "system is to realize a fully reproducible base for retro style  "
	db "game development in an open source software compatible  "
	db "manner.\n\n "
	db "My personal goal with RRPGE is mostly probably realizing  "
	db "computer roleplaying games in my sci-fi fantasy universe and  "
	db "maybe others, some quite large scale tasks. While it is okay  "
	db "that IT develops, it is quite straining to not have something "
	db "steady to do ", 4, "interactive ", 4, "art with, something with "
	db "which the once created piece won't need perpetual maintainance  "
	db "later on. And by the way: Programming in assembly is still a  "
	db "fun way to waste some hours!\n\n"
	db 13, 6, "Jubatian"


org 0xBC0

	dw 0x0000, 0x0000, 0x0100, 0x0000, 0xF800



section data

llay:	ds 50			; Space for the line layout of 25 lines of text
llayc:	ds 1			; Count of entries generated in the line layout

font_def	equ	0x4000	; Extracted font definition data (1024 words)



section code

	; Switch to 4 bit mode

	jsv {kc_vid_mode, 0}

	; Turn off double scanned mode.

	mov a,     0x5000	; Keep output width at 80 cells (not used here)
	mov [0x1E04], a

	; Set up display list for 400 image lines. Will use entry 1 of the
	; list for this.

	mov xm3,   PTR16I
	mov a,     0x0000	; High part of the display list entry
	mov b,     0xC000	; Low part of the display list entry
	mov x3,    0x2002	; Points to the list, first line, entry 1
ldls:	mov [x3],  a
	mov [x3],  b
	add a,     5		; Next line (16 * 5 = 80 cells width)
	add x3,    6		; Skip to next line's entry 1
	xeq x3,    0x2C82	; Would be line 400's entry 1
	jmr ldls

	; Copy font data into VRAM (bank 0, VRAM cell offset 0x8000)

	jfa copy {0x41C0, 0x380, 0x0801, 0, 0, 928}

	; Expand compact font definition

	jfa fontdef1_m4 {0x0300, font_def, 0, 0x8000}

	; Generate line layout for the text. The line layout is used to
	; pre-calculate which parts of the text should go in which line, so
	; later when rendering only the visible part of a large block of text,
	; the invisible part above need not be calculated.

	jfa textlgen {txt, font_def, 624, llay, 20}
	mov [llayc], a		; Count of lines the text has

	; Render text: first initialize the blitter, then output it.

	jfa blitsupp_reset
	jfa blitsupp_setdest {80, 0, 15}

	jfa textblit_block {txt, llay, 18, [llayc], font_def, blits, 0x5050, 0x0190, 0x0001, 624, 10, blitnc}

	; Empty main loop

lmain:	jmr lmain



;
; Additional code modules
;

include "copy.asm"
include "blit.asm"
include "blitsupp.asm"
include "blitnc.asm"
include "textblit.asm"
include "textlgen.asm"
include "fontdef1.asm"
