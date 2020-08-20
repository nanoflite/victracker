; player for victracker 2.0
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

;*   Initialize tune:
.ifconst PL_SUPPORT_SONGS
;*     lda #Song
.endif ;PL_SUPPORT_SONGS
;*     jsr pl_Init 
;*
;*   Uninitialize tune:
;*     jsr pl_UnInit 
;*
;*   Every frame:
;*     jsr pl_Play
.ifconst	PL_SUPPORT_USERFLAG
;*
;*   Read UserFlag into Acc:
;*     jsr pl_ReadFlag
.endif ;PL_SUPPORT_USERFLAG
;*
;******
PL_SUPPORT_PORTFAST	=	1	;not yet implemented
PL_SUPPORT_PORTSLOW	=	1	;not yet implemented

; Player commands
.ifconst PL_SUPPORT_PORTEFFECT
.ifconst	PL_SUPPORT_PORTFAST
PL_PORTUP	=	$10
PL_PORTDOWN	=	$20
.endif ;PL_SUPPORT_PORTFAST
.endif ;PL_SUPPORT_PORTEFFECT
.ifconst PL_SUPPORT_ARPEFFECT
PL_ARPEGGIO	=	$30
.endif ;PL_SUPPORT_ARPEFFECT
.ifconst PL_SUPPORT_PORTEFFECT
.ifconst	PL_SUPPORT_PORTSLOW
PL_PORTUPSLOW	=	$50
PL_PORTDOWNSLOW	=	$60
.endif ;PL_SUPPORT_PORTSLOW
.endif ;PL_SUPPORT_PORTEFFECT
.ifconst	PL_SUPPORT_USERFLAG
PL_SETUSERFLAG	=	$70
.endif ;PL_SUPPORT_USERFLAG
PL_SETSOUND	=	$80
PL_CUTNOTE	=	$c0
.ifconst PL_SUPPORT_DELAY
PL_DELAYNOTE	=	$d0
.endif ;PL_SUPPORT_DELAY

.ifconst PL_SUPPORT_VOLVOICE
PL_NUMVOICES	=	5
.else ;PL_SUPPORT_VOLVOICE
PL_NUMVOICES	=	4
.endif ;PL_SUPPORT_VOLVOICE

;The sound format
PL_SND_DURATION		=	0
PL_SND_FOFFS		=	1
PL_SND_GLIDE		=	2
PL_SND_ARPEGGIO		=	3

.export pl_Play
.export pl_Init
.export pl_PlayFlag

;**************************************************************************
;*
;* zero page allocation
;*
;******

.zeropage

PatternZP:	.word 0
PatternTabZP:	.word 0
pl_Temp1ZP:	.byte 0
pl_Temp2ZP:	.byte 0
pl_Temp3ZP:	.byte 0

.code

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
.ifconst	PL_SUPPORT_USERFLAG
pl_ReadFlag:
	jmp	pl_RReadFlag
.endif ;PL_SUPPORT_USERFLAG

;**************************************************************************
;*
;* Data
;*
;******
pl_PlayFlag:
	.byte	0
pl_Speed:
	.byte	0
pl_Count:
	.byte	0
.ifconst	PL_SUPPORT_USERFLAG
pl_UserFlag:
	.byte	0
.endif ;PL_SUPPORT_USERFLAG

pl_FreqTab:
	.byte	0
	.byte	135,143,147,151,159,163,167,175,179,183,187,191
	.byte	195,199,201,203,207,209,212,215,217,219,221,223
	.byte	225,227,228,229,231,232,233,235,236,237,238,239
	.byte	240,241
pl_VoiceData:
; The voice data structure

