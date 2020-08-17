;**************************************************************************
;*
;* FILE  strip_test.asm
;* Copyright (c) 2003 Daniel Kahlin <daniel@kahlin.net>
;* Written by Daniel Kahlin <daniel@kahlin.net>
;* $Id: strip_test.asm,v 1.1 2003/05/21 10:14:45 tlr Exp $
;*
;* DESCRIPTION
;*   A test file for strip.pl.
;*
;******
	PROCESSOR 6502
	org	$2000
start:
	sei
st_lp1:	
	lda	#$e0+8
	sta	$900f
	lda	#$e6+8
	sta	$900f
	jmp	st_lp1
	IFCONST	ID
	dc.b	"strip_test.asm",0
	ELSE
	IFNCONST EXTRA
	IF	SOMEOTHERSTUFF
	dc.b	"pront!"
	ELSE
	dc.b	"prunt!"
	EIF
	dc.b	"no id",0
	ELSE
	dc.b	"extra",0
	ENDIF
	ENDIF

; eof

