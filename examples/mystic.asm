;**************************************************************************
;*
;* FILE  player.asm
;* Copyright (c) 1994, 2001, 2003 Daniel Kahlin <daniel@kahlin.net>
;* Written by Daniel Kahlin <daniel@kahlin.net>
;* $Id: player.asm,v 1.39 2003/08/27 10:42:14 tlr Exp $
;*
;* DESCRIPTION
;*   Player for vic-tracker tunes packed by vtcomp.
;*   Nice huh?
;*
;*   Initialize tune:
;*     jsr pl_Init 
;*
;*   Uninitialize tune:
;*     jsr pl_UnInit 
;*
;*   Every frame:
;*     jsr pl_Play
;*
;******
PL_SUPPORT_PORTFAST	EQU	1	;not yet implemented
PL_SUPPORT_PORTSLOW	EQU	1	;not yet implemented

; Player commands
	IFCONST	PL_SUPPORT_PORTFAST
PL_PORTUP	EQU	$10
PL_PORTDOWN	EQU	$20
	ENDIF ;PL_SUPPORT_PORTFAST
	IFCONST	PL_SUPPORT_PORTSLOW
PL_PORTUPSLOW	EQU	$50
PL_PORTDOWNSLOW	EQU	$60
	ENDIF ;PL_SUPPORT_PORTSLOW
PL_SETSOUND	EQU	$80
PL_CUTNOTE	EQU	$c0

PL_NUMVOICES	EQU	4

;The sound format
PL_SND_DURATION		EQU	0
PL_SND_FOFFS		EQU	1
PL_SND_GLIDE		EQU	2
PL_SND_ARPEGGIO		EQU	3

;**************************************************************************
;*
;* zero page allocation
;*
;******
	seg.u	zp
	org	$b0
PatternZP:	ds.w	1
PatternTabZP:	ds.w	1
pl_Temp1ZP:	ds.b	1
pl_Temp2ZP:	ds.b	1
pl_Temp3ZP:	ds.b	1

	seg	code
;**************************************************************************
;*
;* Start of generated code
;*
;******
pl_Init:
	jmp	pl_IInit
pl_UnInit:
	jmp	pl_UUnInit
pl_Play:
	jmp	pl_PPlay

;**************************************************************************
;*
;* Data
;*
;******
pl_PlayFlag:
	dc.b	0
pl_Speed:
	dc.b	0
pl_Count:
	dc.b	0
pl_FreqTab:
	dc.b	0
	dc.b	135,143,147,151,159,163,167,175,179,183,187,191
	dc.b	195,199,201,203,207,209,212,215,217,219,221,223
	dc.b	225,227,228,229,231,232,233,235,236,237,238,239
	dc.b	240,241
pl_VoiceData:
; The voice data structure
pl_vd_PatternTabLow:	dc.b	<pl_Tab1_0,<pl_Tab2_0,<pl_Tab3_0,<pl_Tab4_0 ;pointer to Pattlist
pl_vd_PatternTabHigh	dc.b	>pl_Tab1_0,>pl_Tab2_0,>pl_Tab3_0,>pl_Tab4_0 ;
pl_vd_ZeroBegin:	;!!Everything after this gets cleared!!
pl_vd_Note:		ds.b	PL_NUMVOICES	;Current Pitch
pl_vd_Param:		ds.b	PL_NUMVOICES	;Current Param
pl_vd_NextNote:		ds.b	PL_NUMVOICES	;Next Pitch
pl_vd_NextParam:	ds.b	PL_NUMVOICES	;Next Param
pl_vd_DurationCount:	ds.b	PL_NUMVOICES	;Duration Count
pl_vd_ThisNote:		ds.b	PL_NUMVOICES	;This Note   (These get updated when
pl_vd_ThisParam:	ds.b	PL_NUMVOICES	;This Param   pl_Retrig is called)
pl_vd_EffectiveNote:	ds.b	PL_NUMVOICES	;Effective Note
pl_vd_FreqOffsetLow:	ds.b	PL_NUMVOICES	;Current freqoffset
pl_vd_FreqOffsetHigh:	ds.b	PL_NUMVOICES	;Current freqoffset
pl_vd_Sound:		ds.b	PL_NUMVOICES	;Current Sound
pl_vd_PattlistStep:	ds.b	PL_NUMVOICES	;Step in pattlist
pl_vd_PattlistWait:	ds.b	PL_NUMVOICES	;Time before reading the next pattlist
                                        ;entry
