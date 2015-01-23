;
; Fast scrolling tile map example
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;
;
; Shows the use of the fast tile mapper, scrolling over a large (256x256) tile
; map.
;


include "../rrpge.asm"

AppAuth db "Jubatian"
AppName db "Example: Fast tile map scroll"
Version db "00.000.001"
EngSpec db "00.015.003"
License db "RRPGEvt", "\n"
        db 0



section data

logo_rle:

bindata "../logo_rle.bin"



section zero

	; The tile map structure to be set up.

tmobj:	ds 8

	; Fast tile mapper structure to be set up.

fmobj:	ds 10



section code

main:

	; Switch to 640x400, 16 color mode

	jsv {kc_vid_mode, 0}

	; Change source definition A1 to a shift source over PRAM Bank 2, 128
	; cells wide.

	mov x3,    0x02F0
	mov [P_GDG_SA1], x3

	; Change default surface accordingly (128 cells wide, full partition)

	jfa us_dsurf_set {up_dsurf, 2, 0, 128, 15}

	; Trim the output a little: Begin at cell position 4, with 72 cells
	; width (32 pixels skipped on each edge in 4 bit mode).

	mov x3,    0x4804
	mov [P_GDG_SMRA], x3

	; Prepare column 2 of the display lists to show PRAM Bank 0, where the
	; dragon logo will be unpacked

	jfa us_dlist_add {0x0000, 0x8000, 400, 2, 0x0780, 0}
	jfa us_dlist_add {0x0000, 0x8000, 400, 2, 0x0784, 0}

	; Display lists (smallest size) are going to be located in the low end
	; of Peripheral RAM bank 15:
	; (16 bit) 0x1E0000 - 0x1E0FFF (Display list definition: 0x0780)
	; (16 bit) 0x1E1000 - 0x1E1FFF (Display list definition: 0x0784)
	; Prepare for double buffering, setting the display lists.

	jfa us_dbuf_init {0x0780, 0x0784, 0x0000}

	; Decode RLE encoded logo into it's display location, using the high
	; half of PRAM bank 0 for temporarily storing the RLE encoded stream

	jfa us_copy_pfc {0x0001, 0x0000, logo_rle, 1927}
	jfa rledec {0x3, 0xE800, 0, 0xFFFF, 0x0000, 0x0000, 0x0010, 0x0000, 0x1230}

	; Create a big 256x256 tile map of chars in PRAM bank 1 (XOR pattern)

	jfa us_ptr_set16i {3, 0x0002, 0x0000}
	mov c,    256
.l0:	sub c,    1
	mov b,    256
.l1:	sub b,    1
	mov a,    c
	xor a,    b
	mov [P3_RW], a
	xeq b,    0
	jms .l1
	xeq c,    0
	jms .l0

	; Set up tile map

	jfa us_tmap_set {tmobj, up_font_4, 256, 256, 0x0002, 0x0000}

	; Set up fast scrolling tile mapper

	jfa us_fastmap_set {fmobj, tmobj, up_dsurf, 1, 32, 336, 0x1000, 512, 0xC000}

	; Main loop: do a big circular scroll. Note that since the scroll is
	; timed using the 187.5Hz clock, it will run the same way irrespective
	; of the display's refresh rate.

.mlp:	jfa us_dbuf_flip {}

	mov a,    [P_CLOCK]
	shl a,    1
	jfa us_sincos {a}
	add x3,   0x8000
	add c,    0x8000
	shr x3,   2
	shr c,    2
	add a,    32
	jfa us_fastmap_draw {fmobj, x3, c}

	jms .mlp



;
; Additional code modules
;

include "rledec.asm"
