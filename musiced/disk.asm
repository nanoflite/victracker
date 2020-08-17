;**************************************************************************
;*
;* FILE  disk.asm
;* Copyright (c) 1994, 2003 Daniel Kahlin <daniel@kahlin.net>
;* Written by Daniel Kahlin <daniel@kahlin.net>
;* $Id: disk.asm,v 1.23 2003/08/04 22:34:20 tlr Exp $
;*
;* DESCRIPTION
;*   Disk functions
;*
;******

TmpZP		EQU	$fb
Tmp2ZP		EQU	$fd

;**************************************************************************
;*
;* InitTune        - clear the tune
;* InitTune_force  - clear the tune (without asking)
;*
;******
InitTune:
	jsr	AreYouSure
	beq	it_ex1

InitTune_force:
	ldx	#<TuneStart
	ldy	#>TuneStart
	stx	TmpZP
	sty	TmpZP+1

	ldy	#0
it_lp1:
	tya
	sta	(TmpZP),y
	inc	TmpZP
	bne	it_skp1
	inc	TmpZP+1
it_skp1:
	lda	TmpZP
	cmp	#<TuneEnd
	bne	it_lp1
	lda	TmpZP+1
	cmp	#>TuneEnd
	bne	it_lp1

; make pattern 01 a volume pattern with volume 0f
	ldx	#0
	lda	#$0f
it_lp2:
	sta	pl_PatternData+[$40*1],x
	inx
	inx
	cpx	#$40
	bne	it_lp2

; put pattern 01 in the volume track
	ldx	#0
	lda	#$01
it_lp3:
	sta	pl_Tab5,x
	inx
	bne	it_lp3

; set up default lengths
	jsr	SetDefaultLengths

; set up default arpeggios
	jsr	SetDefaultArpeggios

; set up version number
	jsr 	SetVersion

; set up PlayMode.
	ldx	#5		;NTSC..
	lda	PAL_Flag
	beq	it_skp2
	ldx	#1		;PAL...
it_skp2:
	stx	pl_PlayMode

; set up initial speed + start/stop step.
	lda	#1
	sta	pl_SongNum
	ldx	#0
it_lp6:
	lda	#0
	sta	pl_StartStep,x
	sta	pl_EndStep,x
	sta	pl_RepeatStep,x
	lda	#7
	sta	pl_StartSpeed,x
	inx
	inx
	inx
	inx
	cpx	#14*4
	bne	it_lp6
it_ex1:
	rts

SetVersion:
	lda	#"T"
	sta	pl_ID
	lda	#"1"
	sta	pl_ID+1
	lda	#VERSION_MAJOR
	sta	pl_Version
	lda	#VERSION_MINOR
	sta	pl_Revision
	rts

SetDefaultLengths:
; set up default lengths
	lda	#$20-1
SetLengths:
; set up lengths
	ldx	#0
dl_lp1:
	sta	pl_LengthTab,x
	inx
	bne	dl_lp1
	rts
	
SetDefaultArpeggios:
; set up default arpeggios
	ldx	#$00		; mode 0, speed 0
	ldy	#$07		; repeat 0, last step 7
SetArpeggios:
; set up arpeggios
	stx	TmpZP
	sty	Tmp2ZP
	ldx	#0
da_lp1:
	lda	TmpZP		; mode, speed
	sta	pl_ArpeggioConf,x
	inx
	lda	Tmp2ZP		; repeatstep, endstep
	sta	pl_ArpeggioConf,x
	inx
	cpx	#32
	bne	da_lp1
	rts
	
;**************************************************************************
;*
;* LoadTune
;*
;******
LoadTune:
	lda	#<LoadName_MSG
	ldy	#>LoadName_MSG
	jsr	PrintStatus
	jsr	GetFileName
	beq	lt_ex2
	
