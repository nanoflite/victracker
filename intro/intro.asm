;**************************************************************************
;*
;* FILE  intro.asm
;* Copyright (c) 1987, 1994, 2001, 2003 Daniel Kahlin <daniel@kahlin.net>
;* Written by Daniel Kahlin <daniel@kahlin.net>
;* $Id: intro.asm,v 1.28 2004/10/03 19:12:29 tlr Exp $
;*
;* DESCRIPTION
;*   RasterRoutine 1.0 - Daniel "T.L.R" Kahlin
;*   Alpha Range 89 Intro
;*
;******
	PROCESSOR 6502
	include	"../include/macros.i"
	include	"../include/vic20.i"
	
VB_BGCOL		EQU	0
LOGO_KANTCOL		EQU	1
LOGO_BGCOL		EQU	4
LOGO_RAMCOL		EQU	0
REST_BGCOL		EQU	6
SCROLL_BGCOL		EQU	6
SCROLL_TEXTCOL		EQU	1
TEXTAREA_TEXTCOL	EQU	1

BLANKCHAR		EQU	6

; show raster time
RASTERTIME		EQU	0
;*** Flags ***

MUSIC		EQU	1

;Debug Stab
DEBUG		EQU	0

;Debug timer interrupt stable
DEBUG2		EQU	0

;Set to disable RESTORE
RESTOREDISABLE	EQU	1


;the length of a screen in cycles (PAL)
SCREENTIME	EQU	SCREENTIME_PAL

;the length of a row in cycles (PAL)
ROWTIME		EQU	LINETIME_PAL

;the time to setting the next interrupt (PAL)
COMPTIME	EQU	30+71



;Macro to enable next interrupt within this one
	MAC	FORK
	pla
	pla
	jsr	Update
	cli
	ENDM


;Music macros
	MAC	INITMUSIC
;	lda	#0
	jsr	pl_Init
	ENDM
	MAC	PLAYMUSIC
	IF	RASTERTIME
	ldx	#$77+8
	stx	$900f
	ENDIF ;RASTERTIME
	jsr	pl_Play
	IF	RASTERTIME
	ldx	#$00+8
	stx	$900f
	ENDIF ;RASTERTIME
	ENDM

ScreenRAM	EQU	$1200
ColorRAM	EQU	$9600
ScreenRAM_ALT	EQU	$1000
ColorRAM_ALT	EQU	$9400
MSB9002		EQU	$80


MultZP	EQU	$f7	;8 bytes

ScrZP	EQU	$fb		;2 bytes
dummyzp	EQU	$fd

;**************************************************************************
;*
;* Linkage!
;*
;******
	seg	gfx
	org	$1800
FileStart:
	incbin	"logo18x9bg.bin"
	org	$1e00
	incbin	"font.bin"

	seg	code
	org	$2000


;**************************************************************************
;*
;* SysAddress... When run we will enter here!
;*
;******
SysAddress:
	sei
; preserve the old video state.
	ldx	#$0a-1
sa_lp1:
	lda	$9000,x
	sta	videostore,x
	dex
	bpl	sa_lp1
	lda	$900e		; clear volume and store
	and	#$f0
	sta	videostore+$0e
	lda	#[14<<4]+6+8	; Border and Background color
	sta	videostore+$0f	; after exit

; create new screen data
	jsr	InitScrollBar	
	jsr	ScreenInit
	IF	MUSIC
	INITMUSIC
	ENDIF ;MUSIC
	IF	DEBUG2
	ldx	#0
	txa
sa_lp4:
	sta	$5000,x		; Clear stabilize measurement area
	sta	$5100,x
	dex
	bpl	sa_lp4
	ENDIF ;DEBUG2
	jsr	InterruptInit
	cli
sa_lp2:
	IF	DEBUG2
	ldx	#8
idle:
	pha
	inc.w	$100-8,x
	lda	$fe,y
	and	#$01
	bne	id_skp1
id_skp1:
	bit	$ea
	pla
	nop
	nop
	nop
	dey
	ENDIF ;DEBUG2
	lda	exitflag
	beq	sa_lp2

