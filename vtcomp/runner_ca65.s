; Demo player for victracker 2.0
;
;   Copyright (c) 1994, 2001, 2003 Daniel Kahlin <daniel@kahlin.net>
;   Copyright (c) 2020 Johan Van den Brande <johan@vandenbrande.com>
;
;   Originally written by Daniel Kahlin <daniel@kahlin.net>
;   Ported to ca65 (https://www.cc65.org/) by Johan Van den Brande
;
;            (\/)
;           ( ..)
;          C(")(")
;   May the bunnies be with you!

.include "macros.inc"

.import pl_Play
.import pl_Init
.import pl_PlayFlag

; song configuration.
NUMSONGS = @NUMSONGS@
.define TITLE @TITLE@
.define AUTHOR @AUTHOR@
.define VERSION @VERSION@

.ifndef LENGTH
LENGTH = 0
.endif

.ifndef RN_VTCOMP
; modes
;RN_DEBUG	=	1
;RN_DEBUG	=	1
RN_UNEXP	=	1
RN_SPEED_1X	=	1
;RN_SPEED_2X	=	1
;RN_SPEED_3X	=	1
;RN_SPEED_4X	=	1

.endif ;RN_VTCOMP

; macros 
	.macro	HEXDIGIT number
    .ifnblank number
	    .if	number<10
	      .byte	'0'+number
	    .else
	      .byte	'A'+number-10
      .endif
	  .else
	    .byte	'x'
    .endif
	.endmacro

	.macro	HEXWORD number
	  HEXDIGIT (number)>>12
	  HEXDIGIT ((number)>>8)&$0f
	  HEXDIGIT ((number)>>4)&$0f
	  HEXDIGIT (number)&$0f
	.endmacro

BorderColor	 =	6
BorderColor_Play =	3
BackgroundColor	 =	14
NormalColor	=	(BackgroundColor<<4)+BorderColor+8
PlayColor	=	(BackgroundColor<<4)+BorderColor_Play+8

INFO_POS	=	7
INFO_HEIGHT	=	6

BONUS_POS	=	15

.ifdef	RN_DEBUG
SCROLL_POS	=	15
SCROLL_HEIGHT	=	7

DATA_POS	=	0

.endif ;RN_DEBUG

;the length of a screen in cycles (PAL)
SCREENTIME_PAL		=	22150
;the length of a screen in cycles (NTSC)
SCREENTIME_NTSC		=	16963

.ifdef RN_SPEED_1X
STARTLINE	=	74+8*6
STARTLINE_PAL		=	STARTLINE
STARTLINE_NTSC		=	STARTLINE-24
.endif ;RN_SPEED_1X

.ifdef RN_SPEED_2X
SCREENTIMETWO_PAL	=	SCREENTIME_PAL/2
SCREENTIMETWO_NTSC	=	SCREENTIME_NTSC/2
INT_TIMES		=	1
STARTLINE	=	74+8*2
STARTLINE_PAL		=	STARTLINE
STARTLINE_NTSC		=	STARTLINE-24
.endif ;RN_SPEED_2X

.ifdef RN_SPEED_3X
SCREENTIMETWO_PAL	=	SCREENTIME_PAL/3
SCREENTIMETWO_NTSC	=	SCREENTIME_NTSC/3
INT_TIMES		=	2
STARTLINE	=	74-8*2
STARTLINE_PAL		=	STARTLINE
STARTLINE_NTSC		=	STARTLINE-24
.endif ;RN_SPEED_3X

.ifdef RN_SPEED_4X
SCREENTIMETWO_PAL	=	SCREENTIME_PAL/4
SCREENTIMETWO_NTSC	=	SCREENTIME_NTSC/4
INT_TIMES		=	3
STARTLINE	=	34
STARTLINE_PAL		=	STARTLINE
STARTLINE_NTSC		=	STARTLINE-24
.endif ;RN_SPEED_4X
	
.ifdef RN_UNEXP
rn_ScreenRAM	=	$1e00
rn_ColorRAM	=	$9600
.else ;!RN_UNEXP
rn_ScreenRAM	=	$1000
rn_ColorRAM	=	$9400
.endif ;RN_UNEXP

rn_CopyZP	=	$fb	;only used during copy down
rn_ScreenZP	=	$d1
rn_ColorZP	=	$fd
rn_YPosZP	=	$ff
rn_YTempZP	=	$fb
rn_XTempZP	=	$fc

   .segment "EXEHDR"
StartOfFile:

    basicstart 1, rn_Main, "TRACKER"        

   .segment "CODE"

;**************************************************************************
;*
;* SysAddress... When run we will enter here!
;*
;******
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
	cmp	#' '
	beq	rn_mn_Toggle
	cmp	#'P'
	beq	rn_mn_Toggle
	cmp	#'M'
	beq	rn_Restart
	cmp	#'1'		;Less than "1"
	bcc	rn_mn_lp1	;yes, loop.
	cmp	#'1'+NUMSONGS	;Greater than NUMSONGS
	bcs	rn_mn_lp1	;yes, loop.
rn_mn_StartSong:
	sec
	sbc	#'1'
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
.ifndef RN_SPEED_1X
	ldx	#<SCREENTIMETWO_PAL
	ldy	#>SCREENTIMETWO_PAL
	stx	Int_CurCycles
	sty	Int_CurCycles+1
.endif ;RN_SPEED_1X
	ldx	#<SCREENTIME_PAL
	ldy	#>SCREENTIME_PAL
	lda	#STARTLINE_PAL/2
	plp
	bne	ii_skp1
.ifndef RN_SPEED_1X
	ldx	#<SCREENTIMETWO_NTSC
	ldy	#>SCREENTIMETWO_NTSC
	stx	Int_CurCycles
	sty	Int_CurCycles+1
.endif ;RN_SPEED_1X
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
.ifndef RN_SPEED_1X
	asl
	bcs	irq_skp2		;Did T2 time out?
.endif ;RN_SPEED_1X
	jmp	$eabf
.ifndef RN_SPEED_1X
irq_skp2:
	dec	Int_Count
	bmi	irq_skp3		; Last Interrupt?
	lda	Int_CurCycles
	sta	$9128
	lda	Int_CurCycles+1
	sta	$9129	;load T2
irq_skp3:
	lda	$9128		;ACK T2 interrupt.
	jsr	rn_Frame	;Yes, run player.
	jmp	$eb18		;Just pulls the registers
.endif ;RN_SPEED_1X
irq_skp1:
.ifndef RN_SPEED_1X
	lda	Int_CurCycles
	sta	$9128
	lda	Int_CurCycles+1
	sta	$9129	;load T2
	lda	#INT_TIMES
	sta	Int_Count
	lda	#%11100000	;T1 Interrupt + T2 Interrupt
	sta	$912e
	lda	$9124		;ACK T1 interrupt.
	cli			;Enable nesting
.endif ;RN_SPEED_1X
	jsr	rn_Frame	;Yes, run player.
	lda	$9124		;ACK T1 interrupt.
irq_ex1:
	jmp	$eabf
	
.ifndef RN_SPEED_1X
Int_CurCycles:
	.word	0
Int_CurTimes:
	.byte	0	
Int_Count:
	.byte	0	
.endif ;RN_SPEED_1X

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

.ifdef	RN_DEBUG
	lda	pl_Count
	cmp	pl_Speed
	bne	rn_fr_ex1
	ldx	#0
rn_fr_lp2:
	lda	rn_ScreenRAM+(22*(SCROLL_POS+1)),x
	sta	rn_ScreenRAM+(22*(SCROLL_POS)),x
	inx
	cpx	#22*6
	bne	rn_fr_lp2
	jsr	rn_UpdateScroll
rn_fr_ex1:
.endif ;RN_DEBUG
	rts


;**************************************************************************
;*
;* This displays all other data!
;*
;******
rn_ShowData:
;Show number of raster lines
	ldx	#<(rn_ScreenRAM+(22*(INFO_POS+5)))
	ldy	#>(rn_ScreenRAM+(22*(INFO_POS+5)))
	jsr	rn_ScreenPtr
	ldy	#9
	sty	rn_YPosZP
	lda	rn_Lines
	jsr	rn_PutHex
	ldy	#18
	sty	rn_YPosZP
	lda	rn_MaxLines
	jsr	rn_PutHex

.ifdef RN_DEBUG
	ldx	#<(rn_ScreenRAM+(22*DATA_POS))
	ldy	#>(rn_ScreenRAM+(22*DATA_POS))
	jsr	rn_ScreenPtr
;Show a selection of internal player parameters
	ldy	#(22*0+3)
	sty	rn_YPosZP
	ldx	#0
rn_sd_lp1:
	lda	pl_vd_PattlistStep,x
	jsr	rn_PutHex
	lda	pl_vd_FetchMode,x
	jsr	rn_PutHex
	lda	pl_vd_CurrentPattern,x
	jsr	rn_PutHex
	lda	pl_vd_PatternStep,x
	jsr	rn_PutHex
	lda	pl_vd_FreqOffsetLow,x
	jsr	rn_PutHex
	lda	pl_vd_FreqOffsetHigh,x
	jsr	rn_PutHex
	lda	pl_vd_ArpStep,x
	jsr	rn_PutHex
	lda	pl_vd_ArpOffset,x
	jsr	rn_PutHex

	lda	rn_YPosZP
	clc
	adc	#6
	sta	rn_YPosZP
	inx
	cpx	#5
	bne	rn_sd_lp1
	rts

.ifdef RN_DEBUG
.endif ;RN_DEBUG
rn_UpdateScroll:
	ldx	#<(rn_ScreenRAM+(22*(SCROLL_POS+SCROLL_HEIGHT-1)))
	ldy	#>(rn_ScreenRAM+(22*(SCROLL_POS+SCROLL_HEIGHT-1)))
	jsr	rn_ScreenPtr
;Handle update of the scroller
	ldy	#1
	sty	rn_YPosZP
	ldx	#0
rn_sd_lp4:
	lda	pl_vd_Note,x
	jsr	rn_PutHex
	lda	pl_vd_Param,x
	jsr	rn_PutHex
	inx
	cpx	#5
	bne	rn_sd_lp4
	rts
.endif ;RN_DEBUG


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
	.byte	"0123456789",1,2,3,4,5,6

rn_ThisSong:
	.byte	0
rn_Lines:
	.byte	0
rn_MaxLines:
	.byte	0

rn_InitScreen:
.ifdef	RN_UNEXP
; screenmem at $1e00, colormem at $9600
	lda	$9002
	ora	#$80
	sta	$9002
	lda	#$f0
	sta	$9005
.else ;RN_UNEXP
; screenmem at $1000, colormem at $9400
	lda	$9002
	and	#$7f
	sta	$9002
	lda	#$c0
	sta	$9005
.endif ;!RN_UNEXP

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

.ifdef RN_DEBUG
	lda	#>(rn_ColorRAM+(22*SCROLL_POS))
	sta	rn_ColorZP+1
	lda	#<(rn_ColorRAM+(22*SCROLL_POS))
	sta	rn_ColorZP

	ldx	#SCROLL_HEIGHT-1
rn_is_lp2:
	ldy	#21
rn_is_lp3:
	lda	rn_ColorTab,y
	sta	(rn_ColorZP),y	
	dey
	bpl	rn_is_lp3
	lda	rn_ColorZP
	clc
	adc	#22
	sta	rn_ColorZP
	bcc	rn_is_skp1
	inc	rn_ColorZP+1
rn_is_skp1:
	dex
	bpl	rn_is_lp2
.endif ;RN_DEBUG

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
	.byte	"TITLE : "
	.byte	TITLE
; line2
	.byte	"AUTHOR: "
	.byte	AUTHOR
; line3
	.byte	"SONGS : "
	HEXDIGIT NUMSONGS
.if NUMSONGS>1
	.byte	" (1-"
	HEXDIGIT NUMSONGS
	.byte	")       "
.else
	.byte	"             "
.endif	
; line4
	.byte	"LENGTH: $"
	HEXWORD LENGTH
	.byte	"         "
; line 5
	.byte	"             "
; line 6  
	.byte	"             "

rn_Bonus_MSG:
	.byte	" CA65 VIC-PLAYER "
	.byte	VERSION
	.byte	"    "

.ifdef RN_DEBUG
rn_ColorTab:
	.byte	6,2,2,2,2,6,6,6,6,2,2,2,2,6,6,6,6,2,2,2,2,6
.endif ;RN_DEBUG

.ifndef RN_UNEXP
	align	256
.endif ;RN_UNEXP
rn_MainEnd:
rn_LoadEnd:

