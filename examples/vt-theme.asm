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
;*   Read UserFlag into Acc:
;*     jsr pl_ReadFlag
;*
;******
PL_SUPPORT_PORTFAST	EQU	1	;not yet implemented
PL_SUPPORT_PORTSLOW	EQU	1	;not yet implemented

; Player commands
	IFCONST	PL_SUPPORT_PORTFAST
PL_PORTUP	EQU	$10
PL_PORTDOWN	EQU	$20
	ENDIF ;PL_SUPPORT_PORTFAST
PL_ARPEGGIO	EQU	$30
	IFCONST	PL_SUPPORT_PORTSLOW
PL_PORTUPSLOW	EQU	$50
PL_PORTDOWNSLOW	EQU	$60
	ENDIF ;PL_SUPPORT_PORTSLOW
PL_SETUSERFLAG	EQU	$70
PL_SETSOUND	EQU	$80
PL_CUTNOTE	EQU	$c0
PL_DELAYNOTE	EQU	$d0

PL_NUMVOICES	EQU	5

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
pl_ReadFlag:
	jmp	pl_RReadFlag

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
pl_UserFlag:
	dc.b	0
pl_FreqTab:
	dc.b	0
	dc.b	135,143,147,151,159,163,167,175,179,183,187,191
	dc.b	195,199,201,203,207,209,212,215,217,219,221,223
	dc.b	225,227,228,229,231,232,233,235,236,237,238,239
	dc.b	240,241
pl_VoiceData:
; The voice data structure
pl_vd_PatternTabLow:	dc.b	<pl_Tab1_0,<pl_Tab2_0,<pl_Tab3_0,<pl_Tab4_0,<pl_Tab5_0 ;pointer to Pattlist
pl_vd_PatternTabHigh	dc.b	>pl_Tab1_0,>pl_Tab2_0,>pl_Tab3_0,>pl_Tab4_0,>pl_Tab5_0 ;
pl_vd_ZeroBegin:	;!!Everything after this gets cleared!!
pl_vd_Note:		ds.b	PL_NUMVOICES	;Current Pitch
pl_vd_Param:		ds.b	PL_NUMVOICES	;Current Param
pl_vd_NextNote:		ds.b	PL_NUMVOICES	;Next Pitch
pl_vd_NextParam:	ds.b	PL_NUMVOICES	;Next Param
pl_vd_DelayCount:	ds.b	PL_NUMVOICES	;Delay Count
pl_vd_DurationCount:	ds.b	PL_NUMVOICES	;Duration Count
pl_vd_ThisNote:		ds.b	PL_NUMVOICES	;This Note   (These get updated when
pl_vd_ThisParam:	ds.b	PL_NUMVOICES	;This Param   pl_Retrig is called)
pl_vd_EffectiveNote:	ds.b	PL_NUMVOICES	;Effective Note
pl_vd_FreqOffsetLow:	ds.b	PL_NUMVOICES	;Current freqoffset
pl_vd_FreqOffsetHigh:	ds.b	PL_NUMVOICES	;Current freqoffset
pl_vd_ArpMode:		ds.b	PL_NUMVOICES	;Arpeggio Mode
pl_vd_ArpStep:		ds.b	PL_NUMVOICES	;Arpeggio step
pl_vd_ArpOffset:	ds.b	PL_NUMVOICES	;Arpeggio note offset
pl_vd_ArpCount:		ds.b	PL_NUMVOICES	;Arpeggio count
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
	sta	pl_UserFlag
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
;* Read flag
;*
;******
pl_RReadFlag:
	lda	pl_UserFlag
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
	jmp	plgl_lp1	;stämman
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
	cpx	#$04
	beq	plpce_VolumeTempo

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
		
plpce_VolumeTempo:
	lda	pl_vd_Note,x
	and	#$f0
	beq	plcevt_ex1
	lsr
	lsr
	lsr
	lsr
	sta	pl_Speed
