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
;*     lda #Song
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
PL_ARPEGGIO	EQU	$30
	IFCONST	PL_SUPPORT_PORTSLOW
PL_PORTUPSLOW	EQU	$50
PL_PORTDOWNSLOW	EQU	$60
	ENDIF ;PL_SUPPORT_PORTSLOW
PL_SETSOUND	EQU	$80
PL_CUTNOTE	EQU	$c0

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
pl_vd_PatternTabLow:	ds.b	PL_NUMVOICES	;pointer to Pattlist
pl_vd_PatternTabHigh:	ds.b	PL_NUMVOICES	;
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

	tax			;X=Song
	sta	pl_Temp1ZP
	asl
	asl
	clc
	adc	pl_Temp1ZP
	tay			;Y=Song*5
	lda	pl_SongSpeed,x
	sta	pl_Speed
	ldx	#0
	stx	pl_Count
pli_lp1:
	lda	pl_SongLow,y
	sta	pl_vd_PatternTabLow,x
	lda	pl_SongHigh,y
	sta	pl_vd_PatternTabHigh,x
	lda	#$80
	sta	pl_vd_FetchMode,x
	iny
	inx
	cpx	#PL_NUMVOICES
	bne	pli_lp1
			

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

	lda	pl_Count
	beq	pl_o3step0
	cmp	#1
	beq	pl_o3step1
	cmp	#2
	beq	pl_o3step2
	jmp	pl_skp3
plpp_ex1:
	rts
pl_o3step0:
	ldx	#0
	jsr	pl_GetVoice
	jmp	pl_skp3
pl_o3step1:
	ldx	#2
	jsr	pl_GetVoice
	dex
	jsr	pl_GetVoice
	jmp	pl_skp3
pl_o3step2:
	ldx	#4
	jsr	pl_GetVoice
	dex
	jsr	pl_GetVoice
	jmp	pl_skp3
	
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
;*  - 1 Portamento Up
;*  - 2 Portamento Down
;*  - 3 Arpeggio
;* number of songs ...... 2
;* number of patterns ... 27
;* number of sounds ..... 1
;* number of arpeggios .. 1
;* min speed count ...... 4
;*
;******
pl_SongSpeed:
	dc.b	$04
	dc.b	$04
pl_SongLow:
	dc.b	<pl_Tab1_0,<pl_Tab2_0,<pl_Tab3_0,<pl_Tab4_0,<pl_Tab5_0
	dc.b	<pl_Tab1_1,<pl_Tab2_1,<pl_Tab3_1,<pl_Tab4_1,<pl_Tab5_1
pl_SongHigh:
	dc.b	>pl_Tab1_0,>pl_Tab2_0,>pl_Tab3_0,>pl_Tab4_0,>pl_Tab5_0
	dc.b	>pl_Tab1_1,>pl_Tab2_1,>pl_Tab3_1,>pl_Tab4_1,>pl_Tab5_1
pl_Sounds:
	dc.b	$00,$fc,$00,$00
pl_ArpeggioIndex:
	dc.b	pl_Arp00-pl_Arpeggios
pl_Arpeggios:
pl_Arp00:
	dc.b	$00,$04,$07,$0c,$04,$07,$0c,$0c
pl_ArpeggioConf:
	dc.b	$00,$07
pl_Tab1_0:
	dc.b	$83,$04,$83,$1a,$83,$08,$85,$04,$81,$19,$82,$08,$19,$0d,$0e,$c0
pl_Tab2_0:
	dc.b	$82,$03,$07,$82,$03,$07,$83,$00,$83,$03,$87,$16,$81,$00,$c0
pl_Tab3_0:
	dc.b	$81,$09,$05,$06,$81,$09,$05,$06,$82,$0a,$13,$14,$18,$14,$15,$87
	dc.b	$00,$0b,$0c,$c0
pl_Tab4_0:
	dc.b	$8f,$12,$87,$17,$81,$12,$c0
pl_Tab5_0:
	dc.b	$99,$02,$c0
pl_Tab1_1:
	dc.b	$83,$00,$c0
pl_Tab2_1:
	dc.b	$83,$00,$c0
pl_Tab3_1:
	dc.b	$0f,$10,$0f,$11,$c0
pl_Tab4_1:
	dc.b	$83,$01,$c0
pl_Tab5_1:
	dc.b	$83,$02,$c0
pl_PatternsLow:
	dc.b	<pl_Patt00,<pl_Patt01,<pl_Patt02,<pl_Patt03,<pl_Patt04
	dc.b	<pl_Patt05,<pl_Patt06,<pl_Patt07,<pl_Patt08,<pl_Patt09
	dc.b	<pl_Patt0a,<pl_Patt0b,<pl_Patt0c,<pl_Patt0d,<pl_Patt0e
	dc.b	<pl_Patt0f,<pl_Patt10,<pl_Patt11,<pl_Patt12,<pl_Patt13
	dc.b	<pl_Patt14,<pl_Patt15,<pl_Patt16,<pl_Patt17,<pl_Patt18
	dc.b	<pl_Patt19,<pl_Patt1a
