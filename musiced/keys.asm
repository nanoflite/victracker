;**************************************************************************
;*
;* FILE  keys.asm
;* Copyright (c) 1994, 2001, 2003 Daniel Kahlin <daniel@kahlin.net>
;* Written by Daniel Kahlin <daniel@kahlin.net>
;* $Id: keys.asm,v 1.19 2003/08/04 23:22:36 tlr Exp $
;*
;* DESCRIPTION
;*   Handle keys global to the editor.
;*
;******

	IFCONST HAVEDOCS
;**************************************************************************
;*
;* Docs
;*
;******
CheckDocKeys:
	cmp	#"H"
	beq	cdk_ShowDoc

	cmp	#0
	rts

cdk_ShowDoc:
	jsr	ViewDocs
	jsr	ShowScreen
	jsr	StartEdit
	lda	#0
	rts
	ENDIF ;HAVEDOCS

;**************************************************************************
;*
;* PlayerStuff
;*
;******
CheckPlayKeys:
	cmp	#"M"
	beq	cpk_InitMusic

	cmp	#"P"
	beq	cpk_ToggleMusic

	cmp	#"V"
	beq	cpk_ToggleColorFlag

	cmp	#171		; C= Q
	beq	cpk_Mute1
	cmp	#179		; C= W
	beq	cpk_Mute2
	cmp	#177		; C= E
	beq	cpk_Mute3
	cmp	#178		; C= R
	beq	cpk_Mute4

	jmp	CheckSongConfKeys

;Start music from the beginning, reset mutes.
cpk_InitMusic:
	lda	#0
	sta	pl_Mute
	sta	pl_Mute+1
	sta	pl_Mute+2
	sta	pl_Mute+3
	jsr	pl_Init
	jmp	cpk_ex1

;Toggle music on/off, do not change mutes.
cpk_ToggleMusic:
	lda	pl_PlayFlag
	eor	#$ff
	pha
	jsr	pl_Init
	pla
	sta	pl_PlayFlag
cpk_ex1:
	lda	#0
	rts

;Toggle ColorFlag on/off.
cpk_ToggleColorFlag:
	lda	Int_ColorFlag
	eor	#$ff
	sta	Int_ColorFlag
	jmp	cpk_ex1

;Toggle mute for voice 1
cpk_Mute1:
	ldy	#0
	dc.b	$2c		; bit $xxxx
;Toggle mute for voice 2
cpk_Mute2:
	ldy	#1
	dc.b	$2c		; bit $xxxx
;Toggle mute for voice 3
cpk_Mute3:
	ldy	#2
	dc.b	$2c		; bit $xxxx
;Toggle mute for voice 3
cpk_Mute4:
	ldy	#3
	lda	pl_Mute,y
	eor	#$ff
	sta	pl_Mute,y
	jmp	cpk_ex1

CheckSongConfKeys:
	cmp	#176		; C= A
	beq	cpk_SongUp
	cmp	#174		; C= S
	beq	cpk_SongDown
	cmp	#172		; C= D
	beq	cpk_NumUp
	cmp	#187		; C= F
	beq	cpk_NumDown

	cmp	#165		; C= G
	bne	cpk_skp7
	jmp	cpk_PlayModeUp
cpk_skp7:	
	cmp	#180		; C= H
	bne	cpk_skp8
	jmp	cpk_PlayModeDown
cpk_skp8:
	IFCONST	HAVESCALE
	cmp	#181		; C= J
	bne	cpk_skp9
	jmp	cpk_ScaleUp
cpk_skp9:
	cmp	#181		; C= J
	bne	cpk_skp10
	jmp	cpk_ScaleDown
cpk_skp10:
	ENDIF ;HAVESCALE
	cmp	#0
	rts

;Increase the current Song Number (cycle 0..pl_SongNum-1)
cpk_SongUp:
	inc	pl_ThisSong
	lda	pl_ThisSong
	cmp	pl_SongNum
	bne	cpk_ex1
	lda	#0
	sta	pl_ThisSong
	jmp	cpk_ex1
;Decrease the current Song Number (cycle 0..pl_SongNum-1)
cpk_SongDown:
	lda	pl_ThisSong
	beq	cpk_skp1
	dec	pl_ThisSong
	jmp	cpk_ex1
cpk_skp1:
	lda	pl_SongNum
	sta	pl_ThisSong
	dec	pl_ThisSong
	jmp	cpk_ex1

;Increase the Number of songs  (cycle 1..14)
cpk_NumUp:
	inc	pl_SongNum
	lda	pl_SongNum
	cmp	#14+1
	bne	cpk_ex3
	lda	#1
	sta	pl_SongNum
	jmp	cpk_ex3
;Decrease the Number of songs  (cycle 1..14)
cpk_NumDown:
	dec	pl_SongNum
	bne	cpk_ex3
	lda	#14
	sta	pl_SongNum
	jmp	cpk_ex3

