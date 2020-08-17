;**************************************************************************
;*
;* FILE  runner.asm
;* Copyright (c) 1994, 2001, 2003 Daniel Kahlin <daniel@kahlin.net>
;* Written by Daniel Kahlin <daniel@kahlin.net>
;* $Id: runner.asm,v 1.12 2003/08/26 16:51:38 tlr Exp $
;*
;* DESCRIPTION
;*   runner for packed vic-tracker tunes.  Uses player.asm.
;*   Works on both unexpanded and expanded VIC-20s.
;*
;******
	PROCESSOR 6502

; song configuration.
NUMSONGS	EQU	1
TITLE		EQM	"SLOWRIDE      "
AUTHOR		EQM	"DANIEL KAHLIN "
VERSION		EQM	"2.0"

; macros 
	MAC	HEXDIGIT
	IFCONST [{1}]
	IF	[{1}]<10
	dc.b	"0"+[{1}]
	ELSE
	dc.b	"A"+[{1}]-10
	ENDIF
	ELSE
	dc.b	"x"
	ENDIF
	ENDM

	MAC	HEXWORD
	HEXDIGIT [{1}]>>12
	HEXDIGIT [[{1}]>>8]&$0f
	HEXDIGIT [[{1}]>>4]&$0f
	HEXDIGIT [{1}]&$0f
	ENDM


BorderColor	 EQU	6
BorderColor_Play EQU	3
BackgroundColor	 EQU	14
NormalColor	EQU	[BackgroundColor<<4]+BorderColor+8
PlayColor	EQU	[BackgroundColor<<4]+BorderColor_Play+8

INFO_POS	EQU	7
INFO_HEIGHT	EQU	6

BONUS_POS	EQU	15

;the length of a screen in cycles (PAL)
SCREENTIME_PAL		EQU	22150
;the length of a screen in cycles (NTSC)
SCREENTIME_NTSC		EQU	16963
STARTLINE	EQU	74+8*6
STARTLINE_PAL		EQU	STARTLINE
STARTLINE_NTSC		EQU	STARTLINE-24
	
rn_ScreenRAM	EQU	$1e00
rn_ColorRAM	EQU	$9600

rn_CopyZP	EQU	$fb	;only used during copy down
rn_ScreenZP	EQU	$d1
rn_ColorZP	EQU	$fd
rn_YPosZP	EQU	$ff
rn_YTempZP	EQU	$fb
rn_XTempZP	EQU	$fc

	seg	code
	org	$1201		; Normal 8,16,24Kb basic starting point
rn_LoadStart:
;**************************************************************************
;*
;* Basic line!
;*
;******
TOKEN_SYS	EQU	$9e
TOKEN_PEEK	EQU	$c2
TOKEN_PLUS	EQU	$aa
TOKEN_TIMES	EQU	$ac
StartOfFile:
	dc.w	EndLine
	dc.w	2003
	dc.b	TOKEN_SYS,"(",TOKEN_PEEK,"(43)",TOKEN_PLUS,"256",TOKEN_TIMES,TOKEN_PEEK,"(44)",TOKEN_PLUS,"36) /T.L.R/",0
;	     2003 SYS(PEEK(43)+256*PEEK(44)+36) /T.L.R/
EndLine:
	dc.w	0
	
;**************************************************************************
;*
;* SysAddress... When run we will enter here!
;*
;******
startoffset	EQU	cp_store-StartOfFile
endoffset	EQU	startoffset+(cp_end-cp_start)
startoffset2	EQU	rn_MainStart_st-StartOfFile
SysAddress:
	sei
	ldy	#startoffset
sa_lp1:
	lda	($2b),y
	sta	cp_start-startoffset,y
	iny
	cpy	#endoffset
	bne	sa_lp1
	lda	$2b
	clc
	adc	#<startoffset2
	sta	rn_CopyZP
	lda	$2c
	adc	#>startoffset2
	sta	rn_CopyZP+1
	jmp	cp_start

cp_store:	
	rorg	$200
cp_start:
	ldy	#0
cp_lp1:	
	lda	(rn_CopyZP),y
cp_lp2:	
	sta	rn_Main,y
	iny
	bne	cp_skp1
	inc	rn_CopyZP+1
	inc	cp_lp2+2