; We have a filename, try to load... 
	lda	#1
	ldx	#8
	ldy	#0
	jsr	$ffba

	lda	#$00
	sta	$90

	lda	#0
	ldx	#<TuneStart
	ldy	#>TuneStart
	jsr	$ffd5
; first determine if loading succeded
	lda	$90
	and	#%10000011
	bne	lt_fl1

; X, Y contains last byte loaded +1
; now pad with zeroes up to TuneEnd
	stx	TmpZP
	sty	TmpZP+1
lt_lp1:
	lda	TmpZP
	cmp	#<TuneEnd
	bne	lt_skp1
	lda	TmpZP+1
	cmp	#>TuneEnd
	beq	lt_ex1
lt_skp1:
	ldy	#0
	tya
	sta	(TmpZP),y
	inc	TmpZP
	bne	lt_lp1
	inc	TmpZP+1
	jmp	lt_lp1
					
lt_ex1:
	lda	pl_ID
	cmp	#"T"
	bne	lt_fl2
	lda	pl_ID+1
	cmp	#"1"
	beq	lt_skp2		; 'T1' is the current version, skip conversion
	cmp	#"0"
	bne	lt_fl2		; Nor 'T1', nor 'T0'... thus unknown!

;We now have a 'T0' module in memory
;we must convert it to the 'T1' version format
	jsr	ConvertTune

lt_skp2:


;Print a status message on what we loaded
	lda	#<LoadOk1_MSG
	ldy	#>LoadOk1_MSG
	jsr	PrintStatus
	lda	#0
	ldx	pl_Version
	jsr	$ddcd
	lda	#"."
	jsr	$ffd2
	lda	#0
	ldx	pl_Revision
	jsr	$ddcd
	lda	#<LoadOk2_MSG
	ldy	#>LoadOk2_MSG
	jsr	$cb1e

; Set the version number to the current version.
; (we do it here so that Version and Revision is the old value when
;  printing the status message.)
	jsr	SetVersion

	rts
lt_ex2:
	jsr	BlankStatus
	rts
; ERROR: general failure
lt_fl1:
	lda	#<LoadFail_MSG
	ldy	#>LoadFail_MSG
	jsr	PrintStatus
	rts
; ERROR: unknown file type
lt_fl2:
	jsr	InitTune_force	; reinitialize the storage
	lda	#<LoadFail2_MSG
	ldy	#>LoadFail2_MSG
	jsr	PrintStatus
	rts

LoadFail_MSG:
	dc.b	"LOADING FAILED!",0
LoadFail2_MSG:
	dc.b	"UNKNOWN FILETYPE!",0
LoadOk1_MSG:
	dc.b	"LOADED VT-",0
LoadOk2_MSG:
	dc.b	" SONG.",0

;**************************************************************************
;*
;* SaveTune
;*
;******
SaveTune:
; Make sure you see which version created it.
	jsr	SetVersion

; save the data
	lda	#<SaveName_MSG
	ldy	#>SaveName_MSG
	jsr	PrintStatus
	jsr	GetFileName
	beq	st_ex2

	lda	#1
	ldx	#8
	ldy	#1
	jsr	$ffba

	lda	#$00
	sta	$90

	jsr	FindTuneEnd

	lda	#<TuneStart
	sta	TmpZP
	lda	#>TuneStart
	sta	TmpZP+1

	lda	#TmpZP
	ldx	Tmp2ZP
	ldy	Tmp2ZP+1
	jsr	$ffd8	;Save
; first determine if saveing succeded
	lda	$90
	and	#%10000011
	bne	st_fl1

st_ex1:
	lda	#<SaveOk_MSG
	ldy	#>SaveOk_MSG
	jsr	PrintStatus
	rts
st_ex2:
	jsr	BlankStatus
	rts
st_fl1:
	lda	#<SaveFail_MSG
	ldy	#>SaveFail_MSG
	jsr	PrintStatus
	rts

SaveFail_MSG:
	dc.b	"SAVING FAILED!",0
SaveOk_MSG:
	dc.b	"SAVED SONG.",0

