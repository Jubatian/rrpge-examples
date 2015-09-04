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
Version db "00.000.003"
EngSpec db "00.018.000"
License db "RRPGEvt", "\n"
        db 0

section code

main:

	; Request a mouse device (no check for whether it is actually
	; available, just a simple example)

	jsv kc_inp_reqdev {0, DEV_POINT}

	; Register 'b' will hold the color to "draw" with, initially white.

	mov b,     3

	; Register 'x0' will hold mouse X coordinate, and 'x1' the Y.

	mov x0,    320
	mov x1,    200

	; Enter main loop, waiting for events and acting upon them

.lp:	jsv kc_inp_pop {}
	jnz c,     .lps
	jsv kc_dly_delay {65535}
	jms .lp			; Wait for event if there is none

.lps:	; There is an event in c:x3. Check if it is a beginning event, if not,
	; ignore it. So X:Y locations coming with button presses will simply
	; be discarded.

	xbs c,     11
	jms .lp			; Not a beginning event

	; Since only the mouse is requested, assume everything coming from it,
	; just branching by event message type.

	and c,     0xF
	xne c,     2
	mov x0,    x3		; X location update
	xne c,     3
	mov x1,    x3		; Y location update
	xeq c,     0
	jms .eep
	xne x3,    1
	add b,     1		; Left button press, increment color
	xne x3,    2
	sub b,     1		; Right button press, decrement color

.eep:	; Until events are arriving, process them without rendering.

	jsv kc_inp_peek {}
	jnz c,     .lp		; An event is still waiting

	; Calculate offset for pixel

	mov x2,    x1
	mul c:x2,  640
	mov x3,    c
	add c:x2,  x0
	add x3,    c		; Offset in x3:x2 in pixel
	shl c:x2,  2
	slc x3,    2		; Make bit offset

	; Output it. PRAM pointer 1 will be used since it is initially set up
	; for 4 bit access, suitable for the display.

	mov [P1_AH], x3
	mov [P1_AL], x2
	mov [P1_RW], b

	; Done, return to reading events

	jms .lp