.ifndef PL_SUPPORT_SONGS
.ifconst PL_SUPPORT_VOLVOICE
pl_vd_PatternTabLow:	.byte	<pl_Tab1_0,<pl_Tab2_0,<pl_Tab3_0,<pl_Tab4_0,<pl_Tab5_0 ;pointer to Pattlist
pl_vd_PatternTabHigh:	.byte	>pl_Tab1_0,>pl_Tab2_0,>pl_Tab3_0,>pl_Tab4_0,>pl_Tab5_0 ;
.else ;PL_SUPPORT_VOLVOICE
pl_vd_PatternTabLow:	.byte	<pl_Tab1_0,<pl_Tab2_0,<pl_Tab3_0,<pl_Tab4_0 ;pointer to Pattlist
pl_vd_PatternTabHigh:	.byte	>pl_Tab1_0,>pl_Tab2_0,>pl_Tab3_0,>pl_Tab4_0 ;
.endif ;PL_SUPPORT_VOLVOICE
.else ;!PL_SUPPORT_SONGS
pl_vd_PatternTabLow:	.res	PL_NUMVOICES	;pointer to Pattlist
pl_vd_PatternTabHigh:	.res	PL_NUMVOICES	;
.endif ;PL_SUPPORT_SONGS

pl_vd_ZeroBegin:	;!!Everything after this gets cleared!!
pl_vd_Note:		.res	PL_NUMVOICES	;Current Pitch
pl_vd_Param:		.res	PL_NUMVOICES	;Current Param
pl_vd_NextNote:		.res	PL_NUMVOICES	;Next Pitch
pl_vd_NextParam:	.res	PL_NUMVOICES	;Next Param
.ifconst PL_SUPPORT_DELAY
pl_vd_DelayCount:	.res	PL_NUMVOICES	;Delay Count
.endif ;PL_SUPPORT_DELAY
pl_vd_DurationCount:	.res	PL_NUMVOICES	;Duration Count
pl_vd_ThisNote:		.res	PL_NUMVOICES	;This Note   (These get updated when
pl_vd_ThisParam:	.res	PL_NUMVOICES	;This Param   pl_Retrig is called)
pl_vd_EffectiveNote:	.res	PL_NUMVOICES	;Effective Note
.ifconst	PL_SUPPORT_PORTAMENTO
pl_vd_FreqOffsetLow:	.res	PL_NUMVOICES	;Current freqoffset
pl_vd_FreqOffsetHigh:	.res	PL_NUMVOICES	;Current freqoffset
.endif ;PL_SUPPORT_PORTAMENTO
.ifconst	PL_SUPPORT_ARPEGGIOS
pl_vd_ArpMode:		.res	PL_NUMVOICES	;Arpeggio Mode
pl_vd_ArpStep:		.res	PL_NUMVOICES	;Arpeggio step
pl_vd_ArpOffset:	.res	PL_NUMVOICES	;Arpeggio note offset
pl_vd_ArpCount:		.res	PL_NUMVOICES	;Arpeggio count
.endif ;PL_SUPPORT_ARPEGGIOS
pl_vd_Sound:		.res	PL_NUMVOICES	;Current Sound
pl_vd_PattlistStep:	.res	PL_NUMVOICES	;Step in pattlist
pl_vd_PattlistWait:	.res	PL_NUMVOICES	;Time before reading the next pattlist
                                        ;entry
pl_vd_CurrentPattern:	.res	PL_NUMVOICES
pl_vd_PatternStep:	.res	PL_NUMVOICES	;Step in pattern
pl_vd_PatternWait:	.res	PL_NUMVOICES	;Time before reading the next note.
pl_vd_ZeroEnd:		;!!Everything before this gets cleared!!
pl_vd_FetchMode:	.res	PL_NUMVOICES	;Fetch mode.

;**************************************************************************
;*
;* InitRoutine
;*
;******
pl_IInit:
	jsr	pl_UUnInit

.ifconst PL_SUPPORT_SONGS
	tax			;X=Song
.ifconst PL_SUPPORT_VOLVOICE
	sta	pl_Temp1ZP
	asl
	asl
	clc
	adc	pl_Temp1ZP
	tay			;Y=Song*5
.else ;PL_SUPPORT_VOLVOICE
	asl
	asl
	tay			;Y=Song*4
.endif ;PL_SUPPORT_VOLVOICE
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
.else ;PL_SUPPORT_SONGS
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
.endif ;PL_SUPPORT_SONGS
			
	lda	#0
.ifconst	PL_SUPPORT_USERFLAG
	sta	pl_UserFlag
.endif ;PL_SUPPORT_USERFLAG
	ldx	#pl_vd_ZeroEnd-pl_vd_ZeroBegin-1
