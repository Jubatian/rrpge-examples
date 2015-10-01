;
; Simple graphics example
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2015, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;
;
; Outputs simple graphics using the minimal set of peripherals necessary to
; accomplish this. This is basically only the Peripheral RAM interface as the
; initial RRPGE system configuration provides an adequate 640x400 graphics
; setup.
;

include "../rrpge.asm"

AppAuth db "Jubatian"
AppName db "Example: Simple graphics"
Version db "00.000.002"
EngSpec db "00.018.000"
License db "RRPGEvt", "\n"
        db 0

section code

main:	; The display memory in the RRPGE system's initial setup starts at
	; Peripheral RAM page 0, as a 640x400, 4 bit surface. Peripheral RAM
	; pointer 1 initially is set up for 4 bits incrementing access, so the
	; simplest is to rely on that.

	; Outputs 16px wide left angled stripes. The low 4 bits of the cycle
	; counter is used as offset within the 16px wide stripe, the next 4
	; bits give the color index to be written out.

	mov a,     0		; Color counter start
	mov c,     400		; Output 400 lines
.lp0:	mov b,     a		; Color counter within the line
	mov d,     640		; Output 640 pixels per line
.lp1:	mov x0,    b
	shr x0,    4		; Cut low 4 bits
	mov [P1_RW], x0		; Output to the Peripheral RAM (incrementing)
	add b,     1		; Increment color counter
	sub d,     1
	jnz d,     .lp1		; End of X loop
	add a,     1		; Increment start of counter (angled stripes)
	sub c,     1
	jnz c,     .lp0		; End of Y loop

.inf:	jms .inf		; End of program, wait in infinite loop