;**************************************************************************
;*
;* Display Directory...
;*
;***
ShowDir:
	lda	#144
	jsr	$ffd2
	lda	#147
	jsr	$ffd2
	lda	#DnamLen
	ldx	#<Dnam
	ldy	#>Dnam
	jsr	$ffbd	;SETNAM
	lda	#$01
	ldx	$ba
	ldy	#$60
	jsr	$ffba	;SETLFS
	jsr	$ffc0	;iec-OPEN
	lda	$ba
	jsr	$ffb4	;TALK
	lda	$b9
	jsr	$ff96	;TKSA

	ldy	#$03
sd_lp1:	
	sty	$b7
sd_lp2:
	jsr	$ffa5	;ACPTR
	sta	$c3
	jsr	$ffa5	;ACPTR
	ldy	$90
	bne	sd_ex1
	dec	$b7
	bne	sd_lp2
	ldx	$c3
	jsr	$ddcd	;Output decimal number
	lda	#" "
	jsr	$ffd2	;pchar
sd_lp3:
	jsr	$ffa5	;ACPTR
	ldx	$90
	bne	sd_ex1
	cmp	#0
	beq	sd_skp1
	jsr	$ffd2	;pchar
	jmp	sd_lp3
sd_skp1:
	lda	#13
	jsr	$ffd2	;pchar
	ldy	#$02
sd_lp4:
	jsr	$ffe1	;STOP
	bne	sd_lp1
	jmp	sd_ex2

sd_ex1:
	jsr	sd_Close

	lda	#0
	sta	198
sd_lp5:
	jsr	$ffe4
	beq	sd_lp5
	rts

sd_ex2:
	jsr	sd_Close
	rts


sd_Close:
	jsr	$ffab	;UNTLK
	lda	#$01
	jsr	$ffc3	;iec-close
	jsr	$ffe7
	rts
;***
Dnam:
	dc.b	"$0"
DnamLen	EQU	.-Dnam



;**************************************************************************
;*
;* GetFileName
;* OUT:	 Acc=Length (Z-flag set if 0)
;*
;******
GetFileName:
	lda	#16
	ldx	#<FileName
	ldy	#>FileName
	jsr	GetString
	jsr	$ffbd		;Set Filename
	cmp	#0
	rts

FileName:
	ds.b	17


LoadName_MSG:
	dc.b	"LOAD: ",0
SaveName_MSG:
	dc.b	"SAVE: ",0


;**************************************************************************
;*
;* FindFirstUnused
;* returns pattern in Acc if carry clear.
;* carry set means that no pattern can be found
;*
;******
FindFirstUnused:
;Clear table
	ldx	#0
	txa	
ffu_lp2:
	sta	ffu_tab,x
	inx
	cpx	#MAXNUMPATTERNS
	bne	ffu_lp2
	
;Count number of uses of each pattern 
	lda	#<pl_PattLists
	sta	Tmp2ZP
	lda	#>pl_PattLists
	sta	Tmp2ZP+1
	ldx	#5
	ldy	#0
ffu_lp4:	
	txa
	pha
ffu_lp1:
	lda	(Tmp2ZP),y
	and	#MAXNUMPATTERNS_MASK
	tax
	lda	#1
	sta	ffu_tab,x
	iny
	bne	ffu_lp1
	inc	Tmp2ZP+1
	pla
	tax
	dex
	bne	ffu_lp4

;Find first that is unused
	ldx	#0
ffu_lp3:
	lda	ffu_tab,x
	beq	ffu_ex1
	inx
	cpx	#MAXNUMPATTERNS
	bne	ffu_lp3

	sec
	rts

ffu_ex1:
	txa
	clc
	rts
	
ffu_tab:
	ds.b	MAXNUMPATTERNS


