;
; Simple generic full page copy.
;
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEv2 (version 2 of the RRPGE License): see
;           LICENSE.GPLv3 and LICENSE.RRPGEv2 in the project root.
;


include "../rrpge.asm"

section code


;
; Simple generic full page copy routine, capable to copy between any two
; pages, without affecting the page layout for the caller.
;
; param0: destination page
; param1: source page
;
pagecopy:
	mov sp,    10
	mov [bp + 2], xm
	mov [bp + 3], x3
	mov [bp + 4], x2
	mov [bp + 5], a
	mov a,     [ROPD_RBK_14]
	mov [bp + 6], a
	mov a,     [ROPD_WBK_14]
	mov [bp + 7], a
	mov a,     [ROPD_RBK_15]
	mov [bp + 8], a
	mov a,     [ROPD_WBK_15]
	mov [bp + 9], a

	; Bank read & write pages

	jsv {kc_mem_bankwr,   14, 0x4000}	; Neutral page (if 14 was VRAM)
	jsv {kc_mem_bankrd,   14, [bp + 1]}	; Source
	jsv {kc_mem_banksame, 15, [bp + 0]}	; Destination

	; Set up for copying

	mov xm3,   PTR16I
	mov xm2,   PTR16I
	mov x3,    0xF000	; Destination
	mov x2,    0xE000	; Source

	; Copy loop

.l0:	mov a,     [x2]
	mov [x3],  a
	mov a,     [x2]
	mov [x3],  a
	mov a,     [x2]
	mov [x3],  a
	mov a,     [x2]
	mov [x3],  a
	xeq x3,    0		; Wrapped around, so end
	jmr .l0

	; Exit: Restore stuff

	jsv {kc_mem_bank, 14, [bp + 6], [bp + 7]}
	jsv {kc_mem_bank, 15, [bp + 8], [bp + 9]}
	mov a,     [bp + 5]
	mov x2,    [bp + 4]
	mov x3,    [bp + 3]
	mov xm,    [bp + 2]
	rfn