; Ok..., now we should exit!
; First make the screen all blue.
	jsr	BlueScreen

	sei
	IF	RESTOREDISABLE
	lda	#%00000010
	sta	$911d		; Clear pending restore keys
	ENDIF

; Wait until vertical blanking.
; and then restore the old video state.
	lda	#0
	jsr	WaitLine
	ldx	#16-1
sa_lp3:
	lda	videostore,x
	sta	$9000,x
	dex
	bpl	sa_lp3

	jsr	$fd52		; set vectors
	jsr	$fdf9		; set timer ints
	
; clear up basic...
	lda	#0
	sta	$1200
	sta	$1201
	sta	$1202
	sta	$1203
	
; Return safely to earth!
	rts

exitflag:
	dc.b	0

videostore:
	ds.b	16,0
	
;**************************************************************************
;*
;* Initialize ScreenData!
;*
;******
ScreenInit:
	ldx	#0
vi_lp1:
	lda	#LOGO_RAMCOL+8
	sta	ColorRAM,x
	sta	ColorRAM+$100,x
	lda	#BLANKCHAR
	sta	ScreenRAM,x
	sta	ScreenRAM+$100,x
	inx
	bne	vi_lp1

	lda	#0
	sta	Offset1

	jsr	Showtext
	jsr	Showscroll
	rts


;**************************************************************************
;*
;* Initialize Interrupts!
;*
;******
InterruptInit:
	IF	RESTOREDISABLE
	lda	#%00000010
	sta	$911e	;No RestoreKey
	sta	$911d
	ENDIF

	lda	#$7f
	sta	$912e
	sta	$912d
	lda	#%11100000
	sta	$912e
	lda	#%01000000
	sta	$912b
	lda	#<IRQServer
	sta	$0314
	lda	#>IRQServer
	sta	$0315

	jsr	Stab	;Find Fixpoint!!! (VertBlank)
	lda	#<SCREENTIME
	sta	$9124
	lda	#>SCREENTIME
	sta	$9125	;load T1
	rts

	IF	DEBUG2
	ALIGN	256,0
	ENDIF ;DEBUG2
;**************************************************************************
;*
;* Stabilize routine
;*
;******
Stab:

st_lp4
	lda	$9004
	bne	st_lp4
st_lp5:
	lda	$9004
	beq	st_lp5

	START_SAMEPAGE	"Stab"
	ldy	#64
st_lp1:
	lda	$9003
	bmi	st_skp1
st_skp1:
	IF	DEBUG
	ldx	#$77+8
	stx	$900f
	ldx	#$66+8
	stx	$900f	;18
	nop
	nop
	nop
	ldx	#9	;1+5*9
	ELSE
	bit	$ea
	ldx	#12
	ENDIF
st_lp2:
	dex
	bne	st_lp2

	lda	$9003
	bpl	st_skp2
st_skp2:
	IF	DEBUG
	ldx	#$77+8
	stx	$900f
	ldx	#$66+8
	stx	$900f	;18
	nop
	nop
	nop
	ldx	#8	;1+5*9
	ELSE
	bit	$ea
	ldx	#11
	ENDIF
st_lp3:
	dex
	bne	st_lp3

	dey
	bne	st_lp1

	nop
st_lp6:
	lda	$9004
	beq	st_ex1
	IF	DEBUG
	ldx	#$11+8
	stx	$900f
	ldx	#$66+8
	stx	$900f	;18
	nop
	nop
	nop
	ldx	#8	;1+5*9
	ELSE
	bit	$ea
	ldx	#11
	ENDIF
st_lp7:
	dex
	bne	st_lp7
	bit	$ea
	jmp	st_lp6

st_ex1:
	END_SAMEPAGE
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
;* Make screen blue.
;*
;******
BlueScreen:
	ldx	#0
sa_lp5:
	lda	#$a0
	sta	ScreenRAM_ALT,x
	sta	ScreenRAM_ALT+$100,x
	lda	#6
	sta	ColorRAM_ALT,x
	sta	ColorRAM_ALT+$100,x
	dex
	bne	sa_lp5		
	rts

	
	IF	0
