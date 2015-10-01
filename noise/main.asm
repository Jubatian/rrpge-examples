;
; Noise generator example
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2015, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;
;
; A variation of this was the first "real" program for the RRPGE system. It is
; a very simple program using only the CPU to output the initial sample set to
; the audio buffer. It is useful for basic sanity tests when not even kernel
; calls are excepted to be working.
;


include "../rrpge.asm"

AppAuth db "Jubatian"
AppName db "Example: Noise"
Version db "00.000.002"
EngSpec db "00.018.000"
License db "RRPGEvt", "\n"
        db 0

section code

main:

	; Uses Pointer 2 for fetching samples (set up for 8 bit access), and
	; Pointer 3 for writing the audio buffer (set up for 16 bit access).
	; Register 'a' is just used as a simple indicator (if watched in any
	; way) that the program works, counting around as samples are output.

	mov a,     0
.lm:	jfa filla {up1l_smp_sqr}
	jfa waitl {10}
	add a,     1
	jfa filla {up1l_smp_sine}
	jfa waitl {10}
	add a,     1
	jfa filla {up1l_smp_tri}
	jfa waitl {10}
	add a,     1
	jfa filla {up1l_smp_spike}
	jfa waitl {10}
	add a,     1
	jfa filla {up1l_smp_sawi}
	jfa waitl {10}
	add a,     1
	jfa filla {up1l_smp_sawd}
	jfa waitl {10}
	add a,     1
	jfa filla {up1l_smp_nois1}
	jfa waitl {10}
	add a,     1
	jfa filla {up1l_smp_nois2}
	jfa waitl {10}
	mov a,     0
	jms .lm



;
; Fill audio buffer with the bit offset low sent as parameter (the high is
; always up1h_smp). Pointer 2 must be set up for 8 bits access, Pointer 3
; for 16 bits access.
;

filla:

.ofl	equ	0		; Bit offset low

	; Init sample source

	mov c,     up1h_smp
	mov [P2_AH], c
	mov c,     [$.ofl]
	mov [P2_AL], c

	; Init audio buffer (mono)

	mov c,     up1h_au_mono
	mov [P3_AH], c
	mov c,     up1l_au_mono
	mov [P3_AL], c

	; Output 4096 samples (this is the size of the default audio buffer)

	mov c,     4096
.l0:	mov x3,    [P2_RW]
	shl x3,    8
	bts x3,    7
	mov [P3_RW], x3
	btc [P2_AL], 11		; Force wrapping on source (don't enter rate reductions)
	sub c,     1
	jnz c,     .l0

	; Done

	rfn c:x3,  0



;
; Busy loop waiting. Normally the kernel's kc_dly_delay function should be
; used for such, however here no kernel calls are used.
;

waitl:

.cnt	equ	0		; Units to wait

	mov x3,    [$.cnt]
.l0:	mov c,     0
.l1:	sub c,     1
	jnz c,     .l1		; 64K times loop
	sub x3,    1
	jnz x3,    .l0
	rfn