plcevt_ex1:
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
	sta	pl_vd_DelayCount,x
	sta	pl_vd_ArpMode,x
	sta	pl_vd_ArpStep,x
	sta	pl_vd_ArpOffset,x
	sta	pl_vd_ArpCount,x
	sta	pl_vd_FreqOffsetHigh,x
	lda	#$80
	sta	pl_vd_FreqOffsetLow,x     ;The initial value is $0080

	ldy	pl_vd_Sound,x	;Frequency offset from the sound
	lda	pl_Sounds+PL_SND_FOFFS,y
	beq	plrt_skp4	;Do not adjust from $0080 if we are
			        ;already there as this is kind of slow.
	jsr	pl_DoPortamentoSigned	;do portamento _once_.
plrt_skp4:

;Does this Command indicate arpeggio?
	lda	pl_vd_Param,x
	pha
	and	#$f0
	tay
	pla
	cpy	#PL_ARPEGGIO
	beq	plrt_Arpeggio	;Yes, run it!

;Does this sound indicate arpeggio?
	ldy	pl_vd_Sound,x
	lda	pl_Sounds+PL_SND_ARPEGGIO,y
	bpl	plrt_skp3	;no, skip it!

; If we have an arpeggio, we must set up the initial offset
; when we are at it we determine the mode aswell.
plrt_Arpeggio:
	and	#$0f
	tay
	asl
	sta	pl_Temp1ZP	;pl_Temp1ZP=ArpNum*2
	lda	pl_ArpeggioIndex,y
	tay			;y=ArpNum*16
	lda	pl_Arpeggios,y
	sta	pl_vd_ArpOffset,x
	ldy	pl_Temp1ZP
	lda	pl_ArpeggioConf,y
	and	#$f0
	sta	pl_vd_ArpMode,x

plrt_skp3:

	cpx	#$04		;Volume/tempo channel always play legato
	beq	plrt_skp1

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
	cmp	#PL_SETUSERFLAG
	beq	plce_UserFlag
	cmp	#PL_DELAYNOTE
	beq	plce_DelayNote

	cmp	#PL_CUTNOTE
	beq	plce_CutNote
plce_ex1:
	rts

plce_UserFlag:
	lda	pl_vd_Param,x
	and	#$0f
	sta	pl_UserFlag
	rts
plce_CutNote:
	lda	pl_vd_Param,x
	and	#$0f
	sta	pl_vd_DurationCount,x
	rts
plce_DelayNote:
	lda	pl_vd_Param,x
	and	#$0f
	sta	pl_vd_DelayCount,x
	rts

;**************************************************************************
;*
;* PreUpdateVoice
;* X=Voice
;*
;******
pl_PreUpdateVoice:
; Handle the Delay Count
	lda	pl_vd_DelayCount,x
	bne	pl_puv_ex2	;Not zero... decrease and keep it silent.

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
pl_puv_ex2:	
	sec
	sbc	#1
	sta	pl_vd_DelayCount,x
pl_puv_ex1:
; silence it.
	lda	#0
	sta	pl_vd_EffectiveNote,x

	sta	pl_vd_FreqOffsetLow,x
	sta	pl_vd_FreqOffsetHigh,x
	sta	pl_vd_ArpStep,x
	sta	pl_vd_ArpOffset,x
	sta	pl_vd_ArpCount,x
	rts

;**************************************************************************
;*
;* PlayVoice
;* X=Voice
;*
;******
pl_PlayVoice:
	cpx	#$04			;Is VOL/Speed channel?
	beq	plpv_VolumeTempo


; Arpeggio modes 0 and 1
;Get note in, and put it in pl_Temp2ZP
	lda	pl_vd_EffectiveNote,x
	and	#$7f
	beq	plpv_SetValue
	sta	pl_Temp2ZP

;put FreqOffset in pl_Temp1ZP.
	lda	pl_vd_FreqOffsetHigh,x
	sta	pl_Temp1ZP
;Preserve ArpOffset into pl_Temp3ZP
	lda	pl_vd_ArpOffset,x
	sta	pl_Temp3ZP
	beq	plpv_skp4	; If no offset, play as fast as possible
	
