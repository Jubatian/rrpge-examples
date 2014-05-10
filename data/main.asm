;
; Binary data example program
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;
;
; Shows an example of using display data. The image used is one of my
; photographies, if you really want to, you may use it as-is by the terms of
; the license. It only uses 64 colors, so the upper 2 bits are free for use as
; needed.
;


include "../rrpge.asm"
bindata "lizard_p.bin" h, 0x100
bindata "lizard_i.bin" 0

section cons

	db "RPA\n"
	db "\nAppAuth: Jubatian        "
	db "\nAppName: Example program: Binary data      "
	db "\nVersion: 00.000.001"
	db "\nEngSpec: 00.004.001"
	db "\nLicense: RRPGEv2\n\n"
	db 0

org 0xBC0

	dw 0x0000, 0x0000, 0x0100, 0x0010, 0xF800



section code

	; Change to 8 bit mode

	jsv {kc_vid_mode, 1}

	; Apply palette

	mov xm3,   PTR16I
	mov x3,    0x100
	mov a,     0
lpal:	jsv {kc_vid_setpal, x3, [x3]}
	xeq x3,    0x200
	jmr lpal

	; Set up display list of page 2 for 400 lines. Only need to set a 80
	; increment for lines 1 - 399, in the whole part.

	mov a,     80
	mov x3,    0x2002
ldls:	mov [x3],  a		; Write whole part only
	add x3,    1
	xeq x3,    0x2320
	jmr ldls

	; Load the pages of the image. Note the use of delay in the loading
	; loop: in such busy loops when the application just waits, depending
	; on the kernel this may be beneficial (the kernel may use the
	; additional cycles to perform the task faster).

	mov b,     0
	mov d,     0x8000
llod:	jsv {kc_sfi_loadbin, 0x4002, 0, b}
	mov c,     a
llodt:	jsv {kc_dly_delay, 10000}
	jsv {kc_tsk_query, c}
	xbs a,     15		; Is task complete?
	jmr llodt
	jsv {kc_tsk_discard, c}	; Task completed, discard it
	jfa pagecopy {d, 0x4002}
	add d,     1
	add b,     1
	xeq b,     16
	jmr llod

	; Image loaded and displayed, just sit in an empty loop

lmain:	jmr lmain



;
; Additional code modules
;

include "pagecopy.asm"
