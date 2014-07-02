;
; Rotozoomer example program
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
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
	db "\nVersion: 00.000.003"
	db "\nEngSpec: 00.007.003"
	db "\nLicense: RRPGEv2\n\n"
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

accrg:				; 8 accelerator registers for rotozoom
	dw 0x0001		; Source bank: 1, partition irrelevant.
	dw 0x0000		; Destination bank: 0, partition irrelevant.
	dw 0x0000		; Dest. incr: 1, reindex bank irrelevant (by destination).
	dw 0x00F0		; Source partition, X/Y split irrelevant, destination full.
	dw 0x00FF		; Source masks: no effect (OR: clear, AND: set).
	dw 0x3000		; Reindex by destination mode, no colorkey.
	dw 640			; One line takes 640 4bit pixels.
	dw 0x0000		; Trigger: value irrelevant.


section code

	; Switch to 4 bit mode

	jsv {kc_vid_mode, 0}

	; Use the Graphics FIFO to turn off double scanned mode in the
	; Graphics Display Generator's register 0x002.

	mov a,     0x5000	; Keep output width at 80 cells (not used here)
	mov b,     0x8002	; Graphics reg. write + 0x002 command
	mov [0x1E06], b		; Write command
	mov [0x1E07], a		; Write data, this will trigger a store
	mov [0x1E05], a		; Graphics FIFO start trigger (value ignored)
gfwa:	mov a,     [0x1E05]
	xbc a,     0		; Wait for the FIFO to become empty
	jmr gfwa		; So the graphics may be accessed

	; Set up display list for 400 image lines. Will use entry 1 of the
	; list for this.

	mov xm3,   PTR16I
	mov a,     0x4000	; High part of the display list entry
	mov b,     0x8000	; Low part of the display list entry
	mov x3,    0x2002	; Points to the list, first line, entry 1
ldls:	mov [x3],  a
	mov [x3],  b
	add a,     5		; Next line (16 * 5 = 80 cells width)
	add x3,    6		; Skip to next line's entry 1
	xeq x3,    0x2C82	; Would be line 400's entry 1
	jmr ldls

	; Load RLE image

	jfa rledec {0x3, 0xE800, 0, 0x3000, 0x8000, 0x0000, PAGE_ROPD, 0x400, 0x1230}

	; Copy and expand image into the next VRAM bank, to be an 1024 x 512
	; surface suitable for the rotozoomer. Uses the Accelerator for it.

	mov xm2,   PTR16
	mov x2,    0x1E07	; FIFO data write offset
	mov c,     0x8016	; FIFO: Accelerator X pointers & increments
	mov [0x1E06], c
	mov a,     0x0000	; Source X whole
	mov [x2],  a
	mov a,     0x0000	; Source X fraction
	mov [x2],  a
	mov a,     0x0001	; Source X increment whole
	mov [x2],  a
	mov a,     0x0000	; Source X increment fraction
	mov [x2],  a
	mov a,     0x0050	; Source X post-add whole
	mov [x2],  a
	mov a,     0x0000	; Source X post-add fraction
	mov [x2],  a
	mov a,     0x0000	; Destination whole
	mov [x2],  a
	mov a,     0x0000	; Destination fraction
	mov [x2],  a
	mov a,     0x0080	; Destination post-add whole
	mov [x2],  a
	mov a,     0x0000	; Destination post-add fraction
	mov [x2],  a
	mov c,     0x8008	; FIFO: Acc. source bank & partition select
	mov [0x1E06], c
	mov a,     0x0000	; Source bank: 0, partition select unused.
	mov [x2],  a
	mov a,     0x0001	; Destination bank: 1. partition select unused.
	mov [x2],  a
	mov a,     0x0000	; No reindexing, dest. increment is 1
	mov [x2],  a
	mov a,     0xFFF0	; Partition sizes & X/Y split: all full (only X used)
	mov [x2],  a
	mov a,     0x00FF	; Source masks
	mov [x2],  a
	mov a,     0x0000	; Mode: Plain Block Blitter, no reindex, no colorkey
	mov [x2],  a
	mov a,     640		; Output 640 4bit pixels in a line
	mov [x2],  a
	mov b,     400		; 400 lines
cplp0:	mov [x2],  a		; Fire accelerator (written value irrelevant)
	sub b,     1		; (Note: FIFO no longer increments ptr. from here)
	xeq b,     0
	jmr cplp0

	; Accelerator is copying stuff. Meanwhile set up reindexing table,
	; also through the Graphics FIFO.

	mov xm3,   PTR16I
	mov x3,    reimp
	mov c,     0x8100	; First reindex register
	mov [0x1E06], c
rlop:	mov a,     [x3]
	mov [x2],  a
	xeq x3,    reimp_end
	jmr rlop

	; Set up the Accelerator for the rotozoomer: destination props.

	mov c,     0x801C	; FIFO: Destination whole
	mov [0x1E06], c
	mov a,     0x0000	; Destination whole
	mov [x2],  a
	mov a,     0x0000	; Destination fraction
	mov [x2],  a
	mov a,     0x0050	; Destination post-add whole
	mov [x2],  a
	mov a,     0x0000	; Destination post-add fraction
	mov [x2],  a

	; Enter main loop. The real time synchronization is based on the audio
	; counter, running at 48KHz. It is (software) divided by 512 to get a
	; roughly 94Hz base tick. x3 will keep track of this, while x0 will
	; keep track of 94Hz ticks.

	mov x3,    0x240	; Looks good for start
	mov x0,    [0x1E0C]	; Audio DMA sample counter (48KHz)
	shr x0,    9

lmaiw:	jsv {kc_dly_delay, 0xFFFF}
lmain:	mov a,     [0x1E05]
	xbc a,     0		; Wait for FIFO empty
	jmr lmaiw
	mov a,     [0x1E0C]
	shr a,     9
	xch x0,    a		; x0: new 47Hz tick, a: old tick value
	mov b,     x0
	sub b,     a
	and b,     0x7F		; Count of ticks since last run
	add x3,    b

	; Load a value from the large ROPD sine table by x3

	mov x2,    x3
	shr x2,    1
	and x2,    0x1FF
	add x2,    0xE00	; Offset of large sine (-0x4000 - 0x4000)
	mov a,     [x2]

	; Run wave effect

	mov b,     a
	add b,     0x4000	; 0x0000 - 0x8000
	shr b,     8		; 0x00 - 0x80
	jfa effwave {0, x3, b, 0x2002, 4, 400}

	; Run rotozoomer

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
	shr d,     1
	add d,     0x80		; 90 degrees aligning rotation
	jfa offrzoom {320, 200, d, b, accrg, 400}

	; Reset destination after the rotozoomer

	mov d,     0x801C	; FIFO: Destination whole
	mov [0x1E06], d
	mov d,     0x0000
	mov [0x1E07], d		; Destination whole
	mov [0x1E07], d		; Destination fraction

	; Main loop ends

	jmr lmain



;
; Additional code modules
;

include "rledec.asm"
include "effwave.asm"
include "effrzoom.asm"