pl_vd_CurrentPattern:	ds.b	PL_NUMVOICES
pl_vd_PatternStep:	ds.b	PL_NUMVOICES	;Step in pattern
pl_vd_PatternWait:	ds.b	PL_NUMVOICES	;Time before reading the next note.
pl_vd_ZeroEnd:		;!!Everything before this gets cleared!!
pl_vd_FetchMode:	ds.b	PL_NUMVOICES	;Fetch mode.

;**************************************************************************
;*
;* InitRoutine
;*
;******
pl_IInit:
	jsr	pl_UUnInit

	lda	pl_SongSpeed
	sta	pl_Speed
	lda	#0
	sta	pl_Count

	ldx	#PL_NUMVOICES-1
	lda	#$80
pli_lp1:
	sta	pl_vd_FetchMode,x
	dex
	bpl	pli_lp1
			

	lda	#0
	ldx	#pl_vd_ZeroEnd-pl_vd_ZeroBegin-1
pli_lp2:
	sta	pl_vd_ZeroBegin,x
	dex
	bpl	pli_lp2
	ldx	#PL_NUMVOICES-1
pli_lp3:
	jsr	pl_GetVoice
	jsr	pl_GetVoice	;Necessary for optimized players.
	dex
	bpl	pli_lp3

; Ok, now x=$ff
	stx	pl_PlayFlag	;Start Song! (pl_PlayFlag=$ff)

	lda	#$0f		;Set initial volume
	jsr	plpv_SetVolume
	rts

;**************************************************************************
;*
;* UnInitRoutine
;*
;******
pl_UUnInit:
	pha
	lda	#0
	sta	pl_PlayFlag	;Ensure that we don't try to play
; initialize sound registers
	sta	$900a
	sta	$900b
	sta	$900c
	sta	$900d
	jsr	plpv_SetVolume
	pla
	rts


;**************************************************************************
;*
;* PlayRoutine
;*
;******
pl_PPlay:
	lda	pl_PlayFlag
	beq	plpp_ex1

	dec	pl_Count
	bmi	pl_skp1

	ldx	pl_Count
	cpx	#PL_NUMVOICES	;is X less that PL_NUMVOICES? 
	bcs	pl_skp3		;no, skip out.
	jsr	pl_GetVoice	;fetch data for voice X.
	jmp	pl_skp3
plpp_ex1:
	rts
	
pl_skp1:

;*** Get Data from tune ***
	ldx	#PL_NUMVOICES-1
pl_lp1:
	jsr	pl_PreCheckEffects
	jsr	pl_Retrig
	jsr	pl_PostCheckEffects
	dex
	bpl	pl_lp1

	lda	pl_Speed
	sta	pl_Count

pl_skp3:
;*** play the voices ***
	ldx	#PL_NUMVOICES-1
pl_lp3:
	jsr	pl_PreUpdateVoice
	jsr	pl_PlayVoice
	jsr	pl_PostUpdateVoice
	dex
	bpl	pl_lp3

	rts


;**************************************************************************
;*
;* GetVoice
;* X=Voice
;*
;******
pl_GetVoice:

;*** Get Pointer To PatternTab ***
	lda	pl_vd_FetchMode,x
	cmp	#$80		;Fetch new pattern?
	bne	plgv_skp1	;No... skip

plgv_lp1:
;*** Get new entry from patternlist ***
	jsr	pl_GetPattlist

plgv_skp1:
;*** Read last note and param values ***
	lda	pl_vd_NextParam,x
	sta	pl_vd_Param,x
	lda	pl_vd_NextNote,x
	sta	pl_vd_Note,x

;*** Calculate pattern address ***

	ldy	pl_vd_CurrentPattern,x
	lda	pl_PatternsLow,y
	sta	PatternZP
	lda	pl_PatternsHigh,y
	sta	PatternZP+1

;*** Get Current NOTE and PARAM from Pattern ***
	lda	pl_vd_PatternWait,x
	beq	plgv_skp2
	sec
	sbc	#1
	sta	pl_vd_PatternWait,x
	jmp	plgv_skp4

plgv_skp2:

;*** Interpret pattern data ***
	ldy	pl_vd_PatternStep,x
	lda	(PatternZP),y	;Get Codebyte
	iny
	sta	pl_Temp1ZP
	and	#%11100000
	sta	pl_Temp2ZP
	cmp	#$80		;End of pattern?
	bne	plgv_skp3	;no... skip!

	sta	pl_vd_FetchMode,x
	lda	#0
	sta	pl_vd_PatternStep,x
	sta	pl_vd_PatternWait,x
	jmp	plgv_lp1	; Fetch new pattern

