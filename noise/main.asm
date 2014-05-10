;
; Noise generator example
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;
;
; This was the first "real" program for the RRPGE system. It is a very simple
; program using only the CPU to output the initial sample set to the audio
; buffer. It is useful for basic sanity tests when not even kernel calls are
; excepted to be working.
;


include "../rrpge.asm"

section cons

	db "RPA\n"
	db "\nAppAuth: Jubatian        "
	db "\nAppName: Example program: Noise            "
	db "\nVersion: 00.000.001"
	db "\nEngSpec: 00.004.001"
	db "\nLicense: RRPGEv2\n\n"
	db 0

org 0xBC0

	dw 0x0000, 0x0000, 0x0100, 0x0000, 0xF800


section code

	mov xm2,   PTR4I
	mov xh2,   0xE
	mov x2,    0x0000
	mov c,     0
home:	add c,     1
	jfa filla {0x1800}
	jfa waitl {5}
	mov [x2],  c
	add c,     1
	jfa filla {0x1880}
	jfa waitl {5}
	mov [x2],  c
	add c,     1
	jfa filla {0x1900}
	jfa waitl {5}
	mov [x2],  c
	add c,     1
	jfa filla {0x1980}
	jfa waitl {5}
	mov [x2],  c
	add c,     1
	jfa filla {0x1A00}
	jfa waitl {5}
	mov [x2],  c
	add c,     1
	jfa filla {0x1A80}
	jfa waitl {5}
	mov [x2],  c
	add c,     1
	jfa filla {0x1B00}
	jfa waitl {5}
	mov [x2],  c
	add c,     1
	jfa filla {0x1B80}
	jfa waitl {5}
	mov [x2],  c
	and x2,    0x7FFF
	jmr home

;
; Fill audio buffer with data block from parameter, must be on 128 word
; boundary
;

filla:	mov sp,    5
	mov [bp + 1], a
	mov [bp + 2], x0
	mov [bp + 3], x1
	mov [bp + 4], xm
	mov xm0,   PTR16I
	mov xm1,   PTR16I
	mov x0,    0x1000	; Target: the audio buffer
	mov x1,    [bp + 0]	; Source: the parameter

.l0:	mov a,     [x1]
	mov [x0],  a
	mov a,     x1
	and a,     0x007F
	xne a,     0
	sub x1,    0x0080	; Wrap around source
	xeq x0,    0x1800	; Fill the audio buffer fully
	jmr .l0

	mov a,     [bp + 1]
	mov x0,    [bp + 2]
	mov x1,    [bp + 3]
	mov xm,    [bp + 4]
	rfn

;
; Busy loop waiting
;

waitl:	mov sp,    3
	mov [bp + 1], a
	mov [bp + 2], b
	mov a,     0

.l0:	mov b,     0
.l1:	add b,     1
	xeq b,     0
	jmr .l1			; Inner loop: 15 * 64K cycles: ~1M
	add a,     1
	xeq a,     [bp + 0]
	jmr .l0

	mov a,     [bp + 1]
	mov b,     [bp + 2]
	rfn