pli_lp2:
	sta	pl_vd_ZeroBegin,x
	dex
	bpl	pli_lp2
.ifconst	PL_SUPPORT_EXACTPRELOAD
	ldx	#PL_NUMVOICES-1
pli_lp3:
	jsr	pl_GetVoice
.ifndef PL_NO_OPTIMIZE
	jsr	pl_GetVoice	;Necessary for optimized players.
.endif ;PL_NO_OPTIMIZE
	dex
	bpl	pli_lp3
.endif ;PL_SUPPORT_EXACTPRELOAD

; Ok, now x=$ff
	stx	pl_PlayFlag	;Start Song! (pl_PlayFlag=$ff)

.ifndef PL_SUPPORT_VOLVOICE
	lda	#$0f		;Set initial volume
	jsr	plpv_SetVolume
.endif ;PL_SUPPORT_VOLVOICE
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

.ifconst	PL_OPTIMIZE_FIVE
	ldx	pl_Count
	cpx	#PL_NUMVOICES	;is X less that PL_NUMVOICES? 
	bcs	pl_skp3		;no, skip out.
	jsr	pl_GetVoice	;fetch data for voice X.
.endif ;PL_OPTIMIZE_FIVE
.ifconst	PL_OPTIMIZE_THREE
	lda	pl_Count
	beq	pl_o3step0
	cmp	#1
	beq	pl_o3step1
	cmp	#2
	beq	pl_o3step2
.endif ;PL_OPTIMIZE_THREE
.ifconst	PL_OPTIMIZE_TWO
	lda	pl_Count
	beq	pl_o2step0
	cmp	#1
	beq	pl_o2step1
.endif ;PL_OPTIMIZE_TWO
.ifconst	PL_OPTIMIZE_ONE
	lda	pl_Count
	beq	pl_o1step0
.endif ;PL_OPTIMIZE_ONE
	jmp	pl_skp3
plpp_ex1:
	rts
.ifconst	PL_OPTIMIZE_THREE
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
.ifconst PL_SUPPORT_VOLVOICE
	ldx	#4
	jsr	pl_GetVoice
	dex
.else ;PL_SUPPORT_VOLVOICE
	ldx	#3
.endif ;PL_SUPPORT_VOLVOICE
	jsr	pl_GetVoice
	jmp	pl_skp3
.endif ;PL_OPTIMIZE_THREE
.ifconst	PL_OPTIMIZE_TWO
pl_o2step0:
	ldx	#1
	jsr	pl_GetVoice
	dex
	jsr	pl_GetVoice
	jmp	pl_skp3
pl_o2step1:
.ifconst	PL_SUPPORT_VOLVOICE
	ldx	#4
	jsr	pl_GetVoice
	dex
.else ;PL_SUPPORT_VOLVOICE
	ldx	#3
.endif ;PL_SUPPORT_VOLVOICE
	jsr	pl_GetVoice
	dex
	jsr	pl_GetVoice
	jmp	pl_skp3
.endif ;PL_OPTIMIZE_TWO
.ifconst	PL_OPTIMIZE_ONE
pl_o1step0:
	ldx	#PL_NUMVOICES-1
plo1_lp1:
	jsr	pl_GetVoice
	dex
	bpl	plo1_lp1
	jmp	pl_skp3
.endif ;PL_OPTIMIZE_ONE
	
pl_skp1:

;*** Get Data from tune ***
	ldx	#PL_NUMVOICES-1
pl_lp1:
.ifconst PL_NO_OPTIMIZE
	jsr	pl_GetVoice
.endif ;PL_NO_OPTIMIZE
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

.ifconst	PL_SUPPORT_USERFLAG
;**************************************************************************
;*
;* Read flag
;*
;******
pl_RReadFlag:
	lda	pl_UserFlag
	rts
.endif ;PL_SUPPORT_USERFLAG

		
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
.ifconst PL_SUPPORT_VOLVOICE
	cpx	#$04
	beq	plpce_VolumeTempo

.endif ;PL_SUPPORT_VOLVOICE
	lda	pl_vd_Param,x
	and	#$f0
.ifconst	PL_SUPPORT_SOUNDS
	cmp	#PL_SETSOUND
	beq	plpce_SetSound