;**************************************************************************
;*
;* Multiply Acc*71	(A * %01000111)
;*
;******
Mult71:
	sta	MultZP+0
	sty	MultZP+1
	sty	MultZP+3
	asl
	sta	MultZP+2
	rol	MultZP+3
	ldy	MultZP+3
	sty	MultZP+5
	asl
	sta	MultZP+4
	rol	MultZP+5
	ldy	MultZP+5
	sty	MultZP+7
	asl
	rol	MultZP+7
	asl
	rol	MultZP+7
	asl
	rol	MultZP+7
	asl
	rol	MultZP+7
	sta	MultZP+6

	lda	MultZP+6
	clc
	adc	MultZP+4
	sta	MultZP+4
	lda	MultZP+7
	adc	MultZP+5
	sta	MultZP+5

	lda	MultZP+4
	clc
	adc	MultZP+2
	sta	MultZP+2
	lda	MultZP+5
	adc	MultZP+3
	sta	MultZP+3

	lda	MultZP+2
	clc
	adc	MultZP+0
	sta	MultZP+0
	lda	MultZP+3
	adc	MultZP+1
	sta	MultZP+1
	tay
	lda	MultZP+0
	rts
	ENDIF


;**************************************************************************
;*
;* IRQ Interrupt server
;*
;******
IRQServer:
	lda	$912d
	asl
	asl
	bcs	irq_skp1
	asl
	bcc	irq_ex1
	jsr	T2Timeout
	jmp	irq_ex1
irq_skp1:
	jsr	T1Timeout
irq_ex1:
	pla
	tay
	pla
	tax
	pla
	rti



;**************************************************************************
;*
;* Routines + stuff
;*
;******
T1Timeout:
	lda	#[75+[<t1_TComp]]&255
	sec
	sbc	$9124	;68-73 (for PAL)
	sta	t1_SelfModJMP+1
t1_SelfModJMP:
	jmp	t1_TComp
	START_SAMEPAGE	"T1COMP"
t1_TComp:
	dc.b	$a9,$a9,$a9,$a9,$a9,$a9
	dc.b	$a9,$a9,$a9,$a9,$24,$ea
	END_SAMEPAGE

	lda	InterruptTab
	sta	$9128
	lda	InterruptTab+1
	sta	$9129	;load T2
	lda	#$00
	sta	Line
	jsr	Update

	jsr	VertBlanking
	IF	DEBUG2
	lda	t1_SelfModJMP+1
	sec
	sbc	#<t1_TComp
	tax
	lda	#$01
	sta	$5100,x	
	ENDIF ;DEBUG2
	rts


T2Timeout:
	lda	#[$c0+[<t2_TComp]]&255
	sec
	sbc	$9128	;$ba-$bd (for PAL)
	sta	t2_SelfModJMP+1
t2_SelfModJMP:
	jmp	t2_TComp
	START_SAMEPAGE	"T2COMP"
t2_TComp:
	dc.b	$a9,$a9,$a9,$a9,$a9,$a9
	dc.b	$a9,$a9,$a9,$a9,$24,$ea
	END_SAMEPAGE

	lda	TimeLow
	sta	$9128
	lda	TimeHigh
	sta	$9129

SelfModJSR:
	jsr	SelfModJSR

	IF	DEBUG2
	lda	t2_SelfModJMP+1
	sec
	sbc	#<t2_TComp
	tax
	lda	#$01
	sta	$5000,x	
	ENDIF ;DEBUG2
Update:
	lda	Line
	inc	Line
	asl
	asl
	tax
	lda	InterruptTab+4,x
	sta	TimeLow
	lda	InterruptTab+5,x
	sta	TimeHigh
	lda	InterruptTab+2,x
	sta	SelfModJSR+1
	lda	InterruptTab+3,x
	sta	SelfModJSR+2
	rts


TimeLow:
	dc.b	0
TimeHigh:
	dc.b	0
Line:
	dc.b	0
InterruptTab:
	dc.w	ROWTIME*69-COMPTIME+12,Rast0
	dc.w	ROWTIME*5-COMPTIME+44,Rast1
	dc.w	ROWTIME*77-COMPTIME-44,Rast2
	dc.w	ROWTIME*10-COMPTIME,Rast3
	dc.w	ROWTIME*33-COMPTIME,Rast4
	dc.w	ROWTIME*19-COMPTIME,Rast5
	dc.w	ROWTIME*21-COMPTIME,Rast6
	dc.w	ROWTIME*12-COMPTIME,Rast7
	dc.w	-1,-1