;**************************************************************************
;*
;* FindTuneEnd
;*
;******
FindTuneEnd:
	lda	#0
	sta	MaxPatt
	lda	#<pl_PattLists
	sta	Tmp2ZP
	lda	#>pl_PattLists
	sta	Tmp2ZP+1
	ldx	#5
	ldy	#0
fte_lp1:
	lda	(Tmp2ZP),y
	and	#MAXNUMPATTERNS_MASK
	cmp	MaxPatt
	bcc	fte_skp1
	sta	MaxPatt
fte_skp1:
	iny
	bne	fte_lp1
	inc	Tmp2ZP+1
	dex
	bne	fte_lp1

	lda	#0		;Tmp2ZP=pl_PatternData+(MaxPatt+1)*$100/4
	sta	Tmp2ZP
	inc	MaxPatt
	lda	MaxPatt
	lsr
	ror	Tmp2ZP
	lsr
	ror	Tmp2ZP
	pha
	lda	Tmp2ZP
	clc
	adc	#<pl_PatternData
	sta	Tmp2ZP
	pla
	adc	#>pl_PatternData
	sta	Tmp2ZP+1
	rts

MaxPatt:
	dc.b	0

;**************************************************************************
;*
;* ConvertTune
;*
;******
ConvertTune:

; Move old pl_StartSpeed and set pl_RepeatStep to pl_StartStep
	lda	pl_RepeatStep
	sta	pl_StartSpeed
	lda	pl_StartStep
	sta	pl_RepeatStep
	
; First insert a blank space where the extra data of the T1 format is located
	lda	#<TuneEnd
	sta	TmpZP
	lda	#>TuneEnd
	sta	TmpZP+1
	lda	#<[TuneEnd-[pl_ExtraT1End-pl_ExtraT1Start]]
	sta	Tmp2ZP
	lda	#>[TuneEnd-[pl_ExtraT1End-pl_ExtraT1Start]]
	sta	Tmp2ZP+1

	ldy	#0
ct_lp4:	
	lda	TmpZP
	bne	ct_skp1
	dec	TmpZP+1
ct_skp1:
	dec	TmpZP
	lda	Tmp2ZP
	bne	ct_skp2
	dec	Tmp2ZP+1
ct_skp2:
	dec	Tmp2ZP
	lda	(Tmp2ZP),y
	sta	(TmpZP),y
	lda	TmpZP
	cmp	#<pl_ExtraT1End
	bne	ct_lp4
	lda	TmpZP+1
	cmp	#>pl_ExtraT1End
	bne	ct_lp4

; Secondly... fill up the space
	ldx	#0
	txa
ct_lp5:
	sta	pl_ArpeggioConf,x
	sta	pl_Sounds,x
	inx
	bne	ct_lp5

; Set up the default length tab
	jsr	SetDefaultLengths

; Space filled,... convert Arpeggios
	ldx	#8*16-1 	;the end of the old format arpeggios
	ldy	#16*16-1	;the end of the new format arpeggios 
ct_lp3:
	lda	#8
	sta	TmpZP
ct_lp1:
	lda	#0
	sta	pl_Arpeggios,y
	dey
	dec	TmpZP
	bne	ct_lp1
	lda	#8
	sta	TmpZP
ct_lp2:	
	lda	pl_Arpeggios,x
	sta	pl_Arpeggios,y
	dey
	dex
	dec	TmpZP
	bne	ct_lp2
	cpy	#0-1
	bne	ct_lp3

; Set up lengths and speeds to correspond to legacy vic-tracker speeds
	ldx	#$f0		; mode f, speed 0
	ldy	#$07		; repeat 0, last step 7
	jsr	SetArpeggios

; Ok, arpeggios converted... Set up sounds (freqoffs $fc)
	ldx	#0
ct_lp6:
	lda	#$fc
	sta	pl_Sounds+PL_SND_FOFFS,x
	txa
	clc
	adc	#8
	tax
	cpx	#$80
	bne	ct_lp6

; Ok, sounds updated... Done!!!
	rts

; eof
