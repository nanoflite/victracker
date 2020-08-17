;**************************************************************************
;*
;* FILE  editpattern.asm
;* Copyright (c) 1994, 2003 Daniel Kahlin <daniel@kahlin.net>
;* Written by Daniel Kahlin <daniel@kahlin.net>
;* $Id: editpattern.asm,v 1.17 2003/08/07 13:47:07 tlr Exp $
;*
;* DESCRIPTION
;*   The pattern editor. (relies on editor.asm for the dirty work)
;*
;******

PattZP		EQU	$fb
VoiceZP		EQU	$fd
VoiceZP2	EQU	$f9
ConvZP		EQU	$f8

;**************************************************************************
;*
;* EditPattern
;*
;******
EditPattern:
	jsr	UnEdit

	ldx	#4
edp_lp2:
	lda	pl_vd_PatternTabLow,x
	sta	PattZP
	lda	pl_vd_PatternTabHigh,x
	sta	PattZP+1
	ldy	epl_CurrentLine
	lda	(PattZP),y
	and	#MAXNUMPATTERNS_MASK
	sta	EditRow,x
	dex
	bpl	edp_lp2

; only edit the length specified
	ldy	epl_CurrentLine
	lda	pl_LengthTab,y
	and	#$1f		; Max pattern length
	sta	edp_Length

	ldy	#2
	ldx	#0
edp_lp3:
	jsr	edp_GetPatternAddr

	lda	PattZP
	sta	edp_AddressTabLOW,y
	sta	edp_AddressTabLOW+1,y
	lda	PattZP+1
	sta	edp_AddressTabHIGH,y
	sta	edp_AddressTabHIGH+1,y
	iny
	iny
	inc	PattZP
	bne	edp_skp1
	inc	PattZP+1
edp_skp1:
	lda	PattZP
	sta	edp_AddressTabLOW,y
	sta	edp_AddressTabLOW+1,y
	lda	PattZP+1
	sta	edp_AddressTabHIGH,y
	sta	edp_AddressTabHIGH+1,y
	iny
	iny

	inx
	cpx	#5
	bne	edp_lp3
	

	ldx	#0
edp_lp1:
	lda	edp_INFOBLOCK,x
	sta	INFOBLOCK,x
	inx
	cpx	#ib_sizeof
	bne	edp_lp1

	jsr	StartEdit
	rts

UnEditPattern:
	ldx	#0
uedp_lp1:
	lda	INFOBLOCK,x
	sta	edp_INFOBLOCK,x
	inx
	cpx	#ib_sizeof
	bne	uedp_lp1

	rts

edp_Screen:
	ldy	#0
	lda	epl_CurrentLine
	jsr	PutHex
	ldx	#0
edps_lp1:
	lda	#30	;pilupp
	sta	(ScreenZP),y
	iny
	lda	EditRow,x
	jsr	PutHex
	lda	#" "
	sta	(ScreenZP),y
	iny
	inx
	cpx	#5
	bne	edps_lp1
	rts

edp_Update:
	rts

;**************************************************************************
;*
;* NAME  edp_CheckKeys
;*
;* DESCRIPTION
;*   Check all pattern editor keys.
;*   This gets called as a call back from the main editor.
;*   
;* KNOWN BUGS
;*   none
;*
;******
edp_CheckKeys:
	cmp	#"R"		;R
	beq	edpc_Arp
	cmp	#"S"		;S
	beq	edpc_Sound
	cmp	#13		;RETURN
	beq	edpc_Edit
	cmp	#95		;<-
	beq	edpc_Find
	cmp	#170		; C= N
	beq	edpc_PattlistRowUp
	cmp	#167		; C= M
	beq	edpc_PattlistRowDown
	cmp	#181		; C= J
	beq	edpc_PatternUp
	cmp	#161		; C= K
	beq	edpc_PatternDown

	jmp	edp_CheckClipBoardKeys

; Switch back to Pattlist Edit
edpc_Edit:
; calculate which position in the pattlist editor corresponds to
; which position in the pattern editor
	jsr	edp_GetVoiceNum	;Acc=voicenumber

	sta	MultTmp
	asl
	clc
	adc	MultTmp		;Acc=voicenumber*3

	clc
	adc	#4		;Acc=voicenumber*3+4
	sta	epl_CurrentColumn