;Clear out FreqOffset in pl_Temp1ZP if ArpOffset bit 7 is set.
	bit	pl_Temp3ZP
	bpl	plpv_skp1
	lda	#0
	sta	pl_Temp1ZP
plpv_skp1:

	lda	pl_vd_ArpMode,x
	cmp	#$10
	beq	plpv_ArpMode10	

plpv_ArpMode00:
;put new absolute note into pl_Temp2ZP if ArpOffset bit 6 is set.
	bit	pl_Temp3ZP
	bvc	plpv_skp3
	lda	pl_Temp3ZP
	and	#$3f
	sta	pl_Temp2ZP
	jmp	plpv_skp4

plpv_skp3:
	lda	pl_Temp3ZP	;Acc=pl_Temp3ZP signextended with 2 bits.
	asl
	asl
	pha
	asl
	pla
	ror
	pha
	asl
	pla
	ror

	clc
	adc	pl_Temp2ZP
	sta	pl_Temp2ZP

plpv_skp4:		
	lda	pl_Temp2ZP	;Acc = EffectiveNote
	cpx	#$03			;Is this the noise channel?
	beq	plpv00_Noise
	tay
	lda	pl_FreqTab,y	;Freq
	beq	plpv_SetValue
plpv00_Noise:
	clc
	adc	pl_Temp1ZP	;Add frequency offset
	ora	#$80		;SetGate
	jmp	plpv_SetValue

plpv_ArpMode10:	
	lda	pl_Temp2ZP	;Acc = EffectiveNote
	cpx	#$03			;Is this the noise channel?
	beq	plpv10_Noise
	tay
	lda	pl_FreqTab,y	;Freq
	beq	plpv_SetValue
plpv10_Noise:
	;Acc = Effective note
	clc 	; note:	output value is only 7-bit, so no need to
		; sign extend here.

	adc	pl_Temp3ZP	;Add arp offset
	clc
	adc	pl_Temp1ZP	;Add frequency offset
	ora	#$80		;SetGate
	jmp	plpv_SetValue

plpv_VolumeTempo:
;*** Handle Volume ***
	lda	pl_vd_EffectiveNote,x
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
	jsr	pl_puv_UpdateArp
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

	ldy	pl_vd_Sound,x	; Portamento enabled from the sound?
	lda	pl_Sounds+PL_SND_GLIDE,y
	beq	plpuv_skp2	;No, skip it!
	jmp	pl_DoPortamentoSigned	;Yes, do portamento.
plpuv_skp2:
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

pl_puv_UpdateArp:
;*** Handle Arpeggio Effects ***
	lda	pl_vd_ThisParam,x
	tay
	and	#$0f
	sta	pl_Temp1ZP
	tya
	and	#$f0

	cmp	#PL_ARPEGGIO
	beq	pl_Arpeggio

	ldy	pl_vd_Sound,x	;Arpeggio enabled from the sound?
	lda	pl_Sounds+PL_SND_ARPEGGIO,y
	bpl	plpuv_skp1	;No, skip it!
	and	#$0f
	sta	pl_Temp1ZP
	jmp	pl_Arpeggio	;Yes, do arpeggio.
plpuv_skp1:
	rts

;* run ARPEGGIO *
pl_Arpeggio:
	lda	pl_Temp1ZP
	pha
	tay
	lda	pl_ArpeggioIndex,y
	sta	pl_Temp1ZP	;pl_Temp1ZP=Arpnum*16
	pla
	asl
	tay			;y=Arpnum * 2
		
	lda	pl_ArpeggioConf,y
	and	#$0f		;Acc=Speed
	cmp	pl_vd_ArpCount,x
	bne	pl_arp_ex1
	lda	#0
	sta	pl_vd_ArpCount,x

	lda	pl_ArpeggioConf+1,y
	and	#$0f		;Acc=endstep
	cmp	pl_vd_ArpStep,x
	bne	pl_arp_skp1
	lda	pl_ArpeggioConf+1,y
	lsr
	lsr
	lsr
	lsr			;Acc=startstep
	sta	pl_vd_ArpStep,x
	jmp	pl_arp_skp2
