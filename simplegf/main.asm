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
; initial RRPGE system configuration provides an adequate 320x200 graphics
; setup.
;

include "../rrpge.asm"

AppAuth db "Jubatian"
AppName db "Example: Simple graphics"
Version db "00.000.001"
EngSpec db "00.016.000"
License db "RRPGEvt", "\n"
        db 0

section code

main:	; The display memory in the RRPGE system's initial setup starts at
	; Peripheral RAM page 0, as a 320x200, 8 bit surface. Peripheral RAM
	; pointer 2 initially is set up for 8 bits incrementing access, so the
	; simplest is to rely on that.

	; Outputs 16px wide left angled stripes. The low 3 bits of the cycle
	; counter is used as offset within the 16px wide stripe, the next 8
	; bits give the color index to be written out.

	mov a,     0		; Color counter start
	mov c,     200		; Output 200 lines
.lp0:	mov b,     a		; Color counter within the line
	mov d,     320		; Output 320 pixels per line
.lp1:	mov x0,    b
	shr x0,    3		; Cut low 3 bits
	mov [P2_RW], x0		; Output to the Peripheral RAM (incrementing)
	add b,     1		; Increment color counter
	sub d,     1
	jnz d,     .lp1		; End of X loop
	add a,     1		; Increment start of counter (angled stripes)
	sub c,     1
	jnz c,     .lp0		; End of Y loop

.inf:	jms .inf		; End of program, wait in infinite loop
