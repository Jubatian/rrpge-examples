;
; Various examples of printf
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;
;
; Shows various uses of the printf function and the related infrastructure.
;


include "../rrpge.asm"

AppAuth db "Jubatian"
AppName db "Example: Printf"
Version db "00.000.002"
EngSpec db "00.016.000"
License db "RRPGEvt", "\n"
        db 0



section data

title:	db "Examples demonstrating $c5;printf$c; and some related functions\n\n"
	db "RRPGE 16 color palette:\n"
	db " 0: (Black)\n"
	db " 1: $cx1;Bright grey$c;\n"
	db " 2: $cx2;Dark grey$c;\n"
	db " 3: $cx3;White$c;\n"
	db " 4: $cx4;Dark blue$c;\n"
	db " 5: $cx5;Green$c;\n"
	db " 6: $cx6;Red$c;\n"
	db " 7: $cx7;Pale yellow$c;\n"
	db " 8: $cx8;Mid blue$c;\n"
	db " 9: $cx9;Purple$c;\n"
	db "10: $cxa;Dark brown$c;\n"
	db "11: $cxb;Yellow$c;\n"
	db "12: $cxc;Bright blue$c;\n"
	db "13: $cxd;Dark green$c;\n"
	db "14: $cxe;Dark red$c;\n"
	db "15: $cxf;Brown$c;\n", 0

sincos:	db "Sine & Cosine outputs, just to demonstrate formatters. The range is between\n"
	db "-0x4000 and +0x4000 (representing -1 and +1), with some linear interpolation\n"
	db "used between key points. The (in)accuracy is visible on the sum of squares\n"
	db "which ideally should make 0x10000000.\n\n"
	db "    Input   Sine Cosine        Sin²        Cos²   Sin²+Cos²\n"
	db "Dec %5u %+6d %+6d %11ld %11ld %11ld\n", 0
sincoh:	db "Hex  %04X   %04X   %04X    %08lX    %08lX    %08lX\n", 0
angle:	db "\n"
	db "Input angle (%-5u) in degrees: %i  \n", 0

frate:	db "Frame rate:%4i FPS", 0



section zero

	; The character writer

writt:	ds 15



section code

main:

	; Switch to 640x400, 16 color mode

	jsv kc_vid_mode {0}

	; Set up display list for 400 image lines. Will use entry 1 of the
	; list for this. Clearing the list is not necessary since the default
	; list for double scanned mode also only contained nonzero for entry
	; 1 (every second entry 1 position in the 400 line list).

	jfa us_dlist_sb_add {0x0000, 0xC000, 400, 1, 0}

	; Set up character writer for outputting colored text on the screen
	; (colorkey transparency)

	jfa us_cw_tile_new {writt, up_font_4i, up_dsurf, 1}

	; Print title text with RRPGE palette color descriptions

	jfa us_printfnz {writt, up_cr_utf8, title}

	; Prepare for main loop, change to non-colorkeyed text so it can be
	; overwritten but would need reindex tables for coloring

	jfa us_cw_tile_new {writt, up_font_4, up_dsurf, 0}

	; Allocate some stack space for temporary vars

	mov sp,    10

	; Init frame rate counting variables

	mov c,     0
	mov [$6],  c		; Last measured frame rate
	mov c,     [P_CLOCK]
	mov [$7],  c		; Last 187.5Hz clock state to measure elapsed time
	mov c,     0
	mov [$8],  c		; Count of clock ticks since last update
	mov c,     0
	mov [$9],  c		; Number of frames rendered

	; Enter main loop. Note the wait for Graphics FIFO draining: It is not
	; really necessary here since the Accelerator can render the tiny font
	; tiles much faster than printf can produce them, however in single
	; buffered application it should be done this way, to anticipate an
	; Accelerator bottleneck (when using the User Library's double
	; buffering routines, they enforce this wait where it is necessary).

	jms .lm
.lmw:	jsv kc_dly_delay {0x2000}
.lm:	mov a,     [P_GFIFO_STAT]
	jnz a,     .lmw		; Wait for FIFO empty
	mov a,     [P_CLOCK]

	; Frame rate calculation

	mov b,     a
	sub b,     [$7]		; Elapsed ticks
	mov [$7],  a
	add b,     [$8]		; Total ticks since last update
	mov [$8],  b
	xug b,     150
	jms .fr0

	; Nearly a second elapsed: Calculate a new frame rate indication
	; (frames per second).

	mov d,     [$9]		; Number of frames rendered
	mul c:d,   188		; Calculate frames / sec (good enough 187.5)
	xeq c,     0
	mov d,     0xFFFF	; Just saturate it
	div d,     b
	mov [$6],  d
	mov c,     0
	mov [$9],  c		; Reset frame counter
	mov [$8],  c		; Reset total ticks since last update

.fr0:	mov b,     1		; One additional frame will render
	add [$9],  b

	; Calculate inputs.

	mov b,     360
	mul c:b,   a
	mov b,     c		; Angle in degrees
	jfa us_sincos {a}
	mov x0,    x3		; Sine
	mov x1,    c		; Cosine
	mov x3,    x0
	xbc x3,    15
	neg x3,    x3		; Absolute value
	mul c:x3,  x3
	mov [$0],  c
	mov [$1],  x3		; Sine squared
	mov x3,    x1
	xbc x3,    15
	neg x3,    x3		; Absolute value
	mul c:x3,  x3
	mov [$2],  c
	mov [$3],  x3		; Cosine squared
	mov d,     c
	add c:x3,  [$1]
	adc d,     [$0]
	mov [$4],  d
	mov [$5],  x3		; Square sum

	; Output calculations

	jfa us_cw_tile_setxy {writt, 0, 20}
	jfa us_printfnz {writt, up_cr_utf8, sincos, a, x0, x1, [$0], [$1], [$2], [$3], [$4], [$5]}
	jfa us_printfnz {writt, up_cr_utf8, sincoh, a, x0, x1, [$0], [$1], [$2], [$3], [$4], [$5]}
	jfa us_printfnz {writt, up_cr_utf8, angle,  a, b}

	; Output frame rate

	jfa us_cw_tile_setxy {writt, 55, 17}
	jfa us_printfnz {writt, up_cr_utf8, frate, [$6]}

	jms .lm
