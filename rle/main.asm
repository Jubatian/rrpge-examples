;
; RLE decoder example program
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;
;
; A simple RLE decoder decoding graphics (the RRPGE logo).
;


include "../rrpge.asm"

AppAuth db "Jubatian"
AppName db "Example: RLE decoder"
Version db "00.000.002"
EngSpec db "00.013.000"
License db "RRPGEvt", "\n"
        db 0


section data

logo_rle:

bindata "../logo_rle.bin"



section code

main:

	; Switch to 640x400, 16 color mode

	jsv {kc_vid_mode, 0}

	; Set up display list for 400 image lines. Will use entry 1 of the
	; list for this.

	jfa us_ptr_set16i {3, 0x001F, 0xE000}
	mov x0,    x3
	mov xm0,   PTR16

	; All, except entry 1 of the list is zero. Entry 1 need to populate
	; the display (entry 0 would be background pattern).

	mov a,     0		; Zero filler
	mov b,     0x0000	; High part with the source line offsets
	mov d,     0xC000	; Low part with the render mode & position
	mov c,     400		; Line counter

.l0:	mov [x0],  a		; Backround (entry 0)
	mov [x0],  a		; Backround (entry 0)
	mov [x0],  b		; Entry 1, high part
	mov [x0],  d		; Entry 1, low part
	mov [x0],  a		; Entry 2, empty
	mov [x0],  a		; Entry 2, empty
	mov [x0],  a		; Entry 3, empty
	mov [x0],  a		; Entry 3, empty
	add b,     5		; Next source line (16 * 5 = 80 cells wide)
	sub c,     1
	xeq c,     0
	jms .l0

	; Copy RLE data into PRAM, above the display area

	jfa us_copy_pfc {0x0001, 0x0000, logo_rle, 1927}

	; Load RLE image onto the display

	jfa rledec {0x3, 0xE800, 0, 0x3000, 0x0000, 0x0000, 0x0010, 0x0000, 0x1230}


	; Image on screen, just do an infinite loop

.lm:	jms .lm



;
; Additional code modules
;

include "rledec.asm"

