;
; Wave effect on a display list.
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2015, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;


include "../rrpge.asm"

section code

;
; Applies wave effect on a display list
;
; Uses the small sine table in the Peripheral RAM (PRAM: 0xFFE40 - 0xFFE7F).
;
; Only the position in the display list is altered, the rest is left intact.
; The display list entry provided needs to be the second half (odd address) of
; a 32 bit display list entry, as the position information in it is updated.
;
; The wave may be cycled, emphasised, and reduced.
;
; param0: Position base (only low 10 bits used).
; param1: Sine start offset (low 8 bits used).
; param2: Sine strength (0 - 0x100).
; param3: Display list entry word offset in PRAM, high.
; param4: Display list entry word offset in PRAM, low.
; param5: Display list line size (number of entries / line).
; param6: Number of lines to alter.
;
; Registers C and X3 are set zero. PRAM pointers 2 and 3 are not preserved.
; XM3 is assumed to be PTR16I.
;

effwave:

.pbs	equ	0		; Position base
.sst	equ	1		; Sine start
.sml	equ	2		; Sine multiplier
.doh	equ	3		; Display list offset, high
.dol	equ	4		; Display list offset, low
.dls	equ	5		; Display list line size
.lno	equ	6		; Number of lines to alter

	; Save registers

	psh a, b, d

	; Sanitize sine multiplier

	mov a,     [$.sml]
	xul a,     0x100
	mov a,     0x100
	mov [$.sml], a

	; Alter position base by the multiplier, so the sine will be centered
	; around it.

	shr a,     1		; Halve multiplier
	sub [$.pbs], a		; Subtract, so mid sine (0x80) will restore original

	; Prepare pointer to walk display list

	mov c,     [$.dls]
	shl c,     1		; 2 words for a display list entry
	jfa us_ptr_setgenww {2, [$.doh], [$.dol], 0, c}

	; Prepare pointer for sine source (in 'd', the sine start is calculated)

	mov d,     0xFF		; Sine start offset
	and d,     [$.sst]
	shl d,     3		; Shifted to bit address
	add d,     up1l_smp_sine
	jfa us_ptr_set8i {3, up1h_smp, d}

	; Produce display list

	mov c,     [$.lno]	; Line count to alter
.lp:	mov a,     [P3_RW]	; Load next sine value
	btc [P3_AL], 11		; Wrap around sample (not allowing reach in sample reductions)
	mul a,     [$.sml]
	shr a,     8
	add a,     [$.pbs]	; Added base, now it is a start offset
	and a,     0x3FF	; Limit to 10 bits
	mov b,     0xFC00	; Preserve high bits
	and b,     [P2_RW]
	or  b,     a
	mov [P2_RW], b
	sub c,     1
	jnz c,     .lp

	; Restore regs & return

	pop a, b, d
	rfn c:x3,  0
