;
; Mouse example program
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;
;
; Shows some mouse input, simply by plotting pixels on the display as the
; mouse moves around.
;


include "../rrpge.asm"

section cons

	db "RPA\n"
	db "\nAppAuth: Jubatian        "
	db "\nAppName: Example program: Mouse            "
	db "\nVersion: 00.000.002"
	db "\nEngSpec: 00.005.000"
	db "\nLicense: RRPGEv2\n\n"
	db 0

org 0xBC0

	; Request mouse device on 0xBC1 of the application header

	dw 0x0000, 0x0800, 0x0100, 0x0000, 0xF800


section code

	; Switch to 8 bit mode (it is simpler since there are only 64000
	; pixels to address).

	jsv {kc_vid_mode, 1}

	; x3 will be used as pointer into the graphics memory, simply using
	; the default layout.

	mov xm3,   PTR8
	mov xh3,   1		; The graphics is visible on the higher half

	; If a mouse is present, it will show up as device 0. Just poll it so
	; it comes visible to the application. No checking for return as there
	; is nothing much to do if there is no mouse.

	jsv {kc_inp_getprops, 0}

	; Register 'b' will hold the color to "draw" with, initially white.

	mov b,     3

	; Register 'd' will hold previous mouse button states, to detect clicks.

	mov d,     0

lmain:	; Now enter main loop

	; Get mouse coordinates and calculate offset

	jsv {kc_inp_getai, 0, 1}
	shr a,     1		; Mouse Y coordinate. It is between 0 and 399, so need to scale down
	mul a,     320		; Make offset component of it
	mov x3,    a
	jsv {kc_inp_getai, 0, 0}
	shr a,     1		; Mouse X coordinate. It is between 0 and 639, so need to scale down
	add x3,    a

	; Get buttons: left (primary) button cycles color to left, right
	; (secondary) button cycles to the right. Note: input group 0 is the
	; feedback of touch areas, group 1 gives the mouse buttons.

	jsv {kc_inp_getdi, 0, 1}
	mov c,     a
	xor a,     d		; Any button state changed?
	and a,     c		; Only carry over changes where released -> pressed (click)
	mov d,     c		; Update previous button state
	xbc a,     4		; Primary button click?
	sub b,     1		; Cycle color to left
	xbc a,     5		; Secondary button click?
	add b,     1		; Cycle color to right

	; Plot pixel

	mov [x3],  b

	jmr lmain