pl_PatternsHigh:
	dc.b	>pl_Patt00,>pl_Patt01,>pl_Patt02,>pl_Patt03,>pl_Patt04
	dc.b	>pl_Patt05,>pl_Patt06,>pl_Patt07,>pl_Patt08,>pl_Patt09
	dc.b	>pl_Patt0a,>pl_Patt0b,>pl_Patt0c,>pl_Patt0d,>pl_Patt0e
	dc.b	>pl_Patt0f,>pl_Patt10,>pl_Patt11,>pl_Patt12,>pl_Patt13
	dc.b	>pl_Patt14,>pl_Patt15,>pl_Patt16,>pl_Patt17,>pl_Patt18
	dc.b	>pl_Patt19,>pl_Patt1a
pl_Patt00:
	dc.b	$1f,$80
pl_Patt01:
	dc.b	$1f,$80
pl_Patt02:
	dc.b	$bf,$0f,$08,$0c,$04,$0f,$08,$0c,$04,$0f,$08,$0c,$04,$0f,$08,$0c
	dc.b	$04,$0f,$08,$0c,$04,$0f,$08,$0c,$04,$0f,$08,$0c,$04,$0f,$08,$0c
	dc.b	$04,$80
pl_Patt03:
	dc.b	$e1,$19,$30,$80,$30,$41,$30,$0b,$e2,$19,$30,$80,$30,$00,$00,$0c
	dc.b	$80
pl_Patt04:
	dc.b	$bf,$0d,$00,$0d,$00,$19,$00,$0d,$00,$0d,$00,$0d,$00,$19,$00,$0d
	dc.b	$00,$0d,$00,$0d,$00,$19,$00,$0d,$00,$0d,$00,$17,$00,$0d,$00,$19
	dc.b	$00,$80
pl_Patt05:
	dc.b	$e2,$17,$11,$80,$11,$00,$00,$00,$a1,$19,$00,$03,$a1,$1d,$00,$03
	dc.b	$a1,$20,$00,$03,$a1,$1d,$00,$e7,$1d,$11,$00,$00,$1d,$00,$00,$00
	dc.b	$1d,$11,$00,$00,$20,$00,$00,$00,$80
pl_Patt06:
	dc.b	$e5,$20,$21,$80,$00,$1d,$00,$00,$00,$19,$00,$00,$00,$19,$80
pl_Patt07:
	dc.b	$e1,$19,$30,$80,$30,$41,$30,$0b,$e2,$19,$30,$80,$30,$00,$00,$02
	dc.b	$e2,$19,$30,$80,$30,$00,$00,$06,$80
pl_Patt08:
	dc.b	$bf,$0f,$00,$1b,$00,$0f,$00,$1b,$00,$0f,$00,$1b,$00,$1b,$00,$0f
	dc.b	$00,$0f,$00,$0f,$00,$1b,$00,$0f,$00,$0f,$00,$0d,$00,$12,$00,$0d
	dc.b	$00,$80
pl_Patt09:
	dc.b	$e2,$17,$11,$80,$11,$00,$00,$00,$a1,$19,$00,$03,$a1,$1d,$00,$03
	dc.b	$a1,$20,$00,$03,$a1,$1d,$00,$e5,$1d,$11,$00,$00,$20,$00,$00,$00
	dc.b	$1d,$00,$00,$00,$01,$80
pl_Patt0a:
	dc.b	$e2,$19,$11,$80,$11,$00,$00,$00,$a1,$1b,$00,$01,$a3,$19,$00,$16
	dc.b	$00,$03,$a7,$19,$00,$16,$00,$19,$00,$1b,$00,$07,$80
pl_Patt0b:
	dc.b	$f8,$0d,$11,$80,$12,$12,$00,$80,$00,$17,$00,$00,$00,$1b,$00,$00
	dc.b	$00,$19,$00,$80,$21,$17,$00,$00,$00,$14,$00,$00,$00,$12,$00,$00
	dc.b	$00,$14,$11,$00,$00,$14,$11,$00,$00,$14,$11,$80,$21,$12,$00,$80
	dc.b	$00,$00,$00,$00,$a5,$17,$00,$19,$00,$17,$00,$80
pl_Patt0c:
	dc.b	$ef,$19,$11,$00,$00,$19,$11,$00,$00,$19,$11,$80,$21,$80,$00,$00
	dc.b	$00,$14,$00,$80,$11,$17,$00,$00,$00,$19,$00,$00,$00,$17,$00,$80
	dc.b	$00,$21,$80,$0d,$80