.endif ;PL_SUPPORT_SOUNDS
	rts

.ifconst	PL_SUPPORT_SOUNDS
plpce_SetSound:
	lda	pl_vd_Param,x
	and	#$0f
	asl
	asl
	sta	pl_vd_Sound,x
	rts
.endif ;PL_SUPPORT_SOUNDS
		
.ifconst PL_SUPPORT_VOLVOICE
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
.endif ;PL_SUPPORT_VOLVOICE

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
.ifconst PL_SUPPORT_DELAY
	sta	pl_vd_DelayCount,x
.endif ;PL_SUPPORT_DELAY
.ifconst	PL_SUPPORT_ARPEGGIOS
	sta	pl_vd_ArpMode,x
	sta	pl_vd_ArpStep,x
	sta	pl_vd_ArpOffset,x
	sta	pl_vd_ArpCount,x
.endif ;PL_SUPPORT_ARPEGGIOS
.ifconst	PL_SUPPORT_PORTAMENTO
	sta	pl_vd_FreqOffsetHigh,x
	lda	#$80
	sta	pl_vd_FreqOffsetLow,x     ;The initial value is $0080

	ldy	pl_vd_Sound,x	;Frequency offset from the sound
	lda	pl_Sounds+PL_SND_FOFFS,y
	beq	plrt_skp4	;Do not adjust from $0080 if we are
			        ;already there as this is kind of slow.
	jsr	pl_DoPortamentoSigned	;do portamento _once_.
plrt_skp4:

.endif ;PL_SUPPORT_PORTAMENTO
.ifconst	PL_SUPPORT_ARPEGGIOS
.ifconst PL_SUPPORT_ARPEFFECT
;Does this Command indicate arpeggio?
	lda	pl_vd_Param,x
	pha
	and	#$f0
	tay
	pla
	cpy	#PL_ARPEGGIO
	beq	plrt_Arpeggio	;Yes, run it!

.endif ;PL_SUPPORT_ARPEFFECT
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
.endif ;PL_SUPPORT_ARPEGGIOS

plrt_skp3:

.ifconst PL_SUPPORT_VOLVOICE
	cpx	#$04		;Volume/tempo channel always play legato
	beq	plrt_skp1

.endif ;PL_SUPPORT_VOLVOICE
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
.ifconst	PL_SUPPORT_USERFLAG
	cmp	#PL_SETUSERFLAG
	beq	plce_UserFlag
.endif ;PL_SUPPORT_USERFLAG
.ifconst PL_SUPPORT_DELAY
	cmp	#PL_DELAYNOTE
	beq	plce_DelayNote
.endif ;PL_SUPPORT_DELAY

	cmp	#PL_CUTNOTE
	beq	plce_CutNote
plce_ex1:
	rts

.ifconst	PL_SUPPORT_USERFLAG
plce_UserFlag:
	lda	pl_vd_Param,x
	and	#$0f
	sta	pl_UserFlag
	rts
.endif ;PL_SUPPORT_USERFLAG
plce_CutNote:
	lda	pl_vd_Param,x
	and	#$0f
	sta	pl_vd_DurationCount,x
	rts
.ifconst PL_SUPPORT_DELAY
plce_DelayNote:
	lda	pl_vd_Param,x
	and	#$0f
	sta	pl_vd_DelayCount,x
	rts
.endif ;PL_SUPPORT_DELAY

;**************************************************************************
;*
;* PreUpdateVoice
;* X=Voice
;*
;******
pl_PreUpdateVoice:
.ifconst PL_SUPPORT_DELAY
; Handle the Delay Count
	lda	pl_vd_DelayCount,x
	bne	pl_puv_ex2	;Not zero... decrease and keep it silent.

.endif ;PL_SUPPORT_DELAY
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
.ifconst PL_SUPPORT_DELAY
pl_puv_ex2:	
	sec
	sbc	#1
	sta	pl_vd_DelayCount,x
.endif ;PL_SUPPORT_DELAY
pl_puv_ex1:
; silence it.
	lda	#0
	sta	pl_vd_EffectiveNote,x

.ifconst PL_SUPPORT_PORTAMENTO
	sta	pl_vd_FreqOffsetLow,x
	sta	pl_vd_FreqOffsetHigh,x
