;**************************************************************************
;*
;* FILE  playersupport.asm
;* Copyright (c) 2003 Daniel Kahlin <daniel@kahlin.net>
;* Written by Daniel Kahlin <daniel@kahlin.net>
;* $Id: playersupport.asm,v 1.10 2003/08/09 20:28:47 tlr Exp $
;*
;* DESCRIPTION
;*   Functions needed to handle the player from the editor
;*
;******

Int_Cycles:
; On a PAL machine, these are the cycle counts for different interrupts
Int_Cycles_PAL:
	dc.w	SCREENTIME_PAL,SCREENTIME_PAL		  ;LEGACY
	dc.w	SCREENTIME_PAL,SCREENTIME_PAL		  ;PAL...
	dc.w	SCREENTIME_PAL,SCREENTIME_PAL/2		  ;PAL.2X
	dc.w	SCREENTIME_PAL,SCREENTIME_PAL/3		  ;PAL.3X
	dc.w	SCREENTIME_PAL,SCREENTIME_PAL/4		  ;PAL.4X
	dc.w	SCREENTIME_PAL_NTSC,SCREENTIME_PAL_NTSC   ;NTSC..
	dc.w	SCREENTIME_PAL_NTSC,SCREENTIME_PAL_NTSC/2 ;NTSC2X
	dc.w	SCREENTIME_PAL_NTSC,SCREENTIME_PAL_NTSC/3 ;NTSC3X
	dc.w	SCREENTIME_PAL_NTSC,SCREENTIME_PAL_NTSC/4 ;NTSC4X
	dc.w	SCREENTIME_PAL,SCREENTIME_PAL		  ;SYNC24
	dc.w	SCREENTIME_PAL,SCREENTIME_PAL		  ;SYNC48

; On an NTSC machine, these are the cycle counts for different interrupts
Int_Cycles_NTSC:
	dc.w	SCREENTIME_PAL,SCREENTIME_PAL		  ;LEGACY
	dc.w	SCREENTIME_NTSC_PAL,SCREENTIME_NTSC_PAL	  ;PAL...
	dc.w	SCREENTIME_NTSC_PAL,SCREENTIME_NTSC_PAL/2 ;PAL.2X
	dc.w	SCREENTIME_NTSC_PAL,SCREENTIME_NTSC_PAL/3 ;PAL.3X
	dc.w	SCREENTIME_NTSC_PAL,SCREENTIME_NTSC_PAL/4 ;PAL.4X
	dc.w	SCREENTIME_NTSC,SCREENTIME_NTSC		  ;NTSC..
	dc.w	SCREENTIME_NTSC,SCREENTIME_NTSC/2	  ;NTSC2X
	dc.w	SCREENTIME_NTSC,SCREENTIME_NTSC/3	  ;NTSC3X
	dc.w	SCREENTIME_NTSC,SCREENTIME_NTSC/4	  ;NTSC4X
	dc.w	SCREENTIME_PAL,SCREENTIME_PAL		  ;SYNC24
	dc.w	SCREENTIME_PAL,SCREENTIME_PAL		  ;SYNC48

Int_Times:
	dc.b	0,0,1,2,3,0,1,2,3,0,0

Int_CurCycles:
	dc.w	0
Int_CurTimes:
	dc.b	0
Int_Count:
	dc.b	0

Int_ColorFlag:
	dc.b	0

Int_Sync:
	dc.b	0
				
;**************************************************************************
;*
;* Initialize Interrupts!
;*
;******
InterruptInit:
	jsr	InterruptUnInit
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

	lda	#200/2
	jsr	WaitLine

	lda	pl_PlayMode	;Acc=pl_PlayMode*4
	asl
	asl
	ldx	PAL_Flag	;Acc=Acc+Int_Cycles_NTSC-Int_Cycles_PAL
	bne	ii_skp1		;if PAL_Flag = 0
	clc
	adc	#Int_Cycles_NTSC-Int_Cycles_PAL
ii_skp1:	
	tax			;X=Acc
	ldy	Int_Cycles,x
	sty	$9124
	ldy	Int_Cycles+1,x
	sty	$9125	;load T1

	lda	Int_Cycles+2,x
	sta	Int_CurCycles
	lda	Int_Cycles+2+1,x
	sta	Int_CurCycles+1
	ldx	pl_PlayMode
	lda	Int_Times,x
	sta	Int_CurTimes

	
	lda	#0
	sta	Int_Sync
	lda	pl_PlayMode
	sec
	sbc	#9
	bcc	ii_skp2
	clc
	adc	#1
	sta	Int_Sync
	jsr	InterruptSyncInit
ii_skp2:

	cli
	rts

InterruptUnInit:
	sei
	jsr	$fd52		; set vectors
	jsr	$fdf9		; set timer ints
	cli
	rts

;**************************************************************************
;*
;* Wait until line ACC is passed
;*
;******
WaitLine:
s_lp2:
	cmp	$9004
	bne	s_lp2
