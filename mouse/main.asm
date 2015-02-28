;
; Simple mouse example
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2015, GNU GPLv3 (version 3 of the GNU General Public
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
Version db "00.000.002"
EngSpec db "00.016.000"
License db "RRPGEvt", "\n"
        db 0

section desc

org 0x000A
	dw 0x0001		; Request mouse device

section code

	; If a mouse is present, it will show up as device 0. Just poll it so
	; it comes visible to the application. No checking for return as there
	; is nothing much to do if there is no mouse.

	jsv kc_inp_getprops {0}

	; Register 'b' will hold the color to "draw" with, initially white.

	mov b,     3

	; Register 'd' will hold previous mouse button states, to detect clicks.

	mov d,     0

lmain:	; Now enter main loop

	; Get mouse coordinates and calculate offset

	jsv kc_inp_getai {0, 1}
	shr x3,    1		; Mouse Y coordinate. It is between 0 and 399, so need to scale down
	mul x3,    320		; Make offset component of it
	mov a,     x3
	jsv kc_inp_getai {0, 0}
	shr x3,    1		; Mouse X coordinate. It is between 0 and 639, so need to scale down
	add a,     x3
	shl c:a,   3		; Make bit offset as required by the PRAM interface
	mov [P2_AH], c
	mov [P2_AL], a

	; Get buttons: left (primary) button cycles color to left, right
	; (secondary) button cycles to the right. Note: input group 0 is the
	; feedback of touch areas, group 1 gives the mouse buttons.

	jsv kc_inp_getdi {0, 1}
	mov c,     x3
	xor x3,    d		; Any button state changed?
	and x3,    c		; Only carry over changes where released -> pressed (click)
	mov d,     c		; Update previous button state
	xbc x3,    4		; Primary button click?
	sub b,     1		; Cycle color to left
	xbc x3,    5		; Secondary button click?
	add b,     1		; Cycle color to right

	; Plot pixel

	mov [P2_RW],  b

	jms lmain