plgv_skp3:
	
	tya
	sta	pl_vd_PatternStep,x
	lda	pl_Temp1ZP
	and	#$1f
	sta	pl_vd_PatternWait,x
	lda	pl_Temp2ZP
	sta	pl_vd_FetchMode,x
	jsr	pl_Fetch
	jmp	plgv_ex1

plgv_skp4:
;*** fetch data ***
	lda	pl_vd_FetchMode,x
	bpl	plgv_ex1
	jsr	pl_Fetch
	
plgv_ex1:
	rts

;**************************************************************************
;*
;* GetPattlist
;* X=Voice
;*
;******
pl_GetPattlist:
	lda	pl_vd_PattlistWait,x
	beq	plgl_skp1
	sec
	sbc	#1
	sta	pl_vd_PattlistWait,x
	rts

plgl_skp1:
	lda	pl_vd_PatternTabLow,x
	sta	PatternTabZP
	lda	pl_vd_PatternTabHigh,x
	sta	PatternTabZP+1

;*** Get Address to Current Pattern ***
	ldy	pl_vd_PattlistStep,x
plgl_lp1:
	lda	#0
	sta	pl_Temp1ZP
	lda	(PatternTabZP),y
	bpl	plgl_skp3
	pha
	and	#$3f
	sta	pl_Temp1ZP
	pla
	and	#$c0
	cmp	#$c0
	bne	plgl_skp2	
	ldy	pl_Temp1ZP	;Starta om
	jmp	plgl_lp1	;st�mman
plgl_skp2:
	iny
	lda	(PatternTabZP),y
plgl_skp3:
	sta	pl_Temp2ZP

	iny
	tya
	sta	pl_vd_PattlistStep,x
	lda	pl_Temp1ZP
	sta	pl_vd_PattlistWait,x
	lda	pl_Temp2ZP
	sta	pl_vd_CurrentPattern,x
plgl_ex1:
	rts
	
;**************************************************************************
;*
;* Fetch
;* Acc=CodeByte X=Voice
;*
;******
pl_Fetch:
	ldy	pl_vd_PatternStep,x
	and	#$60
	beq	plf_Null
	cmp	#$20
	beq	plf_Pitch
	cmp	#$40
	beq	plf_Param

;*** fetch pitch+param ***
	lda	(PatternZP),y
	iny
	sta	pl_Temp1ZP
	lda	(PatternZP),y
	iny
	sta	pl_Temp2ZP
	jmp	plf_ex1

;*** set to zero ***
plf_Null:
	lda	#0
	sta	pl_Temp1ZP
	sta	pl_Temp2ZP
	jmp	plf_ex1
;*** fetch pitch ***
plf_Pitch:
	lda	(PatternZP),y
	iny
	sta	pl_Temp1ZP
	lda	#0
	sta	pl_Temp2ZP
	jmp	plf_ex1
;*** fetch param , pitch to $80 ***
plf_Param:
	lda	(PatternZP),y
	iny
	sta	pl_Temp2ZP
	lda	#$80
	sta	pl_Temp1ZP
	jmp	plf_ex1

plf_ex1:
	tya
	sta	pl_vd_PatternStep,x

	lda	pl_Temp2ZP
	sta	pl_vd_NextParam,x
	lda	pl_Temp1ZP
	sta	pl_vd_NextNote,x

	rts



;**************************************************************************
;*
;* PreCheckEffects
;* X=Voice
;*
;******
pl_PreCheckEffects:
	lda	pl_vd_Param,x
	and	#$f0
	cmp	#PL_SETSOUND
	beq	plpce_SetSound
	rts

plpce_SetSound:
	lda	pl_vd_Param,x
	and	#$0f
	asl
	asl
	sta	pl_vd_Sound,x
	rts
		

;**************************************************************************
;*
;* Retrig
;* X=Voice
;*
;******
pl_Retrig:
; Transfer the preloaded param
	lda	pl_vd_Param,x
	sta	pl_vd_ThisParam,x

; Transfer the preloaded Note (if not a tie.)
	lda	pl_vd_Note,x
	beq	plrt_ex2	; No note... skip out!
	cmp	#$80
	beq	plrt_skp3	; Last note... just update the duration and
				; skip out!
	lda	pl_vd_Note,x
	sta	pl_vd_ThisNote,x ; Update the note value.
	bmi	plrt_skp3	; No retrig... just update the duration and
				; skip out!

	lda	#0
	sta	pl_vd_FreqOffsetHigh,x
	lda	#$80
	sta	pl_vd_FreqOffsetLow,x     ;The initial value is $0080

	ldy	pl_vd_Sound,x	;Frequency offset from the sound
	lda	pl_Sounds+PL_SND_FOFFS,y
	beq	plrt_skp4	;Do not adjust from $0080 if we are
			        ;already there as this is kind of slow.
	jsr	pl_DoPortamentoSigned	;do portamento _once_.
