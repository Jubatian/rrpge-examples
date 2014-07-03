;
; Mixer example
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;
;
; Just some basic mixer operations on two tones with a little of graphics mess
;


include "../rrpge.asm"

section cons

	db "RPA\n"
	db "\nAppAuth: Jubatian        "
	db "\nAppName: Example program: Mixer            "
	db "\nVersion: 00.000.002"
	db "\nEngSpec: 00.008.000"
	db "\nLicense: RRPGEv2\n\n"
	db 0


org 0xBC0

	dw 0x0000, 0x0000, 0x0100, 0x0000, 0xF800


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



section data

mix_f0:	ds 1			; Sample 0 freq / vol index
mix_v0:	ds 1
mix_p0:	ds 1			; Sample 0 offset (partition, whole, fraction)
mix_s0:	ds 2
mix_f1:	ds 1			; Sample 1 freq / vol index
mix_v1:	ds 1
mix_p1:	ds 1			; Sample 1 offset (partition, whole, fraction)
mix_s1:	ds 2

mix_pt:	ds 1			; Double buffer pointer
mix_st:	ds 1			; Frequency / amlitude step

section code

	; Set up sample data (initial frequency and volume indices from the
	; tables, and sample pointers)

	mov xm3,   PTR16I
	mov x3,    mix_f0
	mov a,     a_ton0
	mov [x3],  a
	mov a,     a_vol0
	mov [x3],  a
	mov a,     0x0880	; Start offset (word) of sine, whole
	mov [x3],  a
	mov [x3],  a
	mov a,     0		; Start offset (word) of sine, fraction
	mov [x3],  a
	mov a,     a_ton1
	mov [x3],  a
	mov a,     a_vol1
	mov [x3],  a
	mov a,     0x0900	; Start offset (word) of triangle, whole
	mov [x3],  a
	mov [x3],  a
	mov a,     0		; Start offset (word) of triangle, fraction
	mov [x3],  a

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

	; Initialize partitioning setting for the Mixer. This is common for
	; the operations.

	mov a,     0x6669	; Destination: 2K samples, rest: 256 samples.
	mov [0x1F17], a

lmain:	; Run sample generation

	jfa mixer

	; Periodic copy of the buffer to the display

	mov xm2,   PTR16I
	mov x3,    0x1000
	mov x2,    0x8000
lcp:	mov a,     [x3]
	mov [x2],  a
	xeq x3,    0x1800
	jmr lcp

	jmr lmain



;
; Mixer process. No input, no output.
;

mixer:

	mov sp,    8		; Reserve some space on the stack

	; Save CPU registers

	mov [bp + 0], xm
	mov [bp + 1], x3
	mov [bp + 2], x2
	mov [bp + 3], x1
	mov [bp + 4], x0
	mov [bp + 5], a
	mov [bp + 6], d
	mov [bp + 7], c

	mov xm3,   PTR16I
	mov xm2,   PTR16I
	mov xm1,   PTR16I
	mov xm0,   PTR16I

	; Initially the 0x000 - 0x7FF range of memory page 0 is the audio
	; output buffer, 0xE0C in the User Peripheral Area gives a DMA sample
	; pointer into it (where the Audio DMA will read next). Use double
	; buffering on it splitting it in two 0x400 word (1024 words or 2048
	; samples) halves, always refilling the half which is not addressed by
	; the DMA sample pointer.

	; Determine whether refilling is necessary

	mov d,     [mix_pt]	; Old pointer (0x0000 or 0x0800)
	mov a,     [0x1F0C]
	and a,     0x0800	; Which half the DMA sample pointer is in?
	xne a,     d
	jmr .exit		; If equal, nothing to do.

	; The DMA sample pointer left the last used half of the buffer, time
	; to refill it. The old pointer (in d) is what to fill.

	mov [mix_pt], a		; First update the pointer for next time
	shr d,     1		; Create word address from destination

	mov c,     [mix_st]	; Amp / freq. step: only step if zero

	; Now refill 2048 samples. In 'd' the pointer to the half where the
	; audio DMA is not reading is preserved, that will be the destination.

	; Sample 0

	mov x3,    0x1F18	; Mixer, Destination pointer
	mov x2,    mix_p0	; Sample offsets (load)
	mov x1,    mix_s0	; Sample offsets (save)
	mov [x3],  d
	mov a,     0		; Banks are all zero
	mov [x3],  a
	mov x0,    [mix_v0]	; Load amplitudo index
	mov a,     [x0]		; Load amplitudo & increment index
	xne x0,    a_vole
	mov x0,    a_vol0	; Wrap index
	xne c,     0
	mov [mix_v0], x0
	mov [x3],  a		; Amplitudo (volume)
	mov a,     [x2]
	mov [x3],  a		; Sample source start offset, partition
	mov a,     [x2]
	mov [x3],  a		; Sample source start offset, whole
	mov a,     [x2]
	mov [x3],  a		; Sample source start offset, fraction
	mov x0,    [mix_f0]	; Load frequency index
	mov a,     [x0]		; Load frequency & increment index
	xne x0,    a_tone
	mov x0,    a_ton0	; Wrap index
	xne c,     0
	mov [mix_f0], x0
	mov [x3],  a		; Frequency
	mov a,     0x2000	; Start, override, process 1024 samples
	mov [x3],  a
	sub x3,    1		; Trigger once more to get 2048 samples
	mov [x3],  a
	mov x3,    0x1F1C	; Mixer, sample offset whole
	mov a,     [x3]		; Save new offsets to continue later
	mov [x1],  a
	mov a,     [x3]
	mov [x1],  a

	; Sample 1

	mov x3,    0x1F18	; Mixer, Destination pointer
	mov x2,    mix_p1	; Sample offsets (load)
	mov x1,    mix_s1	; Sample offsets (save)
	mov [x3],  d
	mov a,     0		; Banks are all zero
	mov [x3],  a
	mov x0,    [mix_v1]	; Load amplitudo index
	mov a,     [x0]		; Load amplitudo & increment index
	xne x0,    a_vole
	mov x0,    a_vol0	; Wrap index
	xne c,     0
	mov [mix_v1], x0
	mov [x3],  a		; Amplitudo (volume)
	mov a,     [x2]
	mov [x3],  a		; Sample source start offset, partition
	mov a,     [x2]
	mov [x3],  a		; Sample source start offset, whole
	mov a,     [x2]
	mov [x3],  a		; Sample source start offset, fraction
	mov x0,    [mix_f1]	; Load frequency index
	mov a,     [x0]		; Load frequency & increment index
	xne x0,    a_tone
	mov x0,    a_ton0	; Wrap index
	xne c,     0
	mov [mix_f1], x0
	mov [x3],  a		; Frequency
	mov a,     0x0000	; Start, additive, process 1024 samples
	mov [x3],  a
	sub x3,    1		; Trigger once more to get 2048 samples
	mov [x3],  a
	mov x3,    0x1F1C	; Mixer, sample offset whole
	mov a,     [x3]		; Save new offsets to continue later
	mov [x1],  a
	mov a,     [x3]
	mov [x1],  a

	; Manage step

	add c,    1
	and c,    0x7		; Step after every 16K samples (roughly 3Hz)
	mov [mix_st], c

.exit:	; Restore registers & exit

	mov c,    [bp + 7]
	mov d,    [bp + 6]
	mov a,    [bp + 5]
	mov x0,   [bp + 4]
	mov x1,   [bp + 3]
	mov x2,   [bp + 2]
	mov x3,   [bp + 1]
	mov xm,   [bp + 0]

	rfn
