;
; Character set example
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2015, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;
;
; Outputs the default character set using the 640x400, 4 bit graphics mode.
;


include "../rrpge.asm"

AppAuth db "Jubatian"
AppName db "Example: Character matrix"
Version db "00.000.005"
EngSpec db "00.018.000"
License db "RRPGEvt", "\n"
        db 0



section code

main:

	; Set up for tile blitting to the default surface, from 4 bit inverted
	; font.

	jfa us_dsurf_getacc {up_dsurf}
	jfa us_tile_acc {up_font_4i}

	; Create a nice colorful 16x16 matrix of characters in the center of
	; the display. One row is 80 cells wide, start with cell 32 to center.
	; For Y, 104 is used for start, to center the 192 row tall (16x12)
	; matrix. Start offset is so 80 * 104 + 32 = 8352 (0x20A0). To
	; increment rows, after a line (16 adds), 80 * 12 - 16 = 944 (0x03B0)
	; has to be added.

	mov d,     0x20A0	; Start offset on destination
	mov a,     0x1000	; Character tile to output
	mov x0,    16		; Row counter

.lr:	mov x1,    16		; Column counter
.lc:	jfa us_tile_blit {up_font_4i, a, d}
	add d,     1
	add c:a,   0x1001
	xeq c,     0
	bts a,     12		; Skip over color 0
	sub x1,    1
	jnz x1,    .lc
	add d,     0x03B0	; To next row
	sub x0,    1
	jnz x0,    .lr

.lm:	jms .lm
