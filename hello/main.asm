;
; Hello world example
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2015, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;
;
; Just the plain and simple "Hello world!" for RRPGE.
;


include "../rrpge.asm"

AppAuth db "Jubatian"
AppName db "Example: Hello world"
Version db "00.000.001"
EngSpec db "00.018.000"
License db "RRPGEvt", "\n"
        db 0



section data

	; Hello world string, with a terminating zero

hello:	db "Hello world!", 0


section zero


	; Character writer object

charw:	ds 15



section code

main:

	; Create a tile character writer for the display surface
	; The parameters:
	; Param0: The character writer object to fill in
	; Param1: The font to use. up_font_4i is a colorable font.
	; Param2: The destination surface. up_dsurf is the initial screen.
	; Param3: The initial text color. 12 is a bright blue.

	jfa us_cw_tile_new {charw, up_font_4i, up_dsurf, 12}

	; Position somewhere more pleasant than the very upper left corner

	jfa us_cw_tile_setxy {charw, 5, 5}

	; Output the hello world string. up_cr_utf8 is a character reader
	; which can read UTF-8 text from the CPU RAM.

	jfa us_strcpynz {charw, up_cr_utf8, hello}

	; Done, wait in empty loop

.lm:	jms .lm
