;
; RRPGE User Library functions - PRAM pointer assistance
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
; Generic PRAM pointer setup
;
; Param0: Target pointer (only low 2 bits used)
; Param1: Start bit(!) address, high
; Param2: Start bit(!) address, low
; Param3: Increment high (in bit units)
; Param4: Increment low (in bit units)
; Param5: Data unit size & Increment on write only flag
; Ret.X3: Points to the Px_RW register of the pointer
; Pet. C: Points to the Px_RW_NI register of the pointer
;
; XM3 is assumed to be PTR16I.
;
us_ptr_setgen:
	jma us_ptr_setgen_i



;
; Generic 16 bit PRAM pointer setup
;
; Param0: Target pointer (only low 2 bits used)
; Param1: Start word address, high
; Param2: Start word address, low
; Param3: Increment high (in word units)
; Param4: Increment low (in word units)
; Ret.X3: Points to the Px_RW register of the pointer
; Pet. C: Points to the Px_RW_NI register of the pointer
;
; XM3 is assumed to be PTR16I.
;
us_ptr_setgen16i:
	jma us_ptr_setgen16i_i



;
; Generic 16 bit PRAM pointer setup for increment on write
;
; Param0: Target pointer (only low 2 bits used)
; Param1: Start word address, high
; Param2: Start word address, low
; Param3: Increment high (in word units)
; Param4: Increment low (in word units)
; Ret.X3: Points to the Px_RW register of the pointer
; Pet. C: Points to the Px_RW_NI register of the pointer
;
; XM3 is assumed to be PTR16I.
;
us_ptr_setgen16w:
	jma us_ptr_setgen16w_i



;
; Sets up PRAM pointer for incrementing 16 bit access
;
; Param0: Target pointer (only low 2 bits used)
; Param1: Start word address, high
; Param2: Start word address, low
; Ret.X3: Points to the Px_RW register of the pointer
; Pet. C: Points to the Px_RW_NI register of the pointer
;
; XM3 is assumed to be PTR16I.
;
us_ptr_set16i:
	jma us_ptr_set16i_i



;
; Sets up PRAM pointer for increment on write 16 bit access
;
; Param0: Target pointer (only low 2 bits used)
; Param1: Start word address, high
; Param2: Start word address, low
; Ret.X3: Points to the Px_RW register of the pointer
; Pet. C: Points to the Px_RW_NI register of the pointer
;
; XM3 is assumed to be PTR16I.
;
us_ptr_set16w:
	jma us_ptr_set16w_i



;
; Sets up PRAM pointer for incrementing 8 bit access
;
; Param0: Target pointer (only low 2 bits used)
; Param1: Start bit(!) address, high
; Param2: Start bit(!) address, low
; Ret.X3: Points to the Px_RW register of the pointer
; Pet. C: Points to the Px_RW_NI register of the pointer
;
; XM3 is assumed to be PTR16I.
;
us_ptr_set8i:
	jma us_ptr_set8i_i



;
; Sets up PRAM pointer for increment on write 8 bit access
;
; Param0: Target pointer (only low 2 bits used)
; Param1: Start bit(!) address, high
; Param2: Start bit(!) address, low
; Ret.X3: Points to the Px_RW register of the pointer
; Pet. C: Points to the Px_RW_NI register of the pointer
;
; XM3 is assumed to be PTR16I.
;
us_ptr_set8w:
	jma us_ptr_set8w_i



;
; Sets up PRAM pointer for incrementing 4 bit access
;
; Param0: Target pointer (only low 2 bits used)
; Param1: Start bit(!) address, high
; Param2: Start bit(!) address, low
; Ret.X3: Points to the Px_RW register of the pointer
; Pet. C: Points to the Px_RW_NI register of the pointer
;
; XM3 is assumed to be PTR16I.
;
us_ptr_set4i:
	jma us_ptr_set4i_i



;
; Sets up PRAM pointer for increment on write 4 bit access
;
; Param0: Target pointer (only low 2 bits used)
; Param1: Start bit(!) address, high
; Param2: Start bit(!) address, low
; Ret.X3: Points to the Px_RW register of the pointer
; Pet. C: Points to the Px_RW_NI register of the pointer
;
; XM3 is assumed to be PTR16I.
;
us_ptr_set4w:
	jma us_ptr_set4w_i



;
; Sets up PRAM pointer for incrementing 2 bit access
;
; Param0: Target pointer (only low 2 bits used)
; Param1: Start bit(!) address, high
; Param2: Start bit(!) address, low
; Ret.X3: Points to the Px_RW register of the pointer
; Pet. C: Points to the Px_RW_NI register of the pointer
;
; XM3 is assumed to be PTR16I.
;
us_ptr_set2i:
	jma us_ptr_set2i_i



