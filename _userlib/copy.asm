;
; RRPGE User Library functions - Copy
;
; Author    Sandor Zsuga (Jubatian)
; Copyright 2013 - 2014, GNU GPLv3 (version 3 of the GNU General Public
;           License) extended as RRPGEvt (temporary version of the RRPGE
;           License): see LICENSE.GPLv3 and LICENSE.RRPGEvt in the project
;           root.
;

include "../rrpge.asm"

section code


;
; PRAM <= CPU RAM copy
;
; Copies an arbitrary amount of words from CPU RAM to PRAM. Uses PRAM pointer
; 3 for this (not preserved).
;
; Param0: Target PRAM word address, high
; Param1: Target PRAM word address, low
; Param2: Source CPU RAM word address
; Param3: Count of words to copy (0 is also valid)
;
; Registers C and X3 are not preserved.
;
us_copy_pfc:
	jma us_copy_pfc_i



;
; CPU RAM <= PRAM copy
;
; Copies an arbitrary amount of words from PRAM to CPU RAM. Uses PRAM pointer
; 3 for this (not preserved).
;
; Param0: Target CPU RAM word address
; Param1: Source PRAM word address, high
; Param2: Source PRAM word address, low
; Param3: Count of words to copy (0 is also valid)
;
; Registers C and X3 are not preserved.
;
us_copy_cfp:
	jma us_copy_cfp_i



;
; CPU RAM <= CPU RAM copy
;
; Copies an arbitrary amount of words within CPU RAM.
;
; Param0: Target CPU RAM word address
; Param1: Source CPU RAM word address
; Param2: Count of words to copy (0 is also valid)
;
; Registers C and X3 are not preserved.
;
us_copy_cfc:
	jma us_copy_cfc_i



;
; PRAM <= PRAM copy
;
; Copies an arbitrary amount of words within PRAM. Uses PRAM pointer 2 and 3
; for this (not preserved). Up to 65535 words may be copied at once.
;
; Param0: Target PRAM word address, high
; Param1: Target PRAM word address, low
; Param1: Source PRAM word address, high
; Param2: Source PRAM word address, low
; Param3: Count of words to copy (0 is also valid)
;
; Registers C and X3 are not preserved.
;
us_copy_pfp:
	jma us_copy_pfp_i



;
; Implementation of us_copy_pfc
;
us_copy_pfc_i:

.tgh	equ	0		; Target (PRAM), high
.tgl	equ	1		; Target (PRAM), low
.src	equ	2		; Source (CPU RAM)
.len	equ	3		; Count of words

	; Set up target (Peripheral RAM pointer)

	mov x3,    [$.tgl]
	shl c:x3,  4
	mov [P3_AL], x3
	mov x3,    [$.tgh]
	slc x3,    4
	mov [P3_AH], x3
	mov x3,    0
	mov [P3_IH], x3
	bts x3,    4		; Increment: 16
	mov [P3_IL], x3
	mov x3,    4		; Data unit size: 16 bits
	mov [P3_DS], x3

	; Set up source & length

	mov x3,    [$.src]
	mov c,     [$.len]

	; Some register pushing around

	mov [$1],  x2		; Save 'x2' to be restored later
	mov x2,    P3_RW	; Save a word & 1 cycle for each copy
	mov [$2],  xm		; Save 'xm' to be restored later
	mov xm,    0x6466	; x3: PTR16I, x2: PTR16

	; Common copy loop & return implementation 'x2' must be saved to
	; [bp + 1], 'xm' to [bp + 2], and set up appropriately before
	; jumping here.

us_copy_lp:

	; Copy loop preparation

	mov [$0],  a		; Save 'a' to be restored later

	xbs c,     2		; Bit 2 set for length?
	jms .l2
	mov a,     [x3]
	mov [x2],  a
	mov a,     [x3]
	mov [x2],  a
	mov a,     [x3]
	mov [x2],  a
	mov a,     [x3]
	mov [x2],  a
	sub c,     4
.l2:	xbs c,     1		; Bit 1 set for length?
	jms .l1
	mov a,     [x3]
	mov [x2],  a
	mov a,     [x3]
	mov [x2],  a
	sub c,     2
.l1:	xbs c,     0		; Bit 0 set for length?
	jms .l0
	mov a,     [x3]
	mov [x2],  a
	sub c,     1