;**************************************************************************
;*
;* Routines + stuff
;*
;******

VertBlanking:
	lda	#[VB_BGCOL<<4]+VB_BGCOL+8
	sta	$900f
	lda	#$0c+4	;horisontal (ingen interlace)
	sta	$9000
	lda	#38	;Vertikal
	sta	$9001	
	lda	#$00+18+MSB9002	;kolumner
	sta	$9002
	lda	#23*2+0	;rader
	sta	$9003
	lda	#$ce
	sta	$9005

	IF	MUSIC
	PLAYMUSIC
	ENDIF ;MUSIC
	rts

;**************************************************************************
;*
;* LOGO
;*
;******
buflen	EQU	72

	org	$2300
;*** Gör Logostart ***
Rast0:
	lda	#[LOGO_KANTCOL<<4]+LOGO_KANTCOL+8
	sta	$900f
	DELAY	20
	DELAY	20
	DELAY	25
	lda	#$08+LOGO_BGCOL
	sta	$900f

	lda	#4	;horisontal (ingen interlace)
	sta	$9000
	lda	#30+MSB9002	;kolumner
	sta	$9002
	lda	#$ce
	sta	$9005
	rts
;*** Visa colorbars i logo ***
Rast1:
	ldx	#0
	lda	$900e
	and	#$0f
	sta	temp
	START_SAMEPAGE	"Colorbars"
cb_lp1:
	lda	Buffer1+1,x
	sta	Buffer1,x
	ora	temp
	ldy	Buffer2,x
	sta	$900e
	sty	$900f
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	bit	$ea
	inx
	cpx	#buflen-1
	bne	cb_lp1
	END_SAMEPAGE

	lda	#$08+LOGO_BGCOL
	sta	$900f
	lda	temp
	sta	$900e
	rts

;*** Gör logoslut och scrolla färger ***
Rast2:
	lda	#[LOGO_KANTCOL<<4]+LOGO_KANTCOL+8
	sta	$900f
	DELAY	20
	DELAY	20
	DELAY	25
	lda	#[VB_BGCOL<<4]+VB_BGCOL+8
	sta	$900f
	DELAY	20
	DELAY	30
	DELAY	25
	lda	#0+MSB9002	;kolumner
	sta	$9002
	rts


;**************************************************************************
;*
;* Text area
;*
;******

;*** Starta textarea ***
Rast3:
	lda	#12	;horisontal (ingen interlace)
	sta	$9000
	lda	#22+MSB9002	;kolumner
	sta	$9002

	IF	MUSIC
	FORK
	PLAYMUSIC
	ENDIF ;MUSIC
	rts

;*** Avsluta textarea ***
Rast4:

	lda	#0+MSB9002	;kolumner
	sta	$9002
	rts



;**************************************************************************
;*
;* SCROLL
;*
;******

;*** Starta scroll ***
Rast5:
	lda	#[LOGO_KANTCOL<<4]+LOGO_KANTCOL+8
	sta	$900f
	DELAY	20
	DELAY	20
	DELAY	25
	lda	#[SCROLL_BGCOL<<4]+SCROLL_BGCOL+8
	sta	$900f

	
	lda	#4	;horisontal (ingen interlace)
	sta	$9000
	lda	#30+MSB9002	;kolumner
	sta	$9002
	rts

;*** Avsluta scroll ***
Rast6:
	lda	#0+MSB9002	;kolumner
	sta	$9002
	rts
	
;*** Avsluta scroll ***
Rast7:
	lda	#[LOGO_KANTCOL<<4]+LOGO_KANTCOL+8
	sta	$900f
	DELAY	20
	DELAY	20
	DELAY	25
	lda	#[VB_BGCOL<<4]+VB_BGCOL+8
	sta	$900f

	IF	RASTERTIME
	lda	#$ff
	sta	$900f
	ENDIF
	jsr	pl_ReadFlag
	cmp	#1
	bne	r7_skp1
	jsr	LogoScroll1
	jmp	r7_skp3
r7_skp1:
	cmp	#2
	bne	r7_skp2
	jsr	LogoScroll2
	jmp	r7_skp3