pl_arp_skp1:
	lda	pl_vd_ArpStep,x
	clc
	adc	#1
	sta	pl_vd_ArpStep,x
pl_arp_skp2:
	lda	pl_vd_ArpStep,x
	clc
	adc	pl_Temp1ZP
	tay
	lda	pl_Arpeggios,y
	sta	pl_vd_ArpOffset,x
	rts
pl_arp_ex1:
	lda	pl_vd_ArpCount,x
	clc
	adc	#1
	sta	pl_vd_ArpCount,x
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
;*  - 3 Arpeggio
;*  - 5 Portamento Up (Slow)
;*  - 6 Portamento Down (Slow)
;*  - 7 Set User Flag
;*  - 8 Set Sound
;*  - c Cut Note
;*  - d Delay Note
;* number of songs ...... 1
;* number of patterns ... 13
;* number of sounds ..... 7
;* number of arpeggios .. 3
;* min speed count ...... 8
;*
;******
pl_SongSpeed:
	dc.b	$08
pl_Sounds:
	dc.b	$00,$00,$00,$00
	dc.b	$05,$00,$00,$00
	dc.b	$04,$00,$00,$80
	dc.b	$12,$00,$00,$82
	dc.b	$04,$00,$f0,$00
	dc.b	$04,$00,$fc,$00
	dc.b	$02,$00,$00,$00
pl_ArpeggioIndex:
	dc.b	pl_Arp00-pl_Arpeggios
	dc.b	pl_Arp01-pl_Arpeggios
	dc.b	pl_Arp02-pl_Arpeggios
pl_Arpeggios:
pl_Arp00:
	dc.b	$0c,$40,$0c,$0c,$00,$00,$00,$00,$00
pl_Arp01:
	dc.b	$00,$00,$01,$00,$00,$00,$ff,$00,$00,$01,$02,$01,$00,$ff,$fe,$ff
pl_Arp02:
	dc.b	$fe,$ff,$01,$00
pl_ArpeggioConf:
	dc.b	$00,$08
	dc.b	$11,$8f
	dc.b	$10,$33
pl_Tab1_0:
	dc.b	$81,$02,$04,$81,$02,$07,$81,$02,$c2
pl_Tab2_0:
	dc.b	$81,$03,$00,$81,$03,$07,$81,$03,$c2
pl_Tab3_0:
	dc.b	$09,$00,$05,$06,$00,$08,$06,$00,$c2
pl_Tab4_0:
	dc.b	$81,$0b,$82,$0b,$0c,$81,$0b,$c2
pl_Tab5_0:
	dc.b	$0a,$01,$85,$01,$c2
pl_PatternsLow:
	dc.b	<pl_Patt00,<pl_Patt01,<pl_Patt02,<pl_Patt03,<pl_Patt04
	dc.b	<pl_Patt05,<pl_Patt06,<pl_Patt07,<pl_Patt08,<pl_Patt09
	dc.b	<pl_Patt0a,<pl_Patt0b,<pl_Patt0c
pl_PatternsHigh:
	dc.b	>pl_Patt00,>pl_Patt01,>pl_Patt02,>pl_Patt03,>pl_Patt04
	dc.b	>pl_Patt05,>pl_Patt06,>pl_Patt07,>pl_Patt08,>pl_Patt09
	dc.b	>pl_Patt0a,>pl_Patt0b,>pl_Patt0c
pl_Patt00:
	dc.b	$1f,$80
pl_Patt01:
	dc.b	$3f,$0f,$80
pl_Patt02:
	dc.b	$e2,$0a,$81,$0a,$00,$16,$00,$a1,$16,$0a,$a1,$0a,$16,$a1,$16,$0a
	dc.b	$a1,$0a,$16,$a1,$16,$0a,$a1,$0a,$16,$a1,$16,$0a,$a1,$0a,$16,$a1
	dc.b	$16,$0a,$a1,$0a,$16,$a1,$16,$0a,$a1,$0a,$16,$a1,$16,$08,$a1,$08
	dc.b	$14,$20,$14,$80