plrt_skp4:


plrt_skp3:

	lda	pl_vd_NextNote,x ;If next note is Tie or noretrig
	bmi	plrt_skp1		     ; Play legato aswell!

;Fetch the duration from the current sound
	ldy	pl_vd_Sound,x
	lda	pl_Sounds+PL_SND_DURATION,y
	bne	plrt_skp2
plrt_skp1:
	lda	pl_Speed	;Duration 00 means set duration to speed
	clc
	adc	#1
plrt_skp2:
	sta	pl_vd_DurationCount,x
	
plrt_ex2:
	rts

;**************************************************************************
;*
;* PostCheckEffects
;* X=Voice
;*
;******
pl_PostCheckEffects:
	lda	pl_vd_Param,x
	and	#$f0

	cmp	#PL_CUTNOTE
	beq	plce_CutNote
plce_ex1:
	rts

plce_CutNote:
	lda	pl_vd_Param,x
	and	#$0f
	sta	pl_vd_DurationCount,x
	rts

;**************************************************************************
;*
;* PreUpdateVoice
;* X=Voice
;*
;******
pl_PreUpdateVoice:
; Handle the Duration Count
	lda	pl_vd_DurationCount,x
	beq	pl_puv_ex1	;Zero... silence it.
	sec
	sbc	#1
	sta	pl_vd_DurationCount,x ;decrease count
	lda	pl_vd_ThisNote,x
	and	#$7f
	sta	pl_vd_EffectiveNote,x ;set effective note
	rts
pl_puv_ex1:
; silence it.
	lda	#0
	sta	pl_vd_EffectiveNote,x

	sta	pl_vd_FreqOffsetLow,x
	sta	pl_vd_FreqOffsetHigh,x
	rts

;**************************************************************************
;*
;* PlayVoice
;* X=Voice
;*
;******
pl_PlayVoice:
	lda	pl_vd_EffectiveNote,x
	and	#$7f
	beq	plpv_SetValue
	cpx	#$03			;Is this the noise channel?
	beq	plpv_Noise
	tay
	lda	pl_FreqTab,y	;Freq
	beq	plpv_SetValue
plpv_Noise:
	clc
	adc	pl_vd_FreqOffsetHigh,x  ;Add frequency offset
	ora	#$80		;SetGate
	jmp	plpv_SetValue
plpv_SetVolume:
	and	#$0f
	sta	pl_Temp1ZP
	lda	$900e
	and	#$f0
	ora	pl_Temp1ZP
	sta	$900e
	rts

plpv_SetValue:
	sta	$900a,x
	rts
	
	

;**************************************************************************
;*
;* PostUpdateVoice
;* X=Voice
;*
;******
pl_PostUpdateVoice:
	jsr	pl_puv_UpdatePort
	rts

pl_puv_UpdatePort:
;*** Handle Portamento Effects ***
	lda	pl_vd_ThisParam,x
	tay
	and	#$0f
	sta	pl_Temp1ZP
	tya
	and	#$f0

	cmp	#PL_PORTUP
	beq	pl_PortamentoUp
	cmp	#PL_PORTDOWN
	beq	pl_PortamentoDown
	cmp	#PL_PORTUPSLOW
	beq	pl_PortamentoUpSlow
	cmp	#PL_PORTDOWNSLOW
	beq	pl_PortamentoDownSlow

	rts

;* run PORTUP *
pl_PortamentoUp:
	lda	#0
	jsr	pl_PreparePortamento
	jmp	pl_DoPortamentoUp

;* run PORTDOWN *
pl_PortamentoDown:
	lda	#0
	jsr	pl_PreparePortamento
	jmp	pl_DoPortamentoDown

;* run PORTUPSLOW *
pl_PortamentoUpSlow:
	jsr	pl_PreparePortamentoSlow
pl_DoPortamentoUp:
	lda	pl_vd_FreqOffsetLow,x
	clc
	adc	pl_Temp2ZP
	sta	pl_vd_FreqOffsetLow,x
	lda	pl_vd_FreqOffsetHigh,x
	adc	pl_Temp1ZP
	sta	pl_vd_FreqOffsetHigh,x
	rts