r7_skp2:
	cmp	#3
	bne	r7_skp3
	jsr	LogoScroll3
r7_skp3:

; check for space
	lda	#$ef
	sta	$9120
	lda	$9121
	cmp	#$fe
	bne	r7_ex1
	lda	#1
	sta	exitflag
r7_ex1:	

	jsr	ScrollBar
	FORK
	jsr	doscroll

	IF	RASTERTIME
	lda	#$00
	sta	$900f
	ENDIF

	rts





;**************************************************************************
;*
;* Scroll ColorBars
;*
;******
InitScrollBar:	
	ldx	#buflen-1
isb_lp1:
	txa
	pha

	ldx	#0
isb_lp2:
	lda	Buffer1+1,x
	sta	Buffer1,x
	inx
	cpx	#buflen-1
	bne	isb_lp2
	jsr	ScrollBar

	pla
	tax
	dex
	bpl	isb_lp1
	rts
	
ScrollBar:	
	lda	frame
	eor	#$ff
	sta	frame
	beq	cb_skp6
	ldx	#buflen-2
cb_lp4:
	lda	Buffer2,x
	sta	Buffer2+1,x
	dex
	bpl	cb_lp4
cb_skp6:

	lda	Cnt1
	lsr
	lsr
	lsr
	lsr
	lsr
	tax
cb_lp2:
	lda	Tab1,x
	bpl	cb_skp1
	ldx	#0
	stx	Cnt1
	beq	cb_lp2
cb_skp1:
	asl
	asl
	asl
	asl
	sta	Buffer1+buflen-1
	inc	Cnt1


	lda	Cnt2
	lsr
	tax
cb_lp3:
	lda	Tab2,x
	bpl	cb_skp2
	ldx	#0
	stx	Cnt2
	beq	cb_lp3
cb_skp2:
	asl
	asl
	asl
	asl
	ora	#LOGO_BGCOL
	sta	Buffer2
	
	inc	Cnt2
	rts
Cnt1:
	dc.b	0
Cnt2:
	dc.b	0
temp:
	dc.b	0
frame:
	dc.b	0

;**************************************************************************
;*
;* LogoScroll1  (Alpha)
;*
;******
LogoScroll1:
	lda	Offset1
	cmp	#18+6
	beq	ls1_ex1

	ldx	#0
ls1_lp1:
	lda	ScreenRAM+1,x
	sta	ScreenRAM,x
	inx
	cpx	#[30*3]-1
	bne	ls1_lp1

	lda	Offset1
	inc	Offset1

	cmp	#18
	bcs	ls1_skp1
	sta	ScreenRAM+[30*0]+29
	clc
	adc	#18
	sta	ScreenRAM+[30*1]+29
	clc
	adc	#18
	sta	ScreenRAM+[30*2]+29
	rts
ls1_skp1:
	lda	#6
	sta	ScreenRAM+[30*0]+29
	sta	ScreenRAM+[30*1]+29
	sta	ScreenRAM+[30*2]+29
ls1_ex1:
	rts
Offset1:
	dc.b	0


;**************************************************************************
;*
;* LogoScroll2  (Range)
;*
;******
LogoScroll2:
	lda	Offset2
	cmp	#18+6
	beq	ls2_ex1

	ldx	#[30*3]-2
ls2_lp1:
	lda	ScreenRAM+[30*3],x
	sta	ScreenRAM+1+[30*3],x
	dex
	bpl	ls2_lp1

	lda	Offset2
	inc	Offset2
	cmp	#18
	bcs	ls2_skp1

	lda	#18+[18*3]
	sec
	sbc	Offset2
	sta	ScreenRAM+[30*3]
	clc
	adc	#18
	sta	ScreenRAM+[30*4]
	clc
	adc	#18
	sta	ScreenRAM+[30*5]
	rts
ls2_skp1:
	lda	#6
	sta	ScreenRAM+[30*3]
	sta	ScreenRAM+[30*4]
	sta	ScreenRAM+[30*5]
ls2_ex1:
	rts
Offset2:
	dc.b	0


