;
; Tile map example
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2015, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;
;
; Outputs a very simple tile map using the tile map manager of the User
; Library.
;


include "../rrpge.asm"

AppAuth db "Jubatian"
AppName db "Example: Simple tile map"
Version db "00.000.003"
EngSpec db "00.016.000"
License db "RRPGEvt", "\n"
        db 0



section data

	; Simple tile map. A yellow smiley in a brown box.

tmdat:	dw 0xF0C9, 0x60CD, 0x60CD, 0x60CD, 0xF0BB, 0x0020
	dw 0x60BA, 0xB020, 0xB002, 0xB020, 0x60BA, 0x0020
	dw 0xF0C8, 0x60CD, 0x60CD, 0x60CD, 0xF0BC, 0x0020



section zero

	; The tile map structure to be set up.

tmobj:	ds 5



section code

main:

	; Switch to 640x400, 16 color mode

	jsv kc_vid_mode {0}

	; Set up display list for 400 image lines. Will use entry 1 of the
	; list for this. Clearing the list is not necessary since the default
	; list for double scanned mode also only contained nonzero for entry
	; 1 (every second entry 1 position in the 400 line list).

	jfa us_dlist_sb_add {0x0000, 0xC000, 400, 1, 0}

	; Copy tile map in PRAM

	jfa us_copy_pfc {0x0002, 0x0000, tmdat, 18}

	; Set up tile map

	jfa us_tmap_new {tmobj, up_font_4i, 6, 3, 0x0002, 0x0000}

	; Set up for blitting it, set origin at 272:164 (272 is 34 cells).

	jfa us_tmap_accxy {tmobj, up_dsurf, 34, 164}

	; Blit it, replicated once on both X and Y.

	jfa us_tmap_blit {tmobj, 0, 0, 12, 6}

	; Wait in infinite loop

.lm:	jms .lm