;Initiate the pattlist editor
	jsr	EditPattList
	jsr	ToggleCursor
	jmp	edpc_ex1
	
; Switch to Arpeggio Edit
edpc_Arp:
	jsr	EditArp
	jsr	ToggleCursor
	jmp	edpc_ex1

; Switch to Sound Edit
edpc_Sound:
	jsr	EditSound
	jsr	ToggleCursor
	jmp	edpc_ex1

; Find first unused pattern
edpc_Find:
	jsr	FindFirstUnused
	bcs	edpc_ex1	;no pattern could be found
	pha
	jsr	edp_GetPattListAddr
	pla
	sta	(PattZP),y	;Store into pattlist
	jmp	edpc_ex2

; Increase/decrease pattern number in pattlist.
edpc_PatternUp:
	jsr	edp_GetPattListAddr
	lda	(PattZP),y
	clc
	adc	#1
	and	#MAXNUMPATTERNS_MASK
	sta	(PattZP),y
	jmp	edpc_ex2
edpc_PatternDown:
	jsr	edp_GetPattListAddr
	lda	(PattZP),y
	sec
	sbc	#1
	and	#MAXNUMPATTERNS_MASK
	sta	(PattZP),y
	jmp	edpc_ex2

; Increase/decrease which row in the pattlist we are editing.
edpc_PattlistRowUp:
	inc	epl_CurrentLine
	jmp	edpc_ex2
edpc_PattlistRowDown:
	dec	epl_CurrentLine
edpc_ex2:
	jsr	EditPattern
	jsr	ToggleCursor
edpc_ex1:
	lda	#0
	rts
	
;**************************************************************************
;*
;* NAME  edp_CheckClipBoardKeys
;*
;* DESCRIPTION
;*   Check keys for clipboard functions.
;*   
;* KNOWN BUGS
;*   none
;*
;******
edp_CheckClipBoardKeys:
	cmp	#191		; C= B
	beq	edpc_Begin
	cmp	#188		; C= C
	beq	edpc_Copy
	cmp	#189		; C= X
	beq	edpc_Cut
	cmp	#190		; C= V
	beq	edpc_Paste

	jmp	edp_CheckInsertKeys

;**************************************************************************
;*
;* NAME  edpc_Begin,edpc_Cut,edpc_Copy
;*
;* DESCRIPTION
;*   Handles the pattern clipboard.
;*   
;* KNOWN BUGS
;*   none
;*
;******
;Set the begin marker.
edpc_Begin:
	lda	CurrentLine
	sta	edp_ClipBoardBegin
	lda	#0
	sta	edp_ClipBoardLen
	jmp	edpc_ex1
edpc_Cut:
	lda	#1
	dc.b	$2c		; bit $xxxx
edpc_Copy:
	lda	#0
	sta	edp_CutFlag
	jsr	edp_GetVoiceNum
	tax
	jsr	edp_GetPatternAddr

; load data into the clipboard.
	ldx	#0
	ldy	edp_ClipBoardBegin
edpcc_lp1:
	tya
	pha

	asl
	tay
	lda	(PattZP),y
	sta	edp_ClipBoardNote,x
	iny
	lda	(PattZP),y
	sta	edp_ClipBoardParam,x

	lda	edp_CutFlag	; shall we cut the data?
	beq	edpcc_skp2	; no, skip clearing
	lda	#0
	sta	(PattZP),y
	dey
	sta	(PattZP),y
edpcc_skp2:

	pla
	tay
	cpy	edp_Length	; Are we at the last pattern step
	bne	edpcc_skp1	; no... skip.
	ldy	#$ff		; yes, start over.
edpcc_skp1:
	inx
	iny
	cpy	CurrentLine
	bne	edpcc_lp1
	stx	edp_ClipBoardLen
	
	jmp	edpc_ex2

edpc_Paste:
	lda	edp_ClipBoardLen
	beq	edpc_ex1	; nothing to paste, get out!
	
	jsr	edp_GetVoiceNum
	tax
	jsr	edp_GetPatternAddr

; paste data from the clipboard.
; load data into the clipboard.
	ldx	#0
	ldy	CurrentLine