cp_skp1:
	lda	cp_lp2+2
	cmp	#>rn_MainEnd
	bne	cp_lp1
	cpy	#<rn_MainEnd
	bne	cp_lp1
	jmp	rn_Main
cp_end:	
	rend
	echo	"copydown", cp_start, "-", cp_end

rn_MainStart_st:
	rorg	$1000
;**************************************************************************
;*
;* This is the main program!
;*
;******
rn_Main:
	jsr	InterruptInit
	jsr	rn_InitScreen
rn_Restart:
	lda	#0
	sta	pl_PlayFlag
rn_mn_Toggle:
	lda	pl_PlayFlag
	pha
	lda	rn_ThisSong
	jsr	pl_Init
	pla
	eor	#$ff
	sta	pl_PlayFlag
	beq	rn_mn_lp1
	lda	#0
	sta	rn_MaxLines

rn_mn_lp1:
	jsr	$ffe4
	beq	rn_mn_lp1
	cmp	#" "
	beq	rn_mn_Toggle
	cmp	#"P"
	beq	rn_mn_Toggle
	cmp	#"M"
	beq	rn_Restart
	cmp	#"1"		;Less than "1"
	bcc	rn_mn_lp1	;yes, loop.
	cmp	#"1"+NUMSONGS	;Greater than NUMSONGS
	bcs	rn_mn_lp1	;yes, loop.
rn_mn_StartSong:
	sec
	sbc	#"1"
	sta	rn_ThisSong
	jmp	rn_Restart

;**************************************************************************
;*
;* Initialize Interrupts!
;*
;******
InterruptInit:
	sei
	lda	#$7f
	sta	$912e
	sta	$912d
	lda	#%11000000	; T1 Interrupt Enabled
	sta	$912e
	lda	#%01000000
	sta	$912b
	lda	#<IRQServer
	sta	$0314
	lda	#>IRQServer
	sta	$0315

	jsr	CheckPAL
	php
	ldx	#<SCREENTIME_PAL
	ldy	#>SCREENTIME_PAL
	lda	#STARTLINE_PAL/2
	plp
	bne	ii_skp1
	ldx	#<SCREENTIME_NTSC
	ldy	#>SCREENTIME_NTSC
	lda	#STARTLINE_NTSC/2
ii_skp1:	
	jsr	WaitLine
	stx	$9124
	sty	$9125	;load T1
	cli
	rts


;**************************************************************************
;*
;* CheckPAL
;* Returns:	 Acc=0 on NTSC-M systems, Acc!=0 on PAL-B systems
;*
;******
CheckPAL:
; find raster line 2
	lda	#2/2
cpl_lp1:
	cmp	$9004
	bne	cpl_lp1
; now we know that we are past raster line 0, see if we find raster line 268
; before we find raster line 0
cpl_lp2:	
	lda	$9004
	beq	cpl_ex1
	cmp	#268/2		; This line does not exist on NTSC.
	bne	cpl_lp2
cpl_ex1:	
	cmp	#0		; test Acc;
	rts

;**************************************************************************
;*
;* Wait until line ACC is passed
;*
;******
WaitLine:
wl_lp1:
	cmp	$9004
	bne	wl_lp1
wl_lp2:
	cmp	$9004
	beq	wl_lp2
	rts


;**************************************************************************
;*
;* IRQ Interrupt server
;*
;******
IRQServer:
	lda	$912d
	asl
	asl
	bcs	irq_skp1		;Did T1 time out?
	jmp	$eabf
irq_skp1:
	jsr	rn_Frame	;Yes, run player.
	lda	$9124		;ACK T1 interrupt.
irq_ex1:
	jmp	$eabf
	

;**************************************************************************
;*
;* Interrupt Routine
;* This gets called every frame!
;*
;******
rn_Frame:
	lda	#PlayColor
	sta	$900f
	lda	$9004		;Rasterline
	sta	rn_Lines
	jsr	pl_Play
	lda	$9004		;Rasterline
	sec
	sbc	rn_Lines
	asl	; multiply by two 
	sta	rn_Lines
	cmp	rn_MaxLines
	bcc	rn_fr_skp2
	sta	rn_MaxLines
rn_fr_skp2:
; if we are not playing, wait a while to ensure that the color is visible
	lda	pl_PlayFlag
	bne	rn_fr_skp1
	ldx	#10
