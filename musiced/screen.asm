;**************************************************************************
;*
;* FILE  screen.asm
;* Copyright (c) 1994, 2001, 2003 Daniel Kahlin <daniel@kahlin.net>
;* Written by Daniel Kahlin <daniel@kahlin.net>
;* $Id: screen.asm,v 1.25 2003/08/26 21:31:38 tlr Exp $
;*
;* DESCRIPTION
;*   handle the main screen
;*
;******

;**************************************************************************
;*
;* Initialize Video!
;*
;******
VideoInit:
	lda	#0
	jsr	WaitLine
	lda	#147		;Clear Screen
	jsr	$ffd2

	ldx	#0
vi_lp1:
	lda	#DefaultTextColor
	sta	ColorRAM,x
	sta	ColorRAM+256,x
	lda	#" "
	sta	ScreenRAM,x
	sta	ScreenRAM+256,x
	inx
	bne	vi_lp1

	lda	#NormalColor
	sta	$900f

	rts

;Non zero if this is a PAL-machine
PAL_Flag:
	dc.b	0

;**************************************************************************
;*
;* CheckPAL
;* Returns:	 Acc=0 on NTSC-M systems, Acc!=0 on PAL-B systems
;*		 (and sets PAL_Flag accordingly)
;*
;******
CheckPAL:
; find raster line 2
	lda	#2/2
cp_lp1:
	cmp	$9004
	bne	cp_lp1
; now we know that we are past raster line 0, see if we find raster line 268
; before we find raster line 0
cp_lp2:	
	lda	$9004
	beq	cp_ex1
	cmp	#268/2		; This line does not exist on NTSC.
	bne	cp_lp2
cp_ex1:	
	sta	PAL_Flag
	rts

;**************************************************************************
;*
;* ShowEditScreen
;*
;******
ShowScreen:
	ldx	#22*10
ss_lp2:
	lda	Screen-1,x
	cmp	#"A"
	bcc	ss_skp1
	cmp	#"Z"+1
	bcs	ss_skp1
	and	#$3f	
ss_skp1:
	sta	ScreenRAM+22*10-1,x
	tay
	lda	#DefaultTextColor2
	cpy	#30		; uparrow
	beq	ss_skp3		; make this like the border.
	cpy	#$40
	bcc	ss_skp2		; char less that $40, make it text color.
ss_skp3:
	lda	#DefaultTextColor
ss_skp2:
	sta	ColorRAM+22*10-1,x
	dex	
	bne	ss_lp2

; say that there is text on the status line, and then call Blank
	lda	#1
	sta	StatusLineFlag
	jsr	BlankStatus

	ldx	#44-1
ss_lp1:
	lda	Bonus_MSG,x
	and	#$3f
	ora	#$80
	sta	ScreenRAM+22*21,x
	lda	#BorderColor
	sta	ColorRAM+22*21,x
	dex
	bpl	ss_lp1
	rts


Bonus_MSG:
	dc.b	"                      "
	dc.b	"   VIC-TRACKER "
	dc.b	VERSION
	dc.b	"!   "

;**************************************************************************
;*
;* ShowInfo
;*
;******
ShowInfo:
	jsr	PrintEditMode

	rts

;**************************************************************************
;*
;* Print PlayerData
;*
;******
PrintPlayer:
	lda	#<[ScreenRAM+22*11]
	sta	ScreenZP
	lda	#>[ScreenRAM+22*11]
	sta	ScreenZP+1
	ldy	#19+22*2
	lda	pl_Step
	jsr	PutHex
	ldy	#19+22*3
	lda	pl_PatternPos
	jsr	PutHex
	ldy	#19+22*4
	lda	pl_Speed
	jsr	PutHex

; Print mutes!
	ldx	#0
	ldy	#15+22*0
ppl_lp1:	
	lda	pl_Mute,x
	bne	ppl_skp2
	txa
	clc
	adc	#"1"
	dc.b	$2c		; bit $xxxx
ppl_skp2:
	lda	#"."
	sta	(ScreenZP),y
	iny
	inx
	cpx	#4
	bne	ppl_lp1

	ldy	#20+22*0
	lda	#"."
	ldx	pl_PlayFlag
	beq	ppl_skp1
	lda	#"P"&$3f