.endif ;PL_SUPPORT_PORTAMENTO
.ifconst PL_SUPPORT_ARPEGGIOS
	sta	pl_vd_ArpStep,x
	sta	pl_vd_ArpOffset,x
	sta	pl_vd_ArpCount,x
.endif ;PL_SUPPORT_ARPEGGIOS
	rts

;**************************************************************************
;*
;* PlayVoice
;* X=Voice
;*
;******
pl_PlayVoice:
.ifconst PL_SUPPORT_VOLVOICE
	cpx	#$04			;Is VOL/Speed channel?
	beq	plpv_VolumeTempo

.endif ;PL_SUPPORT_VOLVOICE
.ifndef PL_SUPPORT_ARPEGGIOS
	lda	pl_vd_EffectiveNote,x
	and	#$7f
	beq	plpv_SetValue
	cpx	#$03			;Is this the noise channel?
	beq	plpv_Noise
	tay
	lda	pl_FreqTab,y	;Freq
	beq	plpv_SetValue
plpv_Noise:
.ifconst PL_SUPPORT_PORTAMENTO
	clc
	adc	pl_vd_FreqOffsetHigh,x  ;Add frequency offset
.endif ;PL_SUPPORT_PORTAMENTO
	ora	#$80		;SetGate
	jmp	plpv_SetValue
.else ;PL_SUPPORT_ARPEGGIOS
.ifconst	PL_SUPPORT_ARPMODEF0
	lda	pl_vd_ArpMode,x
	cmp	#$f0
	bne	plpv_skp8
	jmp	plpv_ArpModef0
plpv_skp8:
.endif ;PL_SUPPORT_ARPMODEF0

; Arpeggio modes 0 and 1
;Get note in, and put it in pl_Temp2ZP
	lda	pl_vd_EffectiveNote,x
	and	#$7f
	beq	plpv_SetValue
	sta	pl_Temp2ZP

.ifconst PL_SUPPORT_PORTAMENTO
;put FreqOffset in pl_Temp1ZP.
	lda	pl_vd_FreqOffsetHigh,x
	sta	pl_Temp1ZP
.endif ;PL_SUPPORT_PORTAMENTO
;Preserve ArpOffset into pl_Temp3ZP
	lda	pl_vd_ArpOffset,x
	sta	pl_Temp3ZP
	beq	plpv_skp4	; If no offset, play as fast as possible
	
.ifconst PL_SUPPORT_PORTAMENTO
;Clear out FreqOffset in pl_Temp1ZP if ArpOffset bit 7 is set.
	bit	pl_Temp3ZP
	bpl	plpv_skp1
	lda	#0
	sta	pl_Temp1ZP
plpv_skp1:
.endif ;PL_SUPPORT_PORTAMENTO

.ifconst PL_SUPPORT_ARPMODE10
	lda	pl_vd_ArpMode,x
	cmp	#$10
	beq	plpv_ArpMode10	

.endif ;PL_SUPPORT_ARPMODE10
.ifconst PL_SUPPORT_ARPMODE00
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
.ifconst PL_SUPPORT_PORTAMENTO
	clc
	adc	pl_Temp1ZP	;Add frequency offset
.endif ;PL_SUPPORT_PORTAMENTO
	ora	#$80		;SetGate
	jmp	plpv_SetValue

.endif ;PL_SUPPORT_ARPMODE00
.ifconst PL_SUPPORT_ARPMODE10
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
.ifconst PL_SUPPORT_PORTAMENTO
	clc
	adc	pl_Temp1ZP	;Add frequency offset
.endif ;PL_SUPPORT_PORTAMENTO
	ora	#$80		;SetGate
	jmp	plpv_SetValue

.endif ;PL_SUPPORT_ARPMODE10
.endif ;PL_SUPPORT_ARPEGGIOS
.ifconst PL_SUPPORT_VOLVOICE
plpv_VolumeTempo:
;*** Handle Volume ***
	lda	pl_vd_EffectiveNote,x
.endif ;PL_SUPPORT_VOLVOICE
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
	
