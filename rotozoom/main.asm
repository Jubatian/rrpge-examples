;
; Rotozoomer example program
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv1 (version 1 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv1 in the project root.
;
;
; Displays a rotozoomer extended with a display list wave effect. Also shows
; some examples of larger program construction, building from multiple source
; components.
;


include "../rrpge.asm"
bindata "../logo_rle.bin" h, 0x100

section cons

	db "RPA\n"
	db "\nAppAuth: Jubatian        "
	db "\nAppName: Example program: Rotozoomer       "
	db "\nVersion: 00.000.000"
	db "\nEngSpec: 00.000.000"
	db "\nLicense: RRPGEv1\n\n"
	db 0

org 0xBC0

	dw 0x0000, 0x0000, 0x0100, 0x0000, 0xF800

org 0xA80

;
; Darkening reindex map. If source is darker than destination, steps one
; gradient down. The following gradient map is used:
;
; 0<A<2<9<F<1<B<7<3
;   4 | 8 | | C
;     E | 6 |
;       D   5
;

reimp:				; Reindex map (darkening when source is darker)
	dw 0x0001, 0x0203, 0x0405, 0x0607, 0x0809, 0x0A0B, 0x0C0D, 0x0E0F	; 0
	dw 0x0F01, 0x0F03, 0x0F05, 0x0607, 0x0F0F, 0x0F0B, 0x0C0F, 0x0F0F	; 1
	dw 0x0A01, 0x0203, 0x0405, 0x0607, 0x0809, 0x0A0B, 0x0C0D, 0x0E0F	; 2
	dw 0x0707, 0x0703, 0x0707, 0x0707, 0x0707, 0x0707, 0x0707, 0x0707	; 3
	dw 0x0001, 0x0203, 0x0405, 0x0607, 0x0809, 0x0A0B, 0x0C0D, 0x0E0F	; 4
	dw 0x0F01, 0x0F03, 0x0F05, 0x0607, 0x0F0F, 0x0F0B, 0x0C0F, 0x0F0F	; 5
	dw 0x0901, 0x0903, 0x0905, 0x0607, 0x0809, 0x090B, 0x0C0D, 0x090F	; 6
	dw 0x0B0B, 0x0B03, 0x0B0B, 0x0B07, 0x0B0B, 0x0B0B, 0x0C0B, 0x0B0B	; 7
	dw 0x0201, 0x0203, 0x0205, 0x0607, 0x0809, 0x020B, 0x0C0D, 0x0E0F	; 8
	dw 0x0201, 0x0203, 0x0205, 0x0607, 0x0809, 0x020B, 0x0C0D, 0x0E0F	; 9
	dw 0x0001, 0x0203, 0x0405, 0x0607, 0x0809, 0x0A0B, 0x0C0D, 0x0E0F	; A
	dw 0x0101, 0x0103, 0x0105, 0x0107, 0x0101, 0x010B, 0x0C01, 0x0101	; B
	dw 0x0101, 0x0103, 0x0105, 0x0107, 0x0101, 0x010B, 0x0C01, 0x0101	; C
	dw 0x0201, 0x0203, 0x0205, 0x0607, 0x0809, 0x020B, 0x0C0D, 0x0E0F	; D
	dw 0x0A01, 0x0203, 0x0405, 0x0607, 0x0809, 0x0A0B, 0x0C0D, 0x0E0F	; E
	dw 0x0901, 0x0903, 0x0905, 0x0607, 0x0809, 0x090B, 0x0C0D, 0x090F	; F
reimp_end:

section data

auitc:	ds 1			; Audio interrupt counter

section code

	; Use the wave effect to set up display list

	jfa effwave {0, 0, 0, 0, 0x2000}

	; Load RLE image

	jfa rledec {0x3, 0xE800, 0, 0x3000, 0x8000, 0x0000, PAGE_ROPD, 0x400, 0x1230}

	; Set video partition size: 32K cells

	mov a,     6
	mov [0x2EE2], a

	; Copy image to next video bank which is used as a full partition

	mov xm3,   PTR16I
	mov x3,    0x2EF0
	mov a,     0x0000	; Source whole: partition 0
	mov [x3],  a
	mov a,     1		; Source increment
	mov [x3],  a
	mov a,     0x0000	; Destination whole: partition 0
	mov [x3],  a
	mov a,     0		; Destination fraction
	mov [x3],  a
	mov a,     1		; Destination increment whole
	mov [x3],  a
	mov a,     0		; Source split mask
	mov [x3],  a
	mov a,     0		; Reindex bank select
	mov [x3],  a
	mov a,     0x80FF	; Source partition, rotate, AND mask
	mov [x3],  a
	mov a,     0x0000	; Mode, colorkey
	mov [x3],  a
	mov a,     640		; Number of pixels to process (1 - 1024)
	mov [x3],  a
	mov a,     0		; Source high (Video RAM bank)
	mov [x3],  a
	mov a,     1		; Destination high (Video RAM bank)
	mov [x3],  a
	mov [x3],  a		; Unused
	mov [x3],  a		; Unused
	mov [x3],  a		; Unused
	mov a,     0		; Line pattern & start trigger
	mov b,     48		; Destination add after each line
	mov xm3,   PTR16
	mov d,     400
acc0:	mov [x3],  a		; Start
	add [0x2EF2], b		; Pad destination (form an 1024 px wide image)
	sub d,     1
	xeq d,     0
	jmr acc0

	; Revert destination to Video RAM bank 0

	mov a,     0
	mov [0x2EFB], a		; Destination high

	; Clear partition zero

	mov a,     0
	mov [0x2EF2], a		; Destination whole
	mov a,     0x0400	; Line mode
	mov [0x2EF8], a		; Mode, colorkey
	mov a,     1024
	mov [0x2EF9], a		; Count of pixels
	mov a,     0x0000	; Line pattern & start trigger
	mov xm3,   PTR16
	mov d,     256
acc1:	mov [x3],  a		; Start
	sub d,     1
	xeq d,     0
	jmr acc1

	; Set up reindexing

	mov xm3,   PTR16I
	mov xm2,   PTR16I
	mov x2,    reimp
	mov x3,    0x2F00
rlop:	mov a,     [x2]
	mov [x3],  a
	xeq x2,    reimp_end
	jmr rlop

	; Set up reindex by destination mode, and the rest for rotozooming

	mov a,     0x3800	; Mode: Reindex by destination
	mov [0x2EF8], a
	mov a,     0x0001	; Source on bank 1
	mov [0x2EFA], a		; Source high (Video RAM bank)
	mov a,     1
	mov [0x2EF4], a		; Destination increment

	; Set up main loop

	mov x3,    0x120	; Looks good for start
	mov c,     x3
	mov [auitc], x3

	jsv {kc_aud_sethnd, audio_ev}

	mov xm2,   PTR16I

	; Sync loop to real time.
	; x3: Real time counter (approx 40/sec)
	; Note that the fadeout depends on the system's performance: on a
	; faster RRPGE implementation it will fade out faster until reaching
	; 40 FPS. On the minimal implementation at about 15 FPS is realized.

lmaiw:	jsv {kc_dly_delay, 0xFFFF}
lmain:	mov c,     [auitc]
	xne c,     x3
	jmr lmaiw		; (Unlikely... The rotozoom is slow)
	mov x3,    c

	; Load a value from the large ROPD sine table by x3

	mov x2,    x3
	and x2,    0x1FF
	add x2,    0xE00	; Offset of large sine (-0x4000 - 0x4000)
	mov a,     [x2]

	; Run wave effect

	mov b,     a
	add b,     0x4000	; 0x0000 - 0x8000
	shr b,     8		; 0x00 - 0x80
	jfa effwave {0, 0, x3, b, 0x2000}

	; Run rotozoomer

	mov c,     0		; Reset destination (accelerator increments it away)
	mov [0x2EF2], c		; Destination whole
	mov [0x2EF3], c		; Destination fraction
	mov b,     a
	add b,     0x4000	; 0x0000 - 0x8000
	shr b,     4		; 0x0000 - 0x0800
	mov d,     b
	mul c:d,   d
	shr c:c,   9
	src d,     9		; 0x0000 - 0x2000
	add b,     d
	add b,     0x80		; 0x0080 - 0x2880, zoom
	mov d,     x3
	add d,     0x80		; 90 degrees aligning rotation
	jfa offrzoom {320, 200, d, b}

	; Main loop ends

	jmr lmain


;
; Audio event (all registers are saved by the kernel)
;
; param0: Left / Mono target sample pointer in sample (byte) units
; param1: Right target sample pointer in sample (byte) units
;

audio_ev:
	mov a,     1
	add [auitc], a
	rfn


;
; Additional code modules
;

include "rledec.asm"
include "effwave.asm"
include "effrzoom.asm"