;* run PORTDOWNSLOW *
pl_PortamentoDownSlow:
	jsr	pl_PreparePortamentoSlow
pl_DoPortamentoDown:
	lda	pl_vd_FreqOffsetLow,x
	sec
	sbc	pl_Temp2ZP
	sta	pl_vd_FreqOffsetLow,x
	lda	pl_vd_FreqOffsetHigh,x
	sbc	pl_Temp1ZP
	sta	pl_vd_FreqOffsetHigh,x
	rts

pl_DoPortamentoSigned:	
	sta	pl_Temp1ZP
	bpl	pl_PortamentoUpSlow
	eor	#$ff
	clc
	adc	#1
	sta	pl_Temp1ZP
	jmp	pl_PortamentoDownSlow
	
pl_PreparePortamentoSlow:
	lda	#0
	lsr	pl_Temp1ZP
	ror
	lsr	pl_Temp1ZP
	ror
pl_PreparePortamento:
	lsr	pl_Temp1ZP
	ror
	sta	pl_Temp2ZP
	rts



;**************************************************************************
;*
;* vic-tracker module
;*
;* This file was generated by:
;*   vtcomp (victracker) 2.0 by Daniel Kahlin <daniel@kahlin.net>
;*
;* used effects:
;*  - 0 None
;*  - 1 Portamento Up
;*  - 8 Set Sound
;*  - c Cut Note
;* number of songs ...... 1
;* number of patterns ... 7
;* number of sounds ..... 3
;* number of arpeggios .. 0
;* min speed count ...... 7
;*
;******
pl_SongSpeed:
	dc.b	$07
pl_Sounds:
	dc.b	$00,$00,$00,$00
	dc.b	$02,$00,$00,$00
	dc.b	$04,$00,$00,$00
pl_ArpeggioIndex:
pl_Arpeggios:
pl_ArpeggioConf:
pl_Tab1_0:
	dc.b	$02,$03,$02,$03,$c0
pl_Tab2_0:
	dc.b	$81,$00,$06,$05,$c0
pl_Tab3_0:
	dc.b	$81,$00,$05,$06,$c0
pl_Tab4_0:
	dc.b	$83,$04,$c0
pl_PatternsLow:
	dc.b	<pl_Patt00,<pl_Patt01,<pl_Patt02,<pl_Patt03,<pl_Patt04
	dc.b	<pl_Patt05,<pl_Patt06
pl_PatternsHigh:
	dc.b	>pl_Patt00,>pl_Patt01,>pl_Patt02,>pl_Patt03,>pl_Patt04
	dc.b	>pl_Patt05,>pl_Patt06
pl_Patt00:
	dc.b	$1b,$80
pl_Patt01:
	dc.b	$1b,$80
pl_Patt02:
	dc.b	$a1,$0d,$00,$01,$a1,$19,$00,$00,$a1,$0d,$00,$00,$a5,$19,$00,$0b
	dc.b	$00,$0d,$00,$01,$a1,$19,$00,$00,$a1,$0d,$00,$00,$a1,$19,$00,$01
	dc.b	$80
pl_Patt03:
	dc.b	$20,$0d,$62,$01,$c3,$20,$19,$ee,$01,$c3,$01,$c0,$0d,$00,$01,$c3
	dc.b	$00,$00,$19,$00,$00,$00,$0b,$00,$00,$00,$0d,$00,$00,$00,$01,$c3
	dc.b	$00,$00,$19,$00,$01,$c3,$e2,$01,$c3,$0d,$00,$01,$c3,$e2,$01,$c3
	dc.b	$19,$00,$17,$c1,$61,$17,$c1,$80
pl_Patt04:
	dc.b	$e3,$00,$81,$00,$00,$7e,$00,$00,$00,$01,$a1,$7e,$00,$01,$a1,$7e
	dc.b	$00,$03,$a1,$7e,$00,$01,$a1,$7e,$00,$01,$a1,$7e,$00,$01,$80
pl_Patt05:
	dc.b	$e2,$0b,$82,$0d,$00,$00,$00,$02,$a9,$0b,$00,$0d,$0e,$11,$00,$0e
	dc.b	$11,$0d,$00,$0b,$80
pl_Patt06:
	dc.b	$e2,$0b,$82,$0d,$00,$00,$00,$02,$ad,$0b,$00,$0d,$0e,$11,$00,$0e
	dc.b	$11,$0d,$00,$0e,$11,$0d,$00,$00,$a1,$0b,$00,$00,$a1,$09,$00,$e1
	dc.b	$08,$c8,$80,$12,$80
; eof