;
; Sets up PRAM pointer for increment on write 2 bit access
;
; Param0: Target pointer (only low 2 bits used)
; Param1: Start bit(!) address, high
; Param2: Start bit(!) address, low
; Ret.X3: Points to the Px_RW register of the pointer
; Pet. C: Points to the Px_RW_NI register of the pointer
;
; XM3 is assumed to be PTR16I.
;
us_ptr_set2w:
	jma us_ptr_set2w_i



;
; Sets up PRAM pointer for incrementing bit access
;
; Param0: Target pointer (only low 2 bits used)
; Param1: Start bit address, high
; Param2: Start bit address, low
; Ret.X3: Points to the Px_RW register of the pointer
; Pet. C: Points to the Px_RW_NI register of the pointer
;
; XM3 is assumed to be PTR16I.
;
us_ptr_set1i:
	jma us_ptr_set1i_i



;
; Sets up PRAM pointer for increment on write bit access
;
; Param0: Target pointer (only low 2 bits used)
; Param1: Start bit address, high
; Param2: Start bit address, low
; Ret.X3: Points to the Px_RW register of the pointer
; Pet. C: Points to the Px_RW_NI register of the pointer
;
; XM3 is assumed to be PTR16I.
;
us_ptr_set1w:
	jma us_ptr_set1w_i



;
; Implementation of us_ptr_setgen
;
us_ptr_setgen_i:

.ptr	equ	0		; Target pointer
.adh	equ	1		; Start bit address, high
.adl	equ	2		; Start bit address, low
.inh	equ	3		; Increment, high
.inl	equ	4		; Increment, low
.dus	equ	5		; Data unit size & Increment on write only

	; Calculate pointer register start offset

	mov x3,    [$.ptr]
	and x3,    3
	shl x3,    3
	add x3,    P0_AH	; Pointer register start acquired

	; Populate PRAM pointer

	mov c,     [$.adh]
	mov [x3],  c		; Address high
	mov c,     [$.adl]
	mov [x3],  c		; Address low
	mov c,     [$.inh]
	mov [x3],  c		; Increment high
	mov c,     [$.inl]
	mov [x3],  c		; Increment low
	mov c,     [$.dus]
	mov [x3],  c		; Data unit size
	add x3,    1		; To register Px_RW_NI
	mov c,     x3		; Return: Px_RW_NI
	add x3,    1		; Return: Px_RW

	; Done

	rfn



;
; Implementation of us_ptr_setgen16i
;
us_ptr_setgen16i_i:

.ptr	equ	0		; Target pointer
.adh	equ	1		; Start bit address, high
.adl	equ	2		; Start bit address, low
.inh	equ	3		; Increment, high
.inl	equ	4		; Increment, low

	; Prepare data unit size in x3

	mov x3,    0x4		; Data unit size: 16 bits

.en16:	; Entry point for us_ptr_setgen16w_i

	; Load word address components, saving registers

	xch a,     [$.adh]
	xch b,     [$.adl]
	shl c:b,   4
	slc a,     4		; Calculate bit offset
	xch x0,    [$.inh]
	xch x1,    [$.inl]
	shl c:x1,  4
	slc x0,    4		; Calculate bit offset

	; Calculate pointer register start offset

	mov c,     x3		; Data unit size
	mov x3,    [$.ptr]
	and x3,    3
	shl x3,    3
	add x3,    P0_AH	; Pointer register start acquired

	; Populate PRAM pointer

	mov [x3],  a		; Address high
	mov [x3],  b		; Address low
	mov [x3],  x0		; Increment high
	mov [x3],  x1		; Increment low
	mov [x3],  c		; Data unit size
	add x3,    1		; To register Px_RW_NI
	mov c,     x3		; Return: Px_RW_NI
	add x3,    1		; Return: Px_RW

	; Restore & exit

	mov a,     [$.adh]
	mov b,     [$.adl]
	mov x0,    [$.inh]
	mov x1,    [$.inl]
	rfn



;
; Implementation of us_ptr_setgen16w
;
us_ptr_setgen16w_i:

.ptr	equ	0		; Target pointer
.adh	equ	1		; Start bit address, high
.adl	equ	2		; Start bit address, low
.inh	equ	3		; Increment, high
.inl	equ	4		; Increment, low

	; Prepare data unit size in x3 & pass over

	mov x3,    0xC		; Data unit size: 16 bits, increment on write only
	jms us_ptr_setgen16i_i.en16



;
; Implementation of us_ptr_set16i
;
us_ptr_set16i_i:

.ptr	equ	0		; Target pointer
.adh	equ	1		; Start word address, high
.adl	equ	2		; Start word address, low

	; Prepare data unit size in x3

	mov x3,    0x4		; Data unit size: 16 bits

