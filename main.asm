;**************************************************************************
;*
;* FILE  main.asm
;* Copyright (c) 2001, 2003 Daniel Kahlin <daniel@kahlin.net>
;* Written by Daniel Kahlin <daniel@kahlin.net>
;* $Id: main.asm,v 1.9 2003/07/12 10:05:25 tlr Exp $
;*
;* DESCRIPTION
;*   sys + copydown
;*
;******
	PROCESSOR 6502
	include "include/macros.i"

	seg	code
	org	$1700
;**************************************************************************
;*
;* SysAddress... When run we will enter here!
;*
;******
SysAddress:
	jsr	$2000
	ldx	#0
sa_lp1:
	lda	cp_store,x
	sta	cp_start,x
	inx
	cpx	#cp_end-cp_start
	bne	sa_lp1
	jmp	cp_start

cp_store:	
	rorg	$200
cp_start:
	sei
	ldx	#0
cp_lp1:	
	lda	PAYLOAD,x
cp_lp2:	
	sta	$1201,x
	inx
	bne	cp_skp1
	inc	cp_lp1+2
	inc	cp_lp2+2
cp_skp1:
	lda	cp_lp1+2
	cmp	#>PAYLOADEND
	bne	cp_lp1
	cpx	#<PAYLOADEND
	bne	cp_lp1
	cli
	jmp	4629
cp_end:	
	rend

;**************************************************************************
;*
;* linkage
;*
;******
	ds.b	$1800-.,0
	incbin	"intro.bin"
	ds.b	$3800-.,0
PAYLOAD:
	incbin	"musiced.bin"
PAYLOADEND:
	
;**************************************************************************
;*
;* status messages
;*
;******
	SHOWRANGE "copydown",cp_start,cp_end
; eof