ppl_skp1:
	sta	(ScreenZP),y

	lda	pl_ThisSong 		; Current song
	pha

	asl			; x=pl_ThisSong * 4
	asl
	tax
	
	ldy	#5+22*2
	lda	pl_StartStep,x
	jsr	PutHex
	ldy	#5+22*3
	lda	pl_EndStep,x
	jsr	PutHex

	ldy	#5+22*4
	lda	pl_StartSpeed,x
	and	#$c0
	beq	ppl_skp5
	cmp	#$40
	beq	ppl_skp3
	lda	#"-"
	dc.b	$2c		; bit $xxxx
ppl_skp5:
	lda	#30		; Uparrow
	sta	(ScreenZP),y
	iny	
	sta	(ScreenZP),y
	jmp	ppl_skp4
ppl_skp3:
	lda	pl_RepeatStep,x
	jsr	PutHex
ppl_skp4:

	ldy	#5+22*5
	lda	pl_StartSpeed,x
	and	#$3f
	jsr	PutHex
	ldy	#6+22*7
	pla				; Current song
	jsr	PutNybble
	ldy	#13+22*4
	lda	pl_SongNum
	jsr	PutNybble


	lda	pl_PlayMode		;x=pl_PlayMode*6
	asl
	clc
	adc	pl_PlayMode
	asl
	tax

MODEPOS	EQU	8+22*2
	ldy	#MODEPOS
ppl_lp2:
	lda	pp_Modes,x
	and	#$3f
	sta	(ScreenZP),y
	iny
	inx
	cpy	#MODEPOS+6
	bne	ppl_lp2

	IFCONST	HAVESCALE
SCALEPOS	EQU	8+22*3
	lda	pl_Scale		;x=pl_Scale*6
	asl
	clc
	adc	pl_Scale
	asl
	tax	
	ldy	#SCALEPOS
ppl_lp3:
	lda	pp_Scales,x
	and	#$3f
	sta	(ScreenZP),y
	iny
	inx
	cpy	#SCALEPOS+7
	bne	ppl_lp3
	ENDIF ;HAVESCALE
	rts

; Modes:	
pp_Modes:
	dc.b	"LEGACY"
	dc.b	"PAL..."
	dc.b	"PAL.2X"
	dc.b	"PAL.3X"
	dc.b	"PAL.4X"
	dc.b	"NTSC.."
	dc.b	"NTSC2X"
	dc.b	"NTSC3X"
	dc.b	"NTSC4X"
	IFNCONST HAVESYNC24
NUMPLAYMODES	EQU	9
	ELSE ;HAVESYNC24
	dc.b	"SYNC24"
	dc.b	"SYNC48"
NUMPLAYMODES	EQU	11
	ENDIF ;HAVESYNC24

	IFCONST HAVESCALE
; Scales:	
pp_Scales:
	dc.b	"LEGACY"
	dc.b	"SCALE1"
	dc.b	"T-PAL."
	dc.b	"T-NTSC"
;	dc.b	"CUSTOM"
NUMSCALES	EQU	4
	ENDIF ;HAVESCALE

;**************************************************************************
;*
;* Print EditMode
;*
;******
PrintEditMode:
	lda	#<[ScreenRAM+22*11]
	sta	ScreenZP
	lda	#>[ScreenRAM+22*11]
	sta	ScreenZP+1

	ldy	#11
	lda	#"R"&$3f
	ldx	AdvanceMode
	beq	pem_skp1
	lda	#"D"&$3f
pem_skp1:
	sta	(ScreenZP),y

	ldy	#13
	lda	EditStep
	jsr	PutNybble

	rts


StatusLineFlag:
	dc.b	0		;true if there is text on the status line.
;**************************************************************************
;*
;* BlankStatusLine
;*
;******
BlankStatus:
	lda	StatusLineFlag
	beq	bs_ex1
	ldx	#21
	lda	#$20
bs_lp1:
	sta	ScreenRAM+22*20,x
	dex
	bpl	bs_lp1

	lda	#0
	sta	StatusLineFlag
bs_ex1:	
	rts

;**************************************************************************
;*
;* PrintStatus
;* Acc,Y=null terminated string
;*
;******
PrintStatus:
	pha
	tya
	pha
	jsr	BlankStatus
	ldy	#0
	ldx	#20
	clc
	jsr	$fff0
	lda	#StatusTextColor
	sta	646		; Cursor color
	pla
	tay
	pla
	jsr	$cb1e
	lda	#1
	sta	StatusLineFlag
	rts

;**************************************************************************
;*
;* Ask: Are You Sure
;* Returns: Acc=0 if no, and Acc=$ff if yes.
;*
;******
AreYouSure:
	jsr	ToggleCursor

	lda	#<AreYouSure_MSG
	ldy	#>AreYouSure_MSG
	jsr	PrintStatus

