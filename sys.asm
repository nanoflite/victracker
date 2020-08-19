;**************************************************************************
;*
;* FILE  sys.asm
;* Copyright (c) 2001, 2003 Daniel Kahlin <daniel@kahlin.net>
;* Written by Daniel Kahlin <daniel@kahlin.net>
;* $Id: sys.asm,v 1.13 2003/08/09 12:04:01 tlr Exp $
;*
;* DESCRIPTION
;*   This is the sysline
;*
;******

RELYEAR EQU "2004-10-02" 

  PROCESSOR 6502
	include "include/macros.i"
	include "include/vic20.i"
	
	seg	code
	org	$1201

asm_start:

;**************************************************************************
;*
;* Basic line!
;*
;******
StartOfFile:
	dc.w	EndLine
	dc.w	RELYEAR
	dc.b	TOKEN_SYS,"(",TOKEN_PEEK,"(43)",TOKEN_PLUS,"256",TOKEN_TIMES,TOKEN_PEEK,"(44)",TOKEN_PLUS,"36) /T.L.R/",0
;	     200x SYS(PEEK(43)+256*PEEK(44)+36) /T.L.R/
EndLine:
	dc.w	0
	
;**************************************************************************
;*
;* SysAddress... When run we will enter here!
;*
;******
SysAddress:
; check if we are running on a vic-20 here
; by checking the basic rom.
	lda	$c002
	cmp	#$67
	bne	sa_print2
	lda	$c003
	cmp	#$e4
	bne	sa_print2
	lda	$c00c
	cmp	#$30
	bne	sa_print2
	lda	$c00d
	cmp	#$c8
	bne	sa_print2
	

; get memtop and calculate start-page
	sec
	jsr	$ff99	;MEMTOP
	tya
	cmp	#$5c
	bcc	sa_print	; Memtop less than $5c00

; all ok, do it.
	jmp	CopyDown

sa_print2:
	ldy	#<[mem2_msg-asm_start]
	dc.b	$2c		; bit $xxxx
sa_print:
	ldy	#<[mem_msg-asm_start]
sa_lp1:	
	lda	($2b),y
	iny
	jsr	$ffd2
	bne	sa_lp1

;
; 'READY.' has already been printed.
; set direct mode,
; set stack and jump through the basic main loop vector
;
	lda	#$80
	jsr	$ff90   ;SETMSG
	ldx	#$fa
	txs
	jmp	($0302) ;IMAIN

mem2_msg:
	dc.b	13,"THIS IS NOT A VIC-20!",13
mem_msg:	
	dc.b	13,"VIC-TRACKER ONLY RUNS",13
	dc.b	"ON A VIC-20 WITH 16KB",13
	dc.b	"MEMORY OR MORE.",13
	dc.b	13,"READY.",13,0	
asm_end:

	IFCONST LENCHECK
CopyDown	EQU	$1000
	ELSE ;LENCHECK
;**************************************************************************
;*
;* The copy down tail code
;*
;******
TARGET	EQU	$120d
	incbin	"tail.bin"
CopyDown:
	ldx	#head_end-head_start
cd_lp1:
	lda	head_start-1,x
	sta	TARGET-1,x
	dex
	bne	cd_lp1
	jmp	TARGET
head_start:
	incbin	"head.bin"
head_end:

	ENDIF ;!LENCHECK

;**************************************************************************
;*
;* status messages
;*
;******
	SHOWRANGE "syscode",asm_start,asm_end
	SHOWRANGE "head_data",head_start,head_end
; eof
