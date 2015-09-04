;
; Simple input event example
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2015, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;
;
; Shows input events as they arrive, useful for debugging the input system.
; Attempts to request a mouse and a gamepad for this purpose.
;


include "../rrpge.asm"

AppAuth db "Jubatian"
AppName db "Example: Simple events"
Version db "00.000.000"
EngSpec db "00.018.000"
License db "RRPGEvt", "\n"
        db 0


section data

title:	db "Input device example (events from a pointing and a gamepad device)", 0

evdsc:	db "Device: %01X, Type: %01X, Msg.Type: %01X, Msg.Data: %04X\n"
	db "                                                          ", 0


section zero

	; The character writer

writt:	ds 15


section code

main:

	; Set up for printf, using the non-colored text so it can be
	; overwritten as events come in.

	jfa us_cw_tile_new {writt, up_font_4, up_dsurf, 0}

	; Request devices

	jsv kc_inp_reqdev {0, DEV_POINT}
	jsv kc_inp_reqdev {1, DEV_PAD}

	; Output title

	jfa us_printfnz {writt, up_cr_utf8, title}

	; Prepare for main loop. Register 'x2' will hold the line used for
	; outputting the event's description.

	mov x2,    2

	; Enter main loop

.lp:	jsv kc_inp_pop {}
	jnz c,     .lps
	jsv kc_dly_delay {65535}
	jms .lp			; Wait for event if there is none

.lps:	; There is an event in c:x3. Check if it is a beginning event, if not,
	; ignore it.

	xbs c,     11
	jms .lp			; Not a beginning event

	; Don't care for trailing events (long event messages) here, just
	; decode the first into components.

	mov a,     c
	shr a,     12		; Source device ID
	mov b,     c
	shr b,     4
	and b,     0xF		; Device type
	mov d,     c
	and d,     0xF		; Event message type
	mov x0,    x3		; Event data

	; Position the printf output row

	jfa us_cw_tile_setxy {writt, 0, x2}
	add x2,    1
	xne x2,    32
	mov x2,    2

	; Output event information

	jfa us_printfnz {writt, up_cr_utf8, evdsc, a, b, d, x0}

	; Done, wait for subsequent events

	jms .lp
