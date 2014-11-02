;
; Rotozoomer example program
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;
;
; Displays a rotozoomer extended with a display list wave effect. Also shows
; some examples of larger program construction, building from multiple source
; components.
;


include "../rrpge.asm"

AppAuth db "Jubatian"
AppName db "Example: Rotozoomer"
Version db "00.000.006"
EngSpec db "00.012.000"
License db "RRPGEvt", "\n"
        db 0



section data

logo_rle:

bindata "../logo_rle.bin"

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

accrg:				; 5 accelerator registers for rotozoom
	dw 0x00F0		; Source partition, X/Y split irrelevant, destination full.
	dw 0x0000		; Substitutions irrelevant, no barrel rotation / colorkey.
	dw 0xFF00		; Source AND mask: no effect (set), no colorkey.
	dw 0x0000		; Reindex bank irrelevant (by destination).
	dw 0x3000		; Reindex by destination mode, no OR mask, 4 bit mode



section code

main:

	; Switch to 640x400, 16 color mode

	jsv {kc_vid_mode, 0}

	; Set up display list for 400 image lines. Will use entry 1 of the
	; list for this.

	jfa us_ptr_set16i {3, 0x001F, 0xE000}
	mov xm0,   PTR16
	mov x0,    x3

	; All, except entry 1 of the list is zero. Entry 1 need to populate
	; the display (entry 0 would be background pattern).

	mov a,     0		; Zero filler
	mov b,     0x0000	; High part with the source line offsets
	mov d,     0xC000	; Low part with the render mode & position
	mov c,     400		; Line counter

.l0:	mov [x0],  a		; Backround (entry 0)
	mov [x0],  a		; Backround (entry 0)
	mov [x0],  b		; Entry 1, high part
	mov [x0],  d		; Entry 1, low part
	mov [x0],  a		; Entry 2, empty
	mov [x0],  a		; Entry 2, empty
	mov [x0],  a		; Entry 3, empty
	mov [x0],  a		; Entry 3, empty
	add b,     5		; Next source line (16 * 5 = 80 cells wide)
	sub c,     1
	xeq c,     0
	jms .l0

	; Copy RLE (1927 words) data into PRAM (high half of bank 0)

	jfa us_copy_pfc {0x0001, 0x0000, logo_rle, 1927}

	; Load RLE image

	jfa rledec {0x3, 0xE800, 0, 0x3000, 0x0000, 0x0000, 0x0010, 0x0000, 0x1230}

	; Copy image to the next PRAM bank (bank 1; it is all zero)

	mov xm2,   PTR16
	mov x2,    P_GFIFO_DATA
	mov a,     0x8016	; Accelerator X pointers & increments
	mov [P_GFIFO_ADDR], a
	mov a,     0x0000
	mov [x2],  a		; Source X whole
	mov a,     0x0000
	mov [x2],  a		; Source X fraction
	mov a,     0x0001
	mov [x2],  a		; Source X increment whole
	mov a,     0x0000
	mov [x2],  a		; Source X increment fraction
	mov a,     0x0050
	mov [x2],  a		; Source X post-add whole
	mov a,     0x0000
	mov [x2],  a		; Source X post-add fraction
	mov a,     0x0000
	mov [x2],  a		; Destination whole
	mov a,     0x0000
	mov [x2],  a		; Destination fraction
	mov a,     0x0001
	mov [x2],  a		; Destination increment
	mov a,     0x0080
	mov [x2],  a		; Destination post-add
	mov a,     0x8004	; Accelerator source bank select
	mov [P_GFIFO_ADDR], a
	mov a,     0
	mov [x2],  a		; Source bank select
	mov a,     1
	mov [x2],  a		; Destination bank select
	mov a,     0
	mov [x2],  a		; Source partition select
	mov a,     0
	mov [x2],  a		; Destination partition select
	mov a,     0xFFF0
	mov [x2],  a		; Partitioning settings
	mov a,     0x0000
	mov [x2],  a		; Substitutions, source barrel rotate, colorkey flag
	mov a,     0xFF00
	mov [x2],  a		; Source AND mask and colorkey
	mov a,     0
	mov [x2],  a		; Reindex bank select
	mov a,     0x0000
	mov [x2],  a		; Blit mode (BB, no reindex, 4 bit, no mirror, no OR)
	mov a,     400
	mov [x2],  a		; 400 lines
	mov a,     640
	mov [x2],  a		; 640 pixels / line
	mov [x2],  a		; Start trigger

	; Set up reindex table by feeding it into the Graphics FIFO.

	mov x3,    reimp
	mov c,     0x8100	; First reindex register
	mov [P_GFIFO_ADDR], c
.rlop:	mov a,     [x3]
	mov [x2],  a
	xeq x3,    reimp_end
	jms .rlop

	; Set up Accelerator for rotozooming

	mov c,     0x8004	; FIFO: Accelerator source bank select
	mov [P_GFIFO_ADDR], c
	mov a,     1
	mov [x2],  a		; Source bank select
	mov a,     0
	mov [x2],  a		; Destination bank select
	mov [x2],  a		; Source partition select
	mov [x2],  a		; Destination partition select
	mov c,     0x800D	; FIFO: Accelerator row count
	mov [P_GFIFO_ADDR], c
	mov a,     400
	mov [x2],  a		; 400 lines
	mov a,     640
	mov [x2],  a		; 640 pixels / line
	mov c,     0x801C	; FIFO: Destination whole
	mov [P_GFIFO_ADDR], c
	mov a,     0x0000	; Destination whole
	mov [x2],  a
	mov a,     0x0000	; Destination fraction
	mov [x2],  a
	mov a,     0x0001	; Destination increment
	mov [x2],  a
	mov a,     0x0050	; Destination post-add
	mov [x2],  a

	; Enter main loop. The real time synchronization is based on the
	; 187.5Hz clock, divided by 2 to get a roughly 94Hz base tick. x1 will
	; keep track of this, while x0 will keep track of 94Hz ticks.

	mov x1,    0x240	; Looks good for start
	mov x0,    [P_CLOCK]	; 187.5Hz clock
	shr x0,    1

.lmw:	jsv {kc_dly_delay, 0xFFFF}
.lm:	mov a,     [P_GFIFO_STAT]
	xeq a,     0		; Wait for FIFO empty
	jms .lmw
	mov a,     [P_CLOCK]
	shr a,     1
	xch x0,    a		; x0: new 94Hz tick, a: old tick value
	mov b,     x0
	sub b,     a
	and b,     0x7FFF	; Count of ticks since last run
	add x1,    b

	; Load a value from the large sine table by x3

	mov x2,    x1
	shr x2,    1
	and x2,    0x1FF
	add x2,    0xFE00	; Offset of large sine (-0x4000 - 0x4000)
	mov a,     [x2]

	; Run wave effect

	mov b,     a
	add b,     0x4000	; 0x0000 - 0x8000
	shr b,     8		; 0x00 - 0x80
	jfa effwave {0, x1, b, 0x001F, 0xE003, 4, 400}

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
	mov d,     x1
	shr d,     1
	add d,     0x80		; 90 degrees aligning rotation
	jfa offrzoom {320, 200, d, b, accrg}

	; Main loop ends

	jms .lm



;
; Additional code modules
;

include "rledec.asm"
include "effwave.asm"
include "effrzoom.asm"
include "../_userlib/copy.asm"
include "../_userlib/ptr.asm"