edpcp_lp1:
	tya
	pha

	asl
	tay
	lda	edp_ClipBoardNote,x
	sta	(PattZP),y
	iny
	lda	edp_ClipBoardParam,x
	sta	(PattZP),y

	pla
	tay
	cpy	edp_Length	; Are we at the last pattern step
	bne	edpcp_skp1	; no... skip.
	ldy	#$ff		; yes, start over.
edpcp_skp1:
	inx
	iny
	cpx	edp_ClipBoardLen
	bne	edpcp_lp1

	jmp	edpc_ex2

;**************************************************************************
;*
;* NAME  edp_CheckInsertKeys
;*
;* DESCRIPTION
;*   Check keys for Insert/Delete Clear functions.
;*   
;* KNOWN BUGS
;*   none
;*
;******
edp_CheckInsertKeys:
	cmp	#147		; SHIFT-CLR/HOME
	beq	edpc_Clear

	jmp	edp_CheckTransposeKeys

;**************************************************************************
;*
;* NAME  edp_Clear
;*
;* DESCRIPTION
;*   Clears the pattern under cursor.  (after asking)
;*   
;* KNOWN BUGS
;*   none
;*
;******
edpc_Clear:
	jsr	AreYouSure
	beq	edpcl_ex1
	jsr	edp_GetVoiceNum
	tax
	jsr	edp_GetPatternAddr

	ldx	edp_Length	; The number of lines in the pattern-1
	lda	#0
	tay
edpcl_lp1:
	sta	(PattZP),y
	iny
	sta	(PattZP),y
	iny
	dex
	bpl	edpcl_lp1	; Are we finished?
	jmp	edpc_ex2
		
edpcl_ex1:
	jmp	edpc_ex1
		
;**************************************************************************
;*
;* NAME  edp_CheckTransposeKeys
;*
;* DESCRIPTION
;*   Check keys for transpose functions.
;*   
;* KNOWN BUGS
;*   none
;*
;******
edp_CheckTransposeKeys:
	cmp	#163		; C= T
	beq	edpc_TransUp
	cmp	#183		; C= Y
	beq	edpc_TransDown

	cmp	#0
	rts

;**************************************************************************
;*
;* NAME  edp_TransDown,edp_TransUp
;*
;* DESCRIPTION
;*   Transposes the pattern under cursor up or down.
;*   
;* KNOWN BUGS
;*   Does not handle notes outside the normal range correctly.
;*   Does not handle a noise channel pattern correctly
;*
;******
edpc_TransDown:
	lda	#1
	dc.b	$2c		; bit $xxxx
edpc_TransUp:
	lda	#0
	sta	edp_TransDownFlag

	jsr	edp_GetVoiceNum
	tax
	jsr	edp_GetPatternAddr

	ldx	edp_Length
	ldy	#0
edpct_lp1:
	lda	(PattZP),y
	pha
	and	#$80
	sta	edp_TransMask
	pla
	pha
	and	#$70
	sta	edp_TransOct
	pla
	pha
	and	#$0f
	sta	edp_TransNote
	pla
	and	#$7f
	beq	edpct_skp1	;Do nothing for ties and empties

	lda	edp_TransDownFlag
	bne	edpct_skp4

; Transpose this note up!
	lda	edp_TransNote
	clc
	adc	#1
	cmp	#$c
	bne	edpct_skp2
	lda	edp_TransOct
	clc
	adc	#$10
	cmp	#$80
	bne	edpct_skp3
	lda	#$10
edpct_skp3:
	sta	edp_TransOct
	lda	#0
edpct_skp2:
	sta	edp_TransNote
	jmp	edpct_skp5

; Transpose this note down!
edpct_skp4:
	lda	edp_TransNote
	sec
	sbc	#1
	cmp	#$ff
	bne	edpct_skp6
	lda	edp_TransOct
	sec
	sbc	#$10
	bne	edpct_skp7
	lda	#$70
edpct_skp7:
	sta	edp_TransOct
	lda	#$b
edpct_skp6:
	sta	edp_TransNote
	
; Reassemble the note!
edpct_skp5:
	lda	edp_TransMask
	ora	edp_TransOct
	ora	edp_TransNote
	sta	(PattZP),y
edpct_skp1:
	iny
	iny
	dex
	bpl	edpct_lp1
	jmp	edpc_ex2