pl_Patt03:
	dc.b	$03,$e1,$0e,$82,$0e,$00,$21,$0e,$00,$23,$0a,$02,$a1,$0c,$00,$01
	dc.b	$a3,$0c,$00,$18,$80,$23,$80,$a1,$16,$80,$21,$80,$80
pl_Patt04:
	dc.b	$e2,$0d,$81,$0d,$00,$19,$00,$a1,$19,$0d,$a1,$0d,$19,$a1,$19,$0d
	dc.b	$a1,$0d,$19,$a1,$19,$0d,$a1,$0d,$19,$a1,$19,$0d,$a1,$0d,$19,$a1
	dc.b	$19,$0d,$a1,$0d,$19,$a1,$19,$0d,$a1,$0d,$19,$a1,$19,$0b,$a1,$0b
	dc.b	$17,$20,$17,$80
pl_Patt05:
	dc.b	$e1,$00,$83,$00,$00,$01,$a1,$08,$00,$01,$a1,$0a,$00,$01,$a1,$0d
	dc.b	$00,$01,$a1,$11,$00,$01,$a1,$0f,$00,$01,$a1,$0d,$00,$01,$a1,$0f
	dc.b	$00,$01,$80
pl_Patt06:
	dc.b	$e3,$0d,$51,$80,$51,$0e,$31,$80,$31,$42,$31,$e3,$0e,$65,$80,$65
	dc.b	$00,$c0,$00,$00,$14,$80
pl_Patt07:
	dc.b	$ff,$0a,$81,$0a,$d3,$0a,$d6,$00,$00,$0a,$00,$0a,$d3,$0a,$d6,$00
	dc.b	$00,$0c,$00,$0c,$d3,$0c,$d6,$00,$00,$0c,$00,$0c,$d3,$0c,$d6,$00
	dc.b	$00,$0d,$00,$0d,$d3,$0d,$d6,$00,$00,$0d,$00,$0d,$d3,$0d,$d6,$00
	dc.b	$00,$0f,$00,$0f,$d3,$0f,$d6,$00,$00,$0f,$00,$0d,$d3,$0c,$d6,$00
	dc.b	$00,$80
pl_Patt08:
	dc.b	$e1,$00,$83,$00,$00,$01,$a1,$08,$00,$01,$a1,$0a,$00,$01,$a1,$0d
	dc.b	$00,$01,$e2,$13,$63,$14,$00,$80,$31,$40,$31,$a1,$0f,$00,$00,$e1
	dc.b	$0d,$d8,$00,$00,$02,$e1,$0f,$d1,$00,$00,$01,$80
pl_Patt09:
	dc.b	$07,$e1,$0d,$54,$80,$64,$40,$64,$06,$e1,$0d,$54,$80,$64,$40,$64
	dc.b	$05,$e1,$0d,$54,$80,$64,$40,$64,$01,$80
pl_Patt0a:
	dc.b	$27,$0f,$e1,$0f,$71,$0f,$00,$27,$0f,$e1,$0f,$72,$0f,$00,$26,$0f
	dc.b	$e1,$0f,$73,$0f,$00,$22,$0f,$80
pl_Patt0b:
	dc.b	$ff,$40,$85,$00,$00,$7e,$86,$7e,$00,$70,$84,$00,$00,$7e,$86,$7e
	dc.b	$00,$40,$85,$00,$00,$40,$85,$00,$00,$70,$84,$00,$00,$7e,$86,$7e
	dc.b	$00,$40,$85,$00,$00,$7e,$86,$00,$00,$70,$84,$7e,$86,$7e,$00,$7e
	dc.b	$00,$40,$85,$00,$00,$7e,$86,$00,$00,$70,$84,$00,$00,$7e,$86,$80
	dc.b	$00,$80
pl_Patt0c:
	dc.b	$e1,$40,$85,$00,$00,$01,$a1,$40,$00,$01,$a1,$40,$00,$01,$a1,$40
	dc.b	$00,$01,$a1,$40,$00,$01,$a1,$40,$00,$01,$a1,$40,$00,$01,$a1,$40
	dc.b	$00,$e1,$7e,$86,$80,$00,$80
; eof