.l0:				; Length is divisable by 8 here

	; Copy loop

	xne c,     0
	jms .le
.lp:	mov a,     [x3]
	mov [x2],  a
	mov a,     [x3]
	mov [x2],  a
	mov a,     [x3]
	mov [x2],  a
	mov a,     [x3]
	mov [x2],  a
	mov a,     [x3]
	mov [x2],  a
	mov a,     [x3]
	mov [x2],  a
	mov a,     [x3]
	mov [x2],  a
	mov a,     [x3]
	mov [x2],  a
	sub c,     8
	xeq c,     0
	jms .lp			; About 10cy/copy even for PRAM<=>PRAM.
.le:

	; Restore & Exit

	mov a,     [$0]
	mov x2,    [$1]
	mov xm,    [$2]
	rfn



;
; Implementation of us_copy_cfp
;
us_copy_cfp_i:

.trg	equ	0		; Target (CPU RAM)
.srh	equ	1		; Source (PRAM), high
.srl	equ	2		; Source (PRAM), low
.len	equ	3		; Count of words

	; Set up source (Peripheral RAM pointer)

	mov x3,    [$.srl]
	shl c:x3,  4
	mov [P3_AL], x3
	mov x3,    [$.srh]
	slc x3,    4
	mov [P3_AH], x3
	mov x3,    0
	mov [P3_IH], x3
	bts x3,    4		; Increment: 16
	mov [P3_IL], x3
	mov x3,    4		; Data unit size: 16 bits
	mov [P3_DS], x3

	; Set up target & length

	mov x3,    [$.trg]
	mov c,     [$.len]

	; Some register pushing around

	mov [$1],  x2		; Save 'x2' to be restored later
	mov x2,    P3_RW	; Save a word & 1 cycle for each copy
	xch x2,    x3
	mov [$2],  xm		; Save 'xm' to be restored later
	mov xm,    0x4666	; x3: PTR16, x2: PTR16I

	; To common copy

	jms us_copy_lp



;
; Implementation of us_copy_cfc
;
us_copy_cfc_i:

.trg	equ	0		; Target (CPU RAM)
.src	equ	1		; Source (CPU RAM)
.len	equ	2		; Count of words

	; Set up regs for jump

	mov x3,    [$.src]
	mov [$1],  x2		; Save 'x2' to be restored later (.src)
	mov x2,    [$.trg]
	mov c,     [$.len]
	mov [$2],  xm		; Save 'xm' to be restored later
	mov xm,    0x6666	; x3: PTR16I, x2: PTR16I

	; To common copy

	jms us_copy_lp



;
; Implementation of us_copy_pfp
;
us_copy_pfp_i:

.tgh	equ	0		; Target (PRAM), high
.tgl	equ	1		; Target (PRAM), low
.srh	equ	2		; Source (PRAM), high
.srl	equ	3		; Source (PRAM), low
.len	equ	4		; Count of words

	; Set up source (Peripheral RAM pointer)

	mov x3,    [$.srl]
	shl c:x3,  4
	mov [P3_AL], x3
	mov x3,    [$.srh]
	slc x3,    4
	mov [P3_AH], x3
	mov x3,    0
	mov [P3_IH], x3
	bts x3,    4		; Increment: 16
	mov [P3_IL], x3
	mov x3,    4		; Data unit size: 16 bits
	mov [P3_DS], x3

	; Set up target (Peripheral RAM pointer)

	mov x3,    [$.tgl]
	shl c:x3,  4
	mov [P2_AL], x3
	mov x3,    [$.tgh]
	slc x3,    4
	mov [P2_AH], x3
	mov x3,    0
	mov [P2_IH], x3
	bts x3,    4		; Increment: 16
	mov [P2_IL], x3
	mov x3,    4		; Data unit size: 16 bits
	mov [P2_DS], x3

	; Set up length

	mov c,     [$.len]

	; Some register pushing around

	mov [$1],  x2		; Save 'x2' to be restored later
	mov x3,    P3_RW	; Save a word & 1 cycle for each copy
	mov x2,    P2_RW
	mov [$2],  xm		; Save 'xm' to be restored later
	mov xm,    0x4466	; x3: PTR16, x2: PTR16

	; To common copy

	jms us_copy_lp