.en16:	; Entry point for us_ptr_set16w_i

	; Load word address components, saving registers 'a' and 'b'

	xch a,     [$.adh]
	xch b,     [$.adl]
	shl c:b,   4
	slc a,     4		; Calculate bit offset

.entr:	; Entry point for us_ptr_set8i_i

	; Calculate pointer register start offset

	mov c,     x3		; Data unit size
	mov x3,    [$.ptr]
	and x3,    3
	shl x3,    3
	add x3,    P0_AH	; Pointer register start acquired

	; Populate PRAM pointer

	mov [x3],  a		; Address high
	mov [x3],  b		; Address low
	mov a,     0
	mov [x3],  a		; Increment high
	mov a,     1
	mov b,     c
	and b,     7		; Data unit size: 0 - 4
	shl a,     b		; Increment: 1, 2, 4, 8 or 16 (bits)
	mov [x3],  a		; Increment low
	mov [x3],  c		; Data unit size
	add x3,    1		; To register Px_RW_NI
	mov c,     x3		; Return: Px_RW_NI
	add x3,    1		; Return: Px_RW

	; Restore & exit

	mov a,     [$.adh]
	mov b,     [$.adl]
	rfn



;
; Implementation of us_ptr_set16w
;
us_ptr_set16w_i:

.ptr	equ	0		; Target pointer
.adh	equ	1		; Start word address, high
.adl	equ	2		; Start word address, low

	; Prepare data unit size in x3 & pass over

	mov x3,    0xC		; Data unit size: 16 bits, increment on write only
	jms us_ptr_set16i_i.en16



;
; Implementation of us_ptr_set8i
;
us_ptr_set8i_i:

.ptr	equ	0		; Target pointer
.adh	equ	1		; Start bit address, high
.adl	equ	2		; Start bit address, low

	; Prepare data unit size in x3

	mov x3,    0x3		; Data unit size: 8 bits

.entr:  ; Entry point for all other routines

	; Load address & save registers, then pass over

	xch a,     [$.adh]
	xch b,     [$.adl]
	jms us_ptr_set16i_i.entr



;
; Implementation of us_ptr_set8w
;
us_ptr_set8w_i:

.ptr	equ	0		; Target pointer
.adh	equ	1		; Start bit address, high
.adl	equ	2		; Start bit address, low

	; Prepare data unit size in x3 & pass over

	mov x3,    0xB		; Data unit size: 8 bits, increment on write only
	jms us_ptr_set8i_i.entr



;
; Implementation of us_ptr_set4i
;
us_ptr_set4i_i:

.ptr	equ	0		; Target pointer
.adh	equ	1		; Start bit address, high
.adl	equ	2		; Start bit address, low

	; Prepare data unit size in x3 & pass over

	mov x3,    0x2		; Data unit size: 4 bits
	jms us_ptr_set8i_i.entr



;
; Implementation of us_ptr_set4w
;
us_ptr_set4w_i:

.ptr	equ	0		; Target pointer
.adh	equ	1		; Start bit address, high
.adl	equ	2		; Start bit address, low

	; Prepare data unit size in x3 & pass over

	mov x3,    0xA		; Data unit size: 4 bits, increment on write only
	jms us_ptr_set8i_i.entr



;
; Implementation of us_ptr_set2i
;
us_ptr_set2i_i:

.ptr	equ	0		; Target pointer
.adh	equ	1		; Start bit address, high
.adl	equ	2		; Start bit address, low

	; Prepare data unit size in x3 & pass over

	mov x3,    0x1		; Data unit size: 2 bits
	jms us_ptr_set8i_i.entr



;
; Implementation of us_ptr_set2w
;
us_ptr_set2w_i:

.ptr	equ	0		; Target pointer
.adh	equ	1		; Start bit address, high
.adl	equ	2		; Start bit address, low

	; Prepare data unit size in x3 & pass over

	mov x3,    0x9		; Data unit size: 2 bits, increment on write only
	jms us_ptr_set8i_i.entr



;
; Implementation of us_ptr_set1i
;
us_ptr_set1i_i:

.ptr	equ	0		; Target pointer
.adh	equ	1		; Start bit address, high
.adl	equ	2		; Start bit address, low

	; Prepare data unit size in x3 & pass over

	mov x3,    0x0		; Data unit size: 1 bit
	jms us_ptr_set8i_i.entr



;
; Implementation of us_ptr_set1w
;
us_ptr_set1w_i:

.ptr	equ	0		; Target pointer
.adh	equ	1		; Start bit address, high
.adl	equ	2		; Start bit address, low

	; Prepare data unit size in x3 & pass over

	mov x3,    0x8		; Data unit size: 1 bit, increment on write only
	jms us_ptr_set8i_i.entr
