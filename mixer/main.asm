;
; Mixer example
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv1 (version 1 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv1 in the project root.
;
;
; Just some basic mixer operations on two tones with a little of graphics mess
;


include "../rrpge.asm"

section cons

	db "RPA\n"
	db "\nAppAuth: Jubatian        "
	db "\nAppName: Example program: Mixer            "
	db "\nVersion: 00.000.000"
	db "\nEngSpec: 00.000.000"
	db "\nLicense: RRPGEv1\n\n"
	db 0


; Frequency - volume data. Tone 0x8E represents A4 (440Hz)

org 0x100

a_ton0:	dw 0x0082, 0x0083, 0x0084, 0x0085, 0x0086
a_ton1:	dw 0x0087
	dw 0x0088, 0x0089, 0x008A, 0x008B, 0x008C, 0x008D
	dw 0x008E, 0x008F, 0x0090, 0x0091, 0x0092, 0x0093
	dw 0x0094, 0x0095, 0x0096, 0x0097, 0x0098, 0x0099
a_tone:
a_vol0:	dw 0x0011, 0x0022, 0x0033, 0x0044, 0x0055
a_vol1:	dw 0x0066
	dw 0x0077, 0x0088, 0x0099, 0x00AA, 0x00BB, 0x00CC
	dw 0x00BB, 0x00AA, 0x0099, 0x0088, 0x0077, 0x0066
	dw 0x0055, 0x0044, 0x0033, 0x0022, 0x0011, 0x0000
a_vole:


; Sound output is set up to Mono, 48KHz, 512 samples / half buffer

org 0xBC0

	dw 0x0001, 0x0000, 0x1100, 0x0000, 0xF800


section data

mix_f0:	ds 1			; Sample 0 freq / vol index
mix_v0:	ds 1
mix_s0:	ds 2			; Sample 0 offset (whole, fraction)
mix_f1:	ds 1			; Sample 0 freq / vol index
mix_v1:	ds 1
mix_s1:	ds 2			; Sample 0 offset (whole, fraction)

mix_st:	ds 1

section code

	; Set up sample data

	mov xm3,   PTR16I
	mov x3,    mix_f0
	mov a,     a_ton0
	mov [x3],  a
	mov a,     a_vol0
	mov [x3],  a
	mov a,     0x0880	; Start offset (word) of sine, whole
	mov [x3],  a
	mov a,     0		; Start offset (word) of sine, fraction
	mov [x3],  a
	mov a,     a_ton1
	mov [x3],  a
	mov a,     a_vol1
	mov [x3],  a
	mov a,     0x0900	; Start offset (word) of triangle, whole
	mov [x3],  a
	mov a,     0		; Start offset (word) of triangle, fraction
	mov [x3],  a

	; Start event handler

	jsv  {kc_aud_sethnd, audio_ev}

	; Set up a gradient palette

	mov a,     0x000
	mov d,     0
spal0:	jsv {kc_vid_setpal, d, a}
	add d,     1
	mov c,     d
	and c,     0xF
	xne c,     5
	add a,     0x100
	xne c,     10
	add a,     0x010
	xne c,     0
	add a,     0x001
	xeq a,     0xFFF
	jmr spal0
spal1:	jsv {kc_vid_setpal, d, a}
	add d,     1
	xeq d,     256
	jmr spal1

	; Spit out some ordinary XOR pattern

	mov xm2,   PTR8I
	mov xh2,   1
	mov x2,    0
	mov a,     0xFFF0
	mov b,     0
lpy:
lpx:	mov c,     a
	xor c,     b
	mov [x2],  c
	add b,     2
	xeq b,     640
	jmr lpx
	mov b,     0
	add a,     2
	xeq a,     384
	jmr lpy

lmain:	; Periodic copy of the buffer to the display

	mov xm2,   PTR16I
	mov x3,    0x1000
	mov x2,    0x8000
lcp:	mov a,     [x3]
	mov [x2],  a
	xeq x3,    0x1800
	jmr lcp

	jmr lmain

;
; Audio event (all registers are saved by the kernel)
;
; param0: Left / Mono target sample pointer in sample (byte) units
; param1: Right target sample pointer in sample (byte) units
;

audio_ev:
	mov xm3,   PTR16I
	mov xm2,   PTR16I
	mov xm1,   PTR16I
	mov xm0,   PTR16I

	; Load step

	mov d,     [mix_st]

	; Sample 0

	mov x3,    0x1ED0	; Mixer, source offset
	mov x2,    mix_s0	; Sample offsets (load)
	mov x1,    mix_s0	; Sample offsets (save)
	mov a,     [x2]
	mov [x3],  a		; Sample source start offset, whole
	mov a,     [x2]
	mov [x3],  a		; Sample source start offset, fraction
	mov x0,    [mix_f0]
	mov a,     [x0]
	xne x0,    a_tone
	mov x0,    a_ton0
	xne d,     0
	mov [mix_f0], x0
	mov [x3],  a		; Frequency
	mov x0,    [mix_v0]
	mov a,     [x0]
	xne x0,    a_vole
	mov x0,    a_vol0
	xne d,     0
	mov [mix_v0], x0
	mov [x3],  a		; Amplitudo (volume)
	mov x3,    0x1ED8	; Mixer, destonation start
	mov a,     [bp + 0]
	shr a,     1
	mov [x3],  a
	mov x3,    0x1EDF	; Mixer, start trigger
	mov a,     0x2100	; Start, override, process 512 samples
	mov [x3],  a
	mov x3,    0x1ED0	; Mixer, source offset
	mov a,     [x3]		; Save new offsets to continue later
	mov [x1],  a
	mov a,     [x3]
	mov [x1],  a

	; Sample 1

	mov x3,    0x1ED0	; Mixer, source offset
	mov x2,    mix_s1	; Sample offsets (load)
	mov x1,    mix_s1	; Sample offsets (save)
	mov a,     [x2]
	mov [x3],  a		; Sample source start offset, whole
	mov a,     [x2]
	mov [x3],  a		; Sample source start offset, fraction
	mov x0,    [mix_f1]
	mov a,     [x0]
	xne x0,    a_tone
	mov x0,    a_ton0
	xne d,     0
	mov [mix_f1], x0
	mov [x3],  a		; Frequency
	mov x0,    [mix_v1]
	mov a,     [x0]
	xne x0,    a_vole
	mov x0,    a_vol0
	xne d,     0
	mov [mix_v1], x0
	mov [x3],  a		; Amplitudo (volume)
	mov x3,    0x1ED8	; Mixer, destonation start
	mov a,     [bp + 0]
	shr a,     1
	mov [x3],  a
	mov x3,    0x1EDF	; Mixer, start trigger
	mov a,     0x0100	; Start, additive, process 512 samples
	mov [x3],  a
	mov x3,    0x1ED0	; Mixer, source offset
	mov a,     [x3]		; Save new offsets to continue later
	mov [x1],  a
	mov a,     [x3]
	mov [x1],  a

	; Step

	add d,     1
	and d,     31
	mov [mix_st], d

	rfn
