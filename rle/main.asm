;
; RLE decoder example program
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2015, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;
;
; A simple RLE decoder decoding graphics (the RRPGE logo).
;


include "../rrpge.asm"

AppAuth db "Jubatian"
AppName db "Example: RLE decoder"
Version db "00.000.008"
EngSpec db "00.018.000"
License db "RRPGEvt", "\n"
        db 0


section data

logo_rle:

bindata "../logo_rle.bin"



section code

main:

	; Copy RLE data into PRAM, above the display area

	jfa us_copy_pfc {0x0001, 0x0000, logo_rle, 1927}

	; Load RLE image onto the display

	jfa rledec {0x3, 0xE800, 0, 0x3000, 0x0000, 0x0000, 0x0010, 0x0000, 0x1230}

	; Image on screen, just do an infinite loop

.lm:	jms .lm



;
; Additional code modules
;

include "rledec.asm"