;**************************************************************************
;*
;* LogoScroll3  (89)
;*
;******
LogoScroll3:
	lda	Offset3
	cmp	#18+6
	beq	ls3_ex1

	ldx	#0
ls3_lp1:
	lda	ScreenRAM+1+[30*6],x
	sta	ScreenRAM+[30*6],x
	inx
	cpx	#[30*3]-1
	bne	ls3_lp1

	lda	Offset3
	inc	Offset3

	cmp	#18
	bcs	ls3_skp1

	clc
	adc	#[18*6]
	sta	ScreenRAM+[30*6]+29
	clc
	adc	#18
	sta	ScreenRAM+[30*7]+29
	clc
	adc	#18
	sta	ScreenRAM+[30*8]+29
	rts
ls3_skp1:
	lda	#6
	sta	ScreenRAM+[30*6]+29
	sta	ScreenRAM+[30*7]+29
	sta	ScreenRAM+[30*8]+29
	rts
ls3_ex1:
	lda	#1
	sta	scrollflag
	rts
Offset3:
	dc.b	0


;**************************************************************************
;*
;* Display text area
;*
;******
Showtext:
	ldx	#[22*3]-1
sht_lp1:
	lda	string,x
	and	#$3f
	ora	#$c0
	sta	ScreenRAM+[30*10]+[22*1],x
	lda	#TEXTAREA_TEXTCOL
	sta	ColorRAM+[30*10]+[22*1],x
	dex
	bpl	sht_lp1
	rts

string:
	dc.b	"       PRESENTS       "
	dc.b	"                      "
	dc.b	"   VIC-TRACKER "
	dc.b	VERSION
	dc.b	"!   "

;**************************************************************************
;*
;* Display scroll
;*
;******
SCROLL_NUM	EQU	30
SCROLL_CHAR	EQU	$c0-SCROLL_NUM
SCROLL_ADDRESS	EQU	$1800+[SCROLL_CHAR*8]
Showscroll:
	ldx	#0
ssc_lp1:
	txa
	clc
	adc	#SCROLL_CHAR
	sta	ScreenRAM+[30*10]+[22*4]+[30*2],x
	lda	#SCROLL_TEXTCOL
	sta	ColorRAM+[30*10]+[22*4]+[30*2],x
	inx
	cpx	#SCROLL_NUM
	bne	ssc_lp1

	ldx	#0
	txa
ssc_lp2:
	sta	SCROLL_ADDRESS,x
	inx
	cpx	#SCROLL_NUM*8
	bne	ssc_lp2

	ldx	#0
	txa
ssc_lp3:
	sta	pulver_buf,x
	inx
	cpx	#4*8
	bne	ssc_lp3
	
	rts

scrollflag:
	dc.b	0
	
doscroll:
	lda	scrollflag
	beq	dsc_ex1
	ldx	#8-1
dsc_lp1:	
; fetch from the buffer
	asl	nextchar,x
; scroll the invisible part
	rol	pulver_buf+[3*8],x
	rol	pulver_buf+[2*8],x
	rol	pulver_buf+[1*8],x
	rol	pulver_buf+[0*8],x
; the visible scroller
	asl	SCROLL_ADDRESS+[29*8],x
	rol	SCROLL_ADDRESS+[28*8],x
	rol	SCROLL_ADDRESS+[27*8],x
	rol	SCROLL_ADDRESS+[26*8],x
	rol	SCROLL_ADDRESS+[25*8],x
	rol	SCROLL_ADDRESS+[24*8],x
	rol	SCROLL_ADDRESS+[23*8],x
	rol	SCROLL_ADDRESS+[22*8],x
	rol	SCROLL_ADDRESS+[21*8],x
	rol	SCROLL_ADDRESS+[20*8],x
	rol	SCROLL_ADDRESS+[19*8],x
	rol	SCROLL_ADDRESS+[18*8],x
	rol	SCROLL_ADDRESS+[17*8],x
	rol	SCROLL_ADDRESS+[16*8],x
	rol	SCROLL_ADDRESS+[15*8],x
	rol	SCROLL_ADDRESS+[14*8],x
	rol	SCROLL_ADDRESS+[13*8],x
	rol	SCROLL_ADDRESS+[12*8],x
	rol	SCROLL_ADDRESS+[11*8],x
	rol	SCROLL_ADDRESS+[10*8],x
	rol	SCROLL_ADDRESS+[9*8],x
	rol	SCROLL_ADDRESS+[8*8],x
	rol	SCROLL_ADDRESS+[7*8],x
	rol	SCROLL_ADDRESS+[6*8],x
	rol	SCROLL_ADDRESS+[5*8],x
	rol	SCROLL_ADDRESS+[4*8],x
	rol	SCROLL_ADDRESS+[3*8],x
	rol	SCROLL_ADDRESS+[2*8],x
	rol	SCROLL_ADDRESS+[1*8],x
	rol	SCROLL_ADDRESS+[0*8],x
	dex
	bpl	dsc_lp1		

	jsr	do_pulverization
	
	dec	scrcount
	lda	scrcount
	beq	dsc_skp1
