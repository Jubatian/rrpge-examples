;
; Simple mouse example
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;
;
; Shows some mouse input, simply by plotting pixels on the display as the
; mouse moves around.
;


include "../rrpge.asm"

AppAuth db "Jubatian"
AppName db "Example: Simple mouse"
Version db "00.000.000"
EngSpec db "00.011.003"
License db "RRPGEvt", "\n"
        db 0

section desc

org 0x000A
	dw 0x0001		; Request mouse device

section code

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
	shl c:x3,  3		; Make bit offset as required by the PRAM interface
	mov [P2_AH], c
	mov [P2_AL], x3

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

	mov [P2_RW],  b

	jmr lmain