rn_fr_lp1:
	dex
	bne	rn_fr_lp1
rn_fr_skp1:

	lda	#NormalColor
	sta	$900f

	jsr	rn_ShowData

	rts


;**************************************************************************
;*
;* This displays all other data!
;*
;******
rn_ShowData:
;Show number of raster lines
	ldx	#<[rn_ScreenRAM+[22*[INFO_POS+5]]]
	ldy	#>[rn_ScreenRAM+[22*[INFO_POS+5]]]
	jsr	rn_ScreenPtr
	ldy	#9
	sty	rn_YPosZP
	lda	rn_Lines
	jsr	rn_PutHex
	ldy	#18
	sty	rn_YPosZP
	lda	rn_MaxLines
	jsr	rn_PutHex



rn_ScreenPtr:
	stx	rn_ScreenZP
	sty	rn_ScreenZP+1
	rts
rn_PutHex:
	sty	rn_YTempZP
	stx	rn_XTempZP
	pha
	lsr
	lsr
	lsr
	lsr
	jsr	rn_ph_Put
	pla
	and	#$0f
	jsr	rn_ph_Put
	ldx	rn_XTempZP
	ldy	rn_YTempZP
	rts
rn_ph_Put:
	tax
	ldy	rn_YPosZP
	lda	rn_HexTab,x
	sta	(rn_ScreenZP),y
	inc	rn_YPosZP
	rts

rn_HexTab:
	dc.b	"0123456789",1,2,3,4,5,6

rn_ThisSong:
	dc.b	0
rn_Lines:
	dc.b	0
rn_MaxLines:
	dc.b	0

rn_InitScreen:
; screenmem at $1e00, colormem at $9600
	lda	$9002
	ora	#$80
	sta	$9002
	lda	#$f0
	sta	$9005

	lda	#NormalColor
	sta	$900f
	
	ldx	#0
rn_is_lp1:
	lda	#$a0
	sta	rn_ScreenRAM,x
	sta	rn_ScreenRAM+$100,x
	lda	#6
	sta	rn_ColorRAM,x
	sta	rn_ColorRAM+$100,x
	inx
	bne	rn_is_lp1


	ldx	#22-1
rn_is_lp4:
	lda	#$20
	sta	rn_ScreenRAM+22*6,x
	sta	rn_ScreenRAM+22*13,x
	lda	rn_Bonus_MSG,x
	and	#$3f
	ora	#$80
	sta	rn_ScreenRAM+22*BONUS_POS,x
	dex
	bpl	rn_is_lp4

	ldx	#22*INFO_HEIGHT
rn_is_lp5:
	lda	rn_Info_MSG-1,x
	and	#$3f
	sta	rn_ScreenRAM+22*INFO_POS-1,x
	lda	#1
	sta	rn_ColorRAM+22*INFO_POS-1,x
	dex
	bne	rn_is_lp5
	rts
	
rn_Info_MSG:
; line1
	dc.b	"TITLE : "
	dc.b	TITLE
; line2
	dc.b	"AUTHOR: "
	dc.b	AUTHOR
; line3
	dc.b	"SONGS : "
	HEXDIGIT NUMSONGS
	IF NUMSONGS>1
	dc.b	" (1-"
	HEXDIGIT NUMSONGS
	dc.b	")       "
	ELSE
	dc.b	"             "
	ENDIF	
; line4
	dc.b	"ADDR  : $"
	HEXWORD start
	dc.b	"-$"
	HEXWORD end
	dc.b	"   "
; line5
	dc.b	"LENGTH: $"
	HEXWORD end-start
	dc.b	"         "
; line6
	dc.b	"LINES : $00 (MAX $00) "
	

rn_Bonus_MSG:
	dc.b	"    VIC-PLAYER "
	dc.b	VERSION
	dc.b	"    "


start:
	include	"slowride.asm"
end:
rn_MainEnd:
	rend
rn_LoadEnd:
	echo	"Player: ",start,"-",end,"(=",end-start,"bytes,",(end-start+253)/254,"blocks)"
	echo	"Load: ",rn_LoadStart,"-",rn_LoadEnd,"(=",rn_LoadEnd-rn_LoadStart,"bytes,",(rn_LoadEnd-rn_LoadStart+253)/254,"blocks)"
; eof