s_lp3:
	cmp	$9004
	beq	s_lp3
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
	asl
	bcs	irq_skp2		;Did T2 time out?
; No, skip to normal interrupt routine.
	jmp	$eabf
irq_skp1:
	jsr	T1Timeout	;Yes, run player.
	lda	$9124		;ACK T1 interrupt.
	jmp	$eabf		;Normal IRQ
irq_skp2:
	jsr	T2Timeout	;Yes, run player.
	lda	$9128		;ACK T2 interrupt.
	jmp	$eb18		;Just pulls the registers
	
;**************************************************************************
;*
;* Interrupt routine
;*
;******
T1Timeout:
	lda	Int_CurTimes
	beq	t1_skp1
	lda	Int_CurCycles
	sta	$9128
	lda	Int_CurCycles+1
	sta	$9129	;load T2
	lda	Int_CurTimes
	sta	Int_Count
	lda	#%11100000	;T1 Interrupt + T2 Interrupt
	sta	$912e
	lda	$9124		;ACK T1 interrupt.
	cli			;Enable nesting
t1_skp1:
	lda	Int_Sync	;Do we have a sync mode?
	bne	t1_ex1		;Yes, check start/stop flag.
		
	lda	#PlayColor
	jsr	SetPlayColor

	jsr	pl_Play

	jsr	DelayNormalColor
	rts
; In sync mode we just check for stop here.
t1_ex1:
	jsr	HandleStop
	rts
	
T2Timeout:
	dec	Int_Count
	bmi	t2_skp1		; Last Interrupt?
	lda	Int_CurCycles
	sta	$9128
	lda	Int_CurCycles+1
	sta	$9129	;load T2
t2_skp1:
	lda	$9128		;ACK T2 interrupt.

	lda	Int_Sync	;Do we have a sync mode?
	bne	t2_ex1		;Yes, Do nothing here.

	lda	#Play2Color
	jsr	SetPlayColor

	jsr	pl_Play

	jsr	DelayNormalColor

t2_ex1:
	rts

SetPlayColor:
	ldx	Int_ColorFlag
	beq	spc_ex1
	sta	$900f
spc_ex1:
	rts

DelayNormalColor:
	ldx	Int_ColorFlag
	beq	dnc_ex1

; if we are not playing, wait a while to ensure that the color is visible
	lda	pl_PlayFlag
	bne	dnc_skp1
	ldx	#10
dnc_lp1:
	dex
	bne	dnc_lp1
dnc_skp1:

	lda	#NormalColor
	sta	$900f
dnc_ex1:
	rts

;**************************************************************************
;*
;* Initialize Interrupts!
;*
;******
InterruptSyncInit:
	lda	#%01111111
	sta	$911e	;disable VIA#1 NMI interrupts
	sta	$911d	;clear pending ints. 


	lda	#0
	sta	LastStartStop
	lda	#1
	sta	SyncCount
	
; bit 0=clock (and CB1)
; bit 5=run
	lda	#%00000000	; All inputs
	sta	$9112	;Port B Data dir
	
	ldx	#<NMIServer
	ldy	#>NMIServer
	stx	$0318
	sty	$0319

;CB1, positive edge
	lda	$911c
	ora	#%00010000
	sta	$911c
	
	lda	#%01111111
	sta	$911d
	lda	#%10010000
	sta	$911e	;Enable CB1 VIA#1 NMI interrupts
	rts


HandleStop:
	lda	$9110
	and	#%00100000
	cmp	LastStartStop	; Did the Start/Stop bit change?
	beq	hstp_ex1	; No, just exit.
	sta	LastStartStop
	cmp	#0		; Shall we stop?
	bne	hstp_ex1	; No, just exit.
	jsr	pl_UnInit	; UnInit the song
hstp_ex1:
	rts

	
HandleStart:
	lda	$9110
	and	#%00100000
	cmp	LastStartStop	; Did the Start/Stop bit change?
	beq	hstr_ex1	; No, just exit.
	sta	LastStartStop
	cmp	#0		; Shall we Start?
	beq	hstr_ex1	; No, just exit.
	jsr	pl_Init		; Init the song
	lda	#1
	sta	SyncCount
hstr_ex1:
	rts

LastStartStop:
	dc.b	0
SyncCount:
	dc.b	0
	
;**************************************************************************
;*
;* NMI Interrupt server
;*
;******
NMIServer:
	pha
	txa
	pha
	tya
	pha
	
	lda	#Play2Color
	jsr	SetPlayColor

	jsr	HandleStart

	dec	SyncCount
	lda	SyncCount
	bne	ns_ex1
	lda	Int_Sync
	sta	SyncCount

	lda	#PlayColor
	jsr	SetPlayColor
	jsr	pl_Play

ns_ex1:
	jsr	DelayNormalColor

	pla
	tay
	pla
	tax
	pla
	rti
	
; eof