.ifconst PL_SUPPORT_ARPEGGIOS
.ifconst	PL_SUPPORT_ARPMODEF0
plpv_ArpModef0:
.ifconst PL_SUPPORT_PORTAMENTO
;put FreqOffset in pl_Temp1ZP
	lda	pl_vd_FreqOffsetHigh,x
	sta	pl_Temp1ZP
	
.endif ;PL_SUPPORT_PORTAMENTO
;Get note in ACC and jump
	lda	pl_vd_EffectiveNote,x
	and	#$7f
	cpx	#$03			;Is this the noise channel?
	beq	plpvf0_Noise

;*** Play Note ***
.ifconst PL_SUPPORT_ARPEGGIOS
	clc
	adc	pl_vd_ArpOffset,x	;Add Arpeggio
.endif ;PL_SUPPORT_ARPEGGIOS
	tay			;y = EffectiveNote
	lda	pl_FreqTab,y	;Freq
	beq	plpv_SetValue
.ifconst PL_SUPPORT_PORTAMENTO
	clc
	adc	pl_Temp1ZP
.endif ;PL_SUPPORT_PORTAMENTO
	ora	#$80		;SetGate
	jmp	plpv_SetValue
plpvf0_Noise:
;*** Play Noise ***
	cmp	#$00
	beq	pplvf0n_skp1
.ifconst PL_SUPPORT_ARPEGGIOS
	clc
	adc	pl_vd_ArpOffset,x	;Add arpeggio
.endif ;PL_SUPPORT_ARPEGGIOS
.ifconst PL_SUPPORT_PORTAMENTO
	clc
	adc	pl_Temp1ZP
.endif ;PL_SUPPORT_PORTAMENTO
	ora	#$80		;SetGate
pplvf0n_skp1:
	jmp	plpv_SetValue
.endif ;PL_SUPPORT_ARPMODEF0
.endif ;PL_SUPPORT_ARPEGGIOS
	

;**************************************************************************
;*
;* PostUpdateVoice
;* X=Voice
;*
;******
pl_PostUpdateVoice:
.ifconst PL_SUPPORT_PORTAMENTO
	jsr	pl_puv_UpdatePort
.endif ;PL_SUPPORT_PORTAMENTO
.ifconst PL_SUPPORT_ARPEGGIOS
	jsr	pl_puv_UpdateArp
.endif ;PL_SUPPORT_ARPEGGIOS
	rts

.ifconst PL_SUPPORT_PORTAMENTO
pl_puv_UpdatePort:
;*** Handle Portamento Effects ***
.ifconst PL_SUPPORT_PORTEFFECT
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

.endif ;PL_SUPPORT_PORTEFFECT
.ifconst PL_SUPPORT_PORTSOUND
	ldy	pl_vd_Sound,x	; Portamento enabled from the sound?
	lda	pl_Sounds+PL_SND_GLIDE,y
	beq	plpuv_skp2	;No, skip it!
	jmp	pl_DoPortamentoSigned	;Yes, do portamento.
plpuv_skp2:
.endif ;PL_SUPPORT_PORTSOUND
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

.endif ;PL_SUPPORT_PORTAMENTO
.ifconst PL_SUPPORT_ARPEGGIOS
pl_puv_UpdateArp:
;*** Handle Arpeggio Effects ***
.ifconst	PL_SUPPORT_ARPEFFECT
	lda	pl_vd_ThisParam,x
	tay
	and	#$0f
	sta	pl_Temp1ZP
	tya
	and	#$f0

	cmp	#PL_ARPEGGIO
	beq	pl_Arpeggio

.endif ;PL_SUPPORT_ARPEFFECT
.ifconst PL_SUPPORT_ARPSOUND
	ldy	pl_vd_Sound,x	;Arpeggio enabled from the sound?
	lda	pl_Sounds+PL_SND_ARPEGGIO,y
	bpl	plpuv_skp1	;No, skip it!
	and	#$0f
	sta	pl_Temp1ZP
	jmp	pl_Arpeggio	;Yes, do arpeggio.
plpuv_skp1:
.endif ;PL_SUPPORT_ARPSOUND
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
.endif ;PL_SUPPORT_ARPEGGIOS

.ifndef PL_VTCOMP
; eof
.endif ;PL_VTCOMP