ays_lp1:
	jsr	$ffe4
	beq	ays_lp1
	pha
	jsr	BlankStatus
	jsr	ToggleCursor
	pla
	cmp	#"Y"
	beq	ays_ex1
	lda	#0
	rts
ays_ex1:
	lda	#$ff
	rts

AreYouSure_MSG:
	dc.b	" ARE YOU SURE?  (Y/N)",0

;**************************************************************************
;*
;* GetString
;* IN:	 Acc=MaxLen (buffer must be able to contain one more byte for
;*       the trailing zero)... X,Y buffer pointer
;* OUT:	 Acc=ActualLength  X,Y buffer pointer
;*
;******
Tmp3ZP		EQU	$ae
GetString:
	stx	Tmp3ZP
	sty	Tmp3ZP+1
	sta	gs_MaxLen
	jsr	ToggleCursor
	ldy	#0
gs_lp1:
	jsr	$ffcf
	cmp	#13
	beq	gs_ex1
	sta	(Tmp3ZP),y
	iny
	cpy	gs_MaxLen
	bne	gs_lp1
gs_ex1:
	lda	#0
	sta	(Tmp3ZP),y
	tya
	jsr	ToggleCursor
	ldx	Tmp3ZP
	ldy	Tmp3ZP+1
	rts
gs_MaxLen:
	dc.b	0

	IFCONST	HAVEFADEIN
;**************************************************************************
;*
;* Fadestuff
;*
;******
FadeScrBuf	EQU	pl_PatternData+[$40*$80]-$200
FadeColBuf	EQU	$9600

PrepareFade:
	lda	$9003
	sta	old9003
	lda	#0
	jsr	WaitLine
	lda	#0
	sta	$9003
	lda	#NormalColor
	sta	$900f
	rts

PerformFade:
	ldx	#0
	txa
pf_lp1:
	lda	ScreenRAM,x
	sta	FadeScrBuf,x
	lda	ScreenRAM+$100,x
	sta	FadeScrBuf+$100,x
	lda	#$a0
	sta	ScreenRAM,x
	sta	ScreenRAM+$100,x
	lda	ColorRAM,x
	sta	FadeColBuf,x
	lda	ColorRAM+$100,x
	sta	FadeColBuf+$100,x
	lda	#BorderColor
	sta	ColorRAM,x
	sta	ColorRAM+$100,x
	inx
	bne	pf_lp1
	
	lda	#0
	jsr	WaitLine
	lda	old9003
	sta	$9003
;Now the screen is all blank and prepared...

	ldx	#0
pf_lp2:
	lda	#0
	jsr	WaitLine
	ldy	#8-1
pf_lp3:
	lda	FadeScrBuf,x
	sta	ScreenRAM,x
	lda	FadeScrBuf+$100,x
	sta	ScreenRAM+$100,x
	lda	FadeColBuf,x
	sta	ColorRAM,x
	lda	FadeColBuf+$100,x
	sta	ColorRAM+$100,x
	txa
	clc
	adc	#69
	tax
	dey
	bpl	pf_lp3
	cpx	#0
	bne	pf_lp2

;All transferred, clear the buffer again 
	ldx	#0
	txa
pf_lp4:	
	sta	FadeScrBuf,x
	sta	FadeScrBuf+$100,x
	inx
	bne	pf_lp4
	rts

old9003:
	dc.b	0
	ENDIF ;HAVEFADEIN

;**************************************************************************
;*
;* Screen layout
;*
;******
Screen:
	dc.b	"p@@@@@@@@@r@r@r@@@@@@n"
	dc.b	"]         ].].].... .]"
	dc.b	"k@@@@@@r@@q@q@[@@@@@@s"
	dc.b	"]FST 00]......]STP 00]"
	dc.b	"]LST 00]......]POS 00]"
	dc.b	"]RPT 00]SNGS 0]SPD 00]"
	dc.b	"]SPD 00k@@@@@@q@@@@@@s"
	dc.b	"k@@",30,30,"@@sPROGRAMMED BY]"
	dc.b	"]SONG 0]DANIEL KAHLIN]"
	dc.b	"m@@@@@@q@@@@@@@@@@@@@}"
 
; Tecken
;
; @ horisontellt
; ] lodrät
; k lodrät-V
; s lodrät-H
; q horisontellt-N
; r horisontellt-U
; p ÖV-hörn
; n ÖH-hörn
; m NV-hörn
; } NH-hörn
; [ Jätteplus
;

; eof