pl_Patt0d:
	dc.b	$af,$0b,$00,$0b,$00,$0b,$00,$0b,$00,$08,$00,$08,$00,$06,$00,$06
	dc.b	$00,$e8,$08,$11,$00,$00,$08,$11,$00,$00,$08,$11,$80,$21,$04,$00
	dc.b	$80,$00,$00,$00,$00,$a5,$04,$00,$04,$00,$04,$00,$80
pl_Patt0e:
	dc.b	$b7,$0b,$00,$0b,$00,$0b,$00,$0b,$00,$08,$00,$08,$00,$04,$00,$04
	dc.b	$00,$0b,$00,$0b,$00,$0b,$00,$0b,$80,$a1,$80,$00,$05,$80
pl_Patt0f:
	dc.b	$a6,$1b,$00,$1c,$00,$1b,$00,$1e,$40,$11,$b5,$20,$00,$1e,$00,$1b
	dc.b	$00,$19,$00,$17,$00,$19,$00,$1b,$00,$19,$00,$14,$00,$14,$00,$14
	dc.b	$80,$21,$80,$80
pl_Patt10:
	dc.b	$a6,$14,$00,$16,$00,$14,$00,$16,$40,$11,$b5,$16,$00,$16,$00,$14
	dc.b	$00,$12,$00,$12,$00,$16,$00,$19,$00,$17,$00,$1b,$00,$1b,$00,$1b
	dc.b	$00,$01,$80
pl_Patt11:
	dc.b	$20,$14,$40,$11,$b3,$16,$00,$19,$00,$17,$00,$1b,$00,$19,$00,$17
	dc.b	$00,$14,$00,$12,$00,$14,$00,$17,$80,$a1,$80,$00,$07,$80
pl_Patt12:
	dc.b	$a3,$50,$00,$50,$00,$03,$a1,$70,$00,$05,$a1,$50,$00,$05,$a1,$70
	dc.b	$00,$05,$80
pl_Patt13:
	dc.b	$e2,$19,$11,$80,$11,$00,$00,$00,$a1,$1b,$00,$01,$a3,$19,$00,$16
	dc.b	$00,$05,$a3,$19,$00,$16,$00,$e6,$14,$11,$00,$00,$14,$00,$80,$11
	dc.b	$00,$00,$12,$00,$00,$00,$00,$a1,$0d,$00,$80
pl_Patt14:
	dc.b	$09,$20,$19,$40,$21,$a8,$17,$00,$16,$00,$17,$00,$16,$00,$17,$40
	dc.b	$21,$a2,$16,$00,$17,$40,$11,$a1,$19,$00,$03,$80
pl_Patt15:
	dc.b	$09,$20,$19,$40,$21,$a5,$17,$00,$16,$00,$17,$00,$00,$a1,$16,$00
	dc.b	$00,$a3,$12,$00,$16,$00,$00,$a1,$14,$00,$00,$a1,$0d,$00,$80
pl_Patt16:
	dc.b	$e2,$0d,$29,$80,$29,$00,$00,$0c,$e2,$0d,$29,$80,$29,$00,$00,$0c
	dc.b	$80
pl_Patt17:
	dc.b	$a3,$7e,$00,$7e,$00,$01,$a9,$7e,$00,$70,$00,$7e,$00,$7e,$00,$7e
	dc.b	$80,$21,$80,$a7,$70,$00,$7e,$00,$7e,$00,$70,$00,$01,$a1,$70,$00
	dc.b	$01,$80
pl_Patt18:
	dc.b	$09,$20,$19,$40,$11,$a5,$1b,$00,$19,$00,$1b,$00,$00,$a1,$1e,$00
	dc.b	$00,$a3,$1d,$00,$1b,$00,$00,$a1,$19,$00,$02,$80
pl_Patt19:
	dc.b	$b3,$0d,$00,$19,$00,$0d,$00,$14,$00,$16,$00,$14,$00,$12,$00,$14
	dc.b	$00,$0d,$00,$0d,$00,$01,$a1,$0d,$00,$01,$a1,$0d,$00,$01,$a1,$0d
	dc.b	$00,$80
pl_Patt1a:
	dc.b	$a4,$0d,$00,$0d,$00,$19,$40,$21,$a6,$0d,$00,$0d,$00,$0d,$00,$19
	dc.b	$40,$21,$a6,$0d,$00,$0d,$00,$0d,$00,$19,$40,$21,$a4,$0d,$00,$0d
	dc.b	$00,$19,$40,$21,$a3,$0d,$00,$19,$00,$80
; eof
