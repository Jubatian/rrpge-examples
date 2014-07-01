;
; Wave effect on a positioned source.
;
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;


include "../rrpge.asm"

section code

;
; Applies wave effect on a positioned source
;
; The display list has to be banked in the CPU address space. Also uses the
; small sine table within the ROPD (0xD80 - 0xDFF).
;
; Only the position in the display list is altered, the rest is left intact.
;
; The wave may be cycled, emphasised, and reduced.
;
; param0: Position base (only low 10 bits used).
; param1: Sine start offset (low 8 bits used).
; param2: Sine strength (0 - 0x100).
; param3: First entry's offset.
; param4: Display list line size (number of entries / line).
; param5: Number of lines to alter.
;

effwave:

.pbs	equ	0		; Position base
.sst	equ	1		; Sine start
.sml	equ	2		; Sine multiplier
.fof	equ	3		; First entry offset
.dls	equ	4		; Display list entry size
.lno	equ	5		; Number of lines to alter

	mov sp,    13		; Reserve space on stack

	; Save registers

	mov [bp +  6], a
	mov [bp +  7], b
	mov [bp +  8], c
	mov [bp +  9], x2
	mov [bp + 10], x3
	mov [bp + 11], xm
	mov [bp + 12], xh

	; Sanitize sine multiplier

	mov a,     [bp + .sml]
	xug 0x100, a
	mov a,     0x100
	mov [bp + .sml], a

	; Alter position base by the multiplier, so the sine will be centered
	; around it.

	shr a,     1		; Halve multiplier
	sub [bp + .pbs], a	; Subtract, so mid sine (0x80) will restore original

	; Prepare pointer to walk display list

	mov xm3,   PTR16
	mov x3,    [bp + .fof]
	add x3,    1		; Low part has to be updated

	; Prepare pointer to fetch sine

	mov xm2,   PTR8I
	mov xh2,   0
	mov x2,    [bp + .sst]
	and x2,    0xFF
	add x2,    0x1B00	; 8 bit address of sine (16 bit: 0xD80)

	; Produce display list

	mov c,     [bp + .lno]	; Line count to alter
.lp:	mov a,     [x2]		; Load sine value
	xne x2,    0x1C00	; Wrap sine
	mov x2,    0x1B00
	mul a,     [bp + .sml]
	shr a,     8
	add a,     [bp + .pbs]	; Added base, now it is a start offset
	and a,     0x3FF	; Limit to 10 bits
	mov b,     [x3]
	and b,     0xFC00	; Preserve high bits
	or  b,     a
	mov [x3],  b
	add x3,    [bp + .dls]	; To next line's entry
	add x3,    [bp + .dls]	; (twice since one entry is 32 bits)
	sub c,     1
	xeq c,     0
	jmr .lp

	; Restore regs & return

	mov xh,   [bp + 12]
	mov xm,   [bp + 11]
	mov x3,   [bp + 10]
	mov x2,   [bp +  9]
	mov c,    [bp +  8]
	mov b,    [bp +  7]
	mov a,    [bp +  6]
	rfn