dsc_ex1:	
	rts

dsc_skp1:
	lda	#8
	sta	scrcount

	jsr	scroll_getchar
	cmp	#1
	bne	dsc_skp2
	jsr	scroll_getchar
	sta	scrcolor
	jsr	scroll_getchar
dsc_skp2:
	and	#$3f	
	sta	ScrZP
	lda	#0
	asl	ScrZP
	rol
	asl	ScrZP
	rol
	asl	ScrZP
	rol
	clc
	adc	#$1e
	sta	ScrZP+1

	ldy	#8-1
dsc_lp2:
	lda	(ScrZP),y
	sta	nextchar,y
	dey
	bpl	dsc_lp2

; scroll the color buffer 
	ldx	#0
dsc_lp3:
	lda	scrcolbuf+1,x
	sta	scrcolbuf,x
	inx
	cpx	#SCROLL_NUM-1
	bne	dsc_lp3
	
	lda	scrcolor
	sta	scrcolbuf+SCROLL_NUM-1

; copy the color buffer to the normal data buffer. 
	ldx	#SCROLL_NUM-1
dsc_lp4:
	ldy	scrcolbuf,x
	lda	lookup,y
	sta	ColorRAM+[30*10]+[22*4]+[30*2],x
	dex
	bpl	dsc_lp4

	lda	lookup+8
	eor	#1
	sta	lookup+8
	lda	lookup+9
	eor	#1
	sta	lookup+9

	rts
	

scrcount:
	dc.b	8
nextchar:	
	ds.b	8,0
scrcolor:
	dc.b	SCROLL_TEXTCOL
scrcolbuf:
	ds.b	SCROLL_NUM
lookup:
	dc.b	0,1,2,3,4,5,6,7,0,1,0,0

scroll_getchar:
sgc_lp1:
textptr:
	lda	scrolltext
	bne	sgc_skp1
	lda	#<scrolltext
	sta	textptr+1
	lda	#>scrolltext
	sta	textptr+2
	jmp	sgc_lp1
sgc_skp1:
	inc	textptr+1
	bne	sgc_ex1
	inc	textptr+2
sgc_ex1:
	cmp	#0
	rts	
;**************************************************************************
;*
;* Pulverization (this routine was originally coded by me in 1987, and
;*                adapted from the original laser genius source code.)
;*
;******
pulver_count:
	dc.b	0
index_table:
	dc.b	7,5,3,6,1,4,0,2
mask_table:
	dc.b	%10000001
	dc.b	%00010010
	dc.b	%01001000
	dc.b	%00100100
	dc.b	%10000001
	dc.b	%00010010
	dc.b	%01001000
	dc.b	%00100100
or_mask:
	ds.b	4
and_mask:
	ds.b	4

; this will contain the first four characters of the scroll,
; and will be gradually or:ed into the real scroll.
pulver_buf:
	ds.b	4*8
		
do_pulverization:
	jsr	generate_masks
	ldy	pulver_count
	lda	index_table,y
	tax
; gradually clear pixels at the left
	lda	SCROLL_ADDRESS+[3*8],x
	and	and_mask
	sta	SCROLL_ADDRESS+[3*8],x
	lda	SCROLL_ADDRESS+[2*8],x
	and	and_mask+1
	sta	SCROLL_ADDRESS+[2*8],x
	lda	SCROLL_ADDRESS+[1*8],x
	and	and_mask+2
	sta	SCROLL_ADDRESS+[1*8],x
	lda	SCROLL_ADDRESS+[0*8],x
	and	and_mask+3
	sta	SCROLL_ADDRESS+[0*8],x