edp_TransDownFlag:
	ds.b	1
edp_TransMask:
	ds.b	1
edp_TransOct:
	ds.b	1
edp_TransNote:
	ds.b	1

;**************************************************************************
;*
;* NAME  edp_GetVoiceNum
;*
;* DESCRIPTION
;*   returns the voicenumber corresponding to the current cursor position.
;*   Acc=VoiceNum
;*
;******
edp_GetVoiceNum:
	lda	CurrentColumn
	sec
	sbc	#2
	lsr
	lsr			;Acc=voicenumber
	rts

;**************************************************************************
;*
;* NAME  edp_GetPattListAddr
;*
;* DESCRIPTION
;*   Sets PattZP to the address of the pattlist corresponding to the voicenum.
;*   PattZP=address of pattlist edited in the current voice.
;*   Y=row.
;*
;******
edp_GetPattListAddr:
	jsr	edp_GetVoiceNum
	clc
	adc	#>pl_Tab1
	sta	PattZP+1
	lda	#<pl_Tab1
	sta	PattZP		;PattZP=pl_Tab{VoiceNum}
	ldy	epl_CurrentLine
	rts

;**************************************************************************
;*
;* NAME  edp_GetPatternAddr
;*
;* DESCRIPTION
;*   Sets PattZP to the address of the pattern corresponding to the voicenum.
;*   PattZP=address of pattern edited in voice X.
;*
;******
edp_GetPatternAddr:
	lda	#0
	sta	PattZP+1
	lda	EditRow,x
	asl
	rol	PattZP+1
	asl
	rol	PattZP+1
	asl
	rol	PattZP+1
	asl
	rol	PattZP+1
	asl
	rol	PattZP+1
	asl
	rol	PattZP+1
	clc
	adc	#<pl_PatternData
	sta	PattZP
	lda	PattZP+1
	adc	#>pl_PatternData
	sta	PattZP+1
	rts

; The clipboard
edp_ClipBoardBegin:
	dc.b	0
edp_ClipBoardNote:
	ds.b	32
edp_ClipBoardParam:
	ds.b	32
edp_ClipBoardLen:
	dc.b	0
edp_CutFlag:			; Temporary
	dc.b	0

; patterns currently under editing
EditRow:
	dc.b	0,0,0,0,0

MultTmp:
	dc.b	0

edp_INFOBLOCK:
;*** THE INFO BLOCK ***
edp_EditMode:
	dc.b	EDIT_PATTERN
; The line we are editing (in the middle of the edit area)
edp_CurrentLine:
	dc.b	0
; The column we are editing
edp_CurrentColumn:
	dc.b	2
; When a character was entered where should we go?
; any nonzero here will make it down else right
edp_AdvanceMode:
	dc.b	0
edp_EditStep:
	dc.b	1
edp_InitRoutine:
	dc.w	EditPattern
edp_ScreenRoutine:
	dc.w	edp_Screen
edp_UpdateRoutine:
	dc.w	edp_Update
edp_KeyRoutine:
	dc.w	edp_CheckKeys
edp_TermRoutine:
	dc.w	UnEditPattern
edp_Length:
	dc.b	32-1
; Number of shifts
edp_Step:
	dc.b	1
edp_ColorTab:
	dc.b	LineNumColor,LineNumColor
	dc.b	Edit1Color,Edit1Color,Edit1Color,Edit1Color
	dc.b	Edit2Color,Edit2Color,Edit2Color,Edit2Color
	dc.b	Edit1Color,Edit1Color,Edit1Color,Edit1Color
	dc.b	Edit2Color,Edit2Color,Edit2Color,Edit2Color
	dc.b	Edit1Color,Edit1Color,Edit1Color,Edit1Color
edp_CursorTab:
	dc.b	CT_HIGHNYBBLE|CT_LINENUM,CT_LINENUM
	dc.b	CT_HIGHNYBBLE|CT_DATA|CT_NOTE,CT_DATA|CT_NOTE
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA|CT_NOTE,CT_DATA|CT_NOTE
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA|CT_NOTE,CT_DATA|CT_NOTE
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA|CT_NOTE,CT_DATA|CT_NOTE
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
edp_AddressTabLOW:
	ds.b	22
edp_AddressTabHIGH:
	ds.b	22

; eof