;Increase the playmode  (cycle 0..NUMPLAYMODES-1)
cpk_PlayModeUp:
	inc	pl_PlayMode
	lda	pl_PlayMode
	cmp	#NUMPLAYMODES
	bne	cpk_ex2
	lda	#0
	sta	pl_PlayMode
	jmp	cpk_ex2

;Decrease the playmode  (cycle 0..NUMPLAYMODES-1)
cpk_PlayModeDown:
	dec	pl_PlayMode
	bpl	cpk_ex2
	lda	#NUMPLAYMODES-1
	sta	pl_PlayMode
	jmp	cpk_ex2

	IFCONST	HAVESCALE
;Increase the scale (cycle 0..NUMSCALES-1)
cpk_ScaleUp:
	inc	pl_Scale
	lda	pl_Scale
	cmp	#NUMSCALES
	bne	cpk_ex2
	lda	#0
	sta	pl_Scale
	ENDIF ;HAVESCALE
cpk_ex2:
	jsr	InterruptInit
cpk_ex3:
	jmp	cpk_ex1
	
;**************************************************************************
;*
;* DiskStuff
;*
;******
CheckDiskKeys:
	cmp	#204	;Shift L
	beq	cdk_LoadTune

	cmp	#211	;Shift S
	beq	cdk_SaveTune

	cmp	#196	;Shift D
	beq	cdk_Directory

	cmp	#201	;Shift I
	beq	cdk_InitTune
	cmp	#0
	rts

cdk_LoadTune:
	jsr	pl_UnInit
	jsr	InterruptUnInit
	jsr	LoadTune
	jmp	cdk_ex2

cdk_SaveTune:
	jsr	pl_UnInit
	jsr	InterruptUnInit
	jsr	SaveTune
	jmp	cdk_ex2

cdk_Directory:
	jsr	pl_UnInit
	jsr	InterruptUnInit
	jsr	ShowDir
	lda	#147
	jsr	$ffd2
	jmp	cdk_ex1

cdk_InitTune:
	jsr	pl_UnInit
	jsr	InterruptUnInit
	jsr	InitTune

cdk_ex1:
	jsr	ShowScreen
cdk_ex2:
	jsr	PrintPlayer
	jsr	StartEdit
	jsr	InterruptInit
	lda	#0
	rts


;**************************************************************************
;*
;* Function keys
;*
;******
CheckEditKeys:
	pha
	lda	pl_ThisSong	;X=pl_ThisSong*4
	asl
	asl
	tax
	pla
	
	cmp	#133	;F1
	beq	cek_SetStep
	cmp	#134	;F3
	beq	cek_SetStartStep
	cmp	#138	;F4
	beq	cek_SetRepeatStep
	cmp	#135	;F5
	beq	cek_SetEndStep
	cmp	#139	;F6
	beq	cek_ToggleRepeatMode
	cmp	#136	;F7
	beq	cek_IncSpeed
	cmp	#140	;F8
	beq	cek_DecSpeed
	cmp	#0
	rts

cek_SetStep:
	lda	pl_StartStep,x
	pha
	lda	LastPattListLine
	sta	pl_StartStep,x
	txa
	pha
	jsr	pl_Init
	pla
	tax
	pla	
	sta	pl_StartStep,x
	sta	pl_ThisStartStep
	jmp	cek_ex1

cek_SetStartStep:
	lda	LastPattListLine
	sta	pl_StartStep,x
	sta	pl_ThisStartStep
	jmp	cek_ex1

cek_SetRepeatStep:
	lda	LastPattListLine
	sta	pl_RepeatStep,x
	sta	pl_ThisRepeatStep
	jmp	cek_ex1

cek_SetEndStep:
	lda	LastPattListLine
	sta	pl_EndStep,x
	sta	pl_ThisEndStep
	jmp	cek_ex1

cek_ToggleRepeatMode:
	jsr	cek_SpeedPrepare
	lda	cek_SpeedTmp2
	clc
	adc	#$40
	cmp	#$80		; $c0 if halt is implied!
	bne	cek_skp2
	lda	#$00
cek_skp2:
	sta	cek_SpeedTmp2
	jmp	cek_ex2
cek_IncSpeed:
	jsr	cek_SpeedPrepare
	inc	cek_SpeedTmp1
	jmp	cek_ex2
cek_DecSpeed:
	jsr	cek_SpeedPrepare
	dec	cek_SpeedTmp1
cek_ex2:
	lda	cek_SpeedTmp1
	and	#$3f
	ora	cek_SpeedTmp2
	sta	pl_StartSpeed,x
	sta	pl_ThisStartSpeed
cek_ex1:
	lda	#0
	rts

cek_SpeedPrepare:
	lda	pl_StartSpeed,x
	pha
	and	#$3f
	sta	cek_SpeedTmp1
	pla
	and	#$c0
	sta	cek_SpeedTmp2
	rts
		
cek_SpeedTmp1:
	dc.b	0
cek_SpeedTmp2:
	dc.b	0
; eof