; gradually make pixels appear at the right
	lda	pulver_buf+[3*8],x
	and	or_mask
	ora	SCROLL_ADDRESS+[[SCROLL_NUM-1]*8],x
	sta	SCROLL_ADDRESS+[[SCROLL_NUM-1]*8],x
	lda	pulver_buf+[2*8],x
	and	or_mask+1
	ora	SCROLL_ADDRESS+[[SCROLL_NUM-2]*8],x
	sta	SCROLL_ADDRESS+[[SCROLL_NUM-2]*8],x
	lda	pulver_buf+[1*8],x
	and	or_mask+2
	ora	SCROLL_ADDRESS+[[SCROLL_NUM-3]*8],x
	sta	SCROLL_ADDRESS+[[SCROLL_NUM-3]*8],x
	lda	pulver_buf+[0*8],x
	and	or_mask+3
	ora	SCROLL_ADDRESS+[[SCROLL_NUM-4]*8],x
	sta	SCROLL_ADDRESS+[[SCROLL_NUM-4]*8],x
	inc	pulver_count
	lda	pulver_count
	and	#7
	sta	pulver_count
	rts

generate_masks:
	ldy	pulver_count
	ldx	#0
gm_lp1:
	lda	mask_table,y
	sta	or_mask,x
	eor	#$ff
	sta	and_mask,x
	iny
	tya
	and	#7
	tay
	inx
	cpx	#4
	bne	gm_lp1
	rts

;**************************************************************************
;*
;* Generate delay code
;*
;******
	DELAYCODE	

;**************************************************************************
;*
;* Färg data
;*
;******
	ALIGN	256,0
Buffer1:
	ds.b	buflen,0
Buffer2:
	ds.b	buflen,LOGO_BGCOL
Tab1:
	dc.b	14
	dc.b	10
	dc.b	7
	dc.b	15
	dc.b	7
	dc.b	10
	dc.b	$ff
Tab2:
	dc.b	2,8,10,7,15,1,15,7,10,8,2,0,$ff


scrolltext:
	dc.b	1,1,"DANIEL KAHLIN PRESENTS "
	dc.b	1,8,"VIC-TRACKER "
	dc.b	VERSION
	dc.b	"! ",1,1
	dc.b	" THIS MUCH ANTICIPATED "
	dc.b	RELDATE
	dc.b	" RELEASE "
	dc.b	"ADDS -LOADS- OF NEW FEATURES AND IMPROVEMENTS OVER "
	dc.b	"THE PREVIOUS 1.0 AND 0.6 VERSIONS.    "
	dc.b	"I WOULD LIKE TO THANK MY FIANCE FOR PUTTING UP WITH ME "
	dc.b    "SITTING IN FRONT OF THE COMPUTER WRITING THIS PIECE OF "
	dc.b	"SOFTWARE.  "
	dc.b	"I HOPE YOU WILL FIND IT USEFUL AND MAKE LOTS OF FUN "
	dc.b	"MUSIC WITH IT!    "
	dc.b	"GREETINGS TO:  FRZ, PITCH, K12, LORD DEATH, ANDERS CARLSSON, "
	dc.b	"ALEKSI EEBEN, MERMAID/CREATORS, MARKO MAKELA "
	dc.b	"AND THOSE FORGOTTEN...        "
	dc.b	"VIC-TRACKER "
	dc.b	VERSION
	dc.b	" IS THE DEFINITE "
	dc.b	"TOOL OF CHOICE FOR THE PROFESSIONAL VIC-20 COMPOSER! "
	dc.b	"                     "
	dc.b	0
scrolltextend:
	
	IF	MUSIC
music:
	include "../examples/vt-theme.asm"
musicend:
	ENDIF ;MUSIC

FileEnd
	SHOWRANGE "All",FileStart,FileEnd
	SHOWRANGE "Scrolltext",scrolltext,scrolltextend
	IF	MUSIC
	SHOWRANGE "Music",music,musicend
	ENDIF ;MUSIC
; eof
