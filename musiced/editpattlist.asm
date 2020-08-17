;**************************************************************************
;*
;* FILE  editpattlist.asm
;* Copyright (c) 1994, 2003 Daniel Kahlin <daniel@kahlin.net>
;* Written by Daniel Kahlin <daniel@kahlin.net>
;* $Id: editpattlist.asm,v 1.9 2003/08/07 13:47:07 tlr Exp $
;*
;* DESCRIPTION
;*   The pattern list editor. (relies on editor.asm for the dirty work)
;*
;******

;**************************************************************************
;*
;* EditPattList
;*
;******
EditPattList:
	jsr	UnEdit

	ldx	#0
epl_lp1:
	lda	epl_INFOBLOCK,x
	sta	INFOBLOCK,x
	inx
	cpx	#ib_sizeof
	bne	epl_lp1

	jsr	StartEdit
	rts


UnEditPattList:
	ldx	#0
uepl_lp1:
	lda	INFOBLOCK,x
	sta	epl_INFOBLOCK,x
	inx
	cpx	#ib_sizeof
	bne	uepl_lp1

	rts


epl_Screen:
	ldy	#22-1
epl_lp2:
	lda	PattList_MSG,y
	and	#$3f
	sta	(ScreenZP),y
	dey
	bpl	epl_lp2
	rts
PattList_MSG:
	dc.b	"      PATTERNLIST     "


epl_Update:
	lda	CurrentLine
	sta	LastPattListLine
	rts

;**************************************************************************
;*
;* NAME  epl_CheckKeys
;*
;* DESCRIPTION
;*   Check all patternlist editor keys.
;*   This gets called as a call back from the main editor.
;*   
;* KNOWN BUGS
;*   none
;*
;******
epl_CheckKeys:
	cmp	#"R"		;R
	beq	eplc_EditArp
	cmp	#"S"		;S
	beq	eplc_EditSound
	cmp	#13		;RETURN
	beq	eplc_Edit
	cmp	#95		;<-
	beq	eplc_Find

	cmp	#20		;INST/DEL
	beq	eplc_Delete
	cmp	#148		;SHIFT-INST/DEL
	beq	eplc_Insert
	
	cmp	#0
	rts

; Switch to Pattern Edit
eplc_Edit:
	lda	#0
	sta	edp_CurrentLine		;PatternEdit from line 0

; calculate which position in the pattern editor corresponds to
; which position in the pattlist editor
	jsr	epl_GetVoiceNum
	tax			;VoiceNum
	lda	epl_MapTable2,x
	sta	edp_CurrentColumn
;Initiate the pattern editor
	jsr	EditPattern
	jsr	ToggleCursor
	jmp	eplc_ex1

;Target pattern editor positions for each voice
epl_MapTable2:
	dc.b	2,6,10,14,18,18

; Switch to Arpeggio Edit
eplc_EditArp:
	jsr	EditArp
	jsr	ToggleCursor
	jmp	eplc_ex1

; Switch to Sound Edit
eplc_EditSound:
	jsr	EditSound
	jsr	ToggleCursor
	jmp	eplc_ex1
		
eplc_ex2:
	jsr	EditPattList
	jsr	ToggleCursor
eplc_ex1:
	lda	#0
	rts

; Find first unused pattern
eplc_Find:
	jsr	FindFirstUnused
	bcs	eplc_ex1	;no pattern could be found
	sta	PokeByte
	pla	;Pull return Adress
	pla
	lda	#$00
	sta	PokeMask	;Update the whole byte
	jmp	ch_Poke		

; Delete 
eplc_Delete:
	jsr	epl_GetPattListAddr
	ldy	CurrentLine
	beq	eplc_ex1
eplcd_lp1:
	lda	(PattZP),y
	dey
	sta	(PattZP),y
	iny
	iny
	bne	eplcd_lp1
	tya			; Acc=0
	dey			; Y=$ff
	sta	(PattZP),y	
	dec	CurrentLine
	jmp	eplc_ex2
; Insert 
eplc_Insert:
	jsr	epl_GetPattListAddr
	ldy	CurrentLine
	cpy	#$ff
	beq	eplci_ex1	; If at the last position, just clear.
	ldy	#$ff
eplci_lp1:
	dey
	lda	(PattZP),y
	iny
	sta	(PattZP),y
	dey
	cpy	CurrentLine
	bne	eplci_lp1
eplci_ex1:
	lda	#0
	sta	(PattZP),y	
	jmp	eplc_ex2

LastPattListLine:
	dc.b	0

;**************************************************************************
;*
;* NAME  epl_GetVoiceNum
;*
;* DESCRIPTION
;*   returns the voicenumber corresponding to the current cursor position.
;*   Acc=VoiceNum
;*
;******
epl_GetVoiceNum:
	ldx	CurrentColumn
	lda	epl_MapTable,x
	rts
; Voice as a function of cursor position
epl_MapTable:
	dc.b	0,0,0,0
	dc.b	0,0,0
	dc.b	1,1,1
	dc.b	2,2,2
	dc.b	3,3,3
	dc.b    4,4,4
	dc.b	5,5,5

;**************************************************************************
;*
;* NAME  epl_GetPattListAddr
;*
;* DESCRIPTION
;*   Sets PattZP to the address of the pattlist corresponding to the voicenum.
;*   PattZP=address of pattlist in the current voice.
;*
;******
epl_GetPattListAddr:
	jsr	epl_GetVoiceNum
	tax
	lda	epl_AddrLow,x
	sta	PattZP
	lda	epl_AddrHigh,x
	sta	PattZP+1
	rts
	
epl_AddrLow:
	dc.b	<pl_Tab1,<pl_Tab2,<pl_Tab3,<pl_Tab4,<pl_Tab5,<pl_LengthTab
epl_AddrHigh:
	dc.b	>pl_Tab1,>pl_Tab2,>pl_Tab3,>pl_Tab4,>pl_Tab5,>pl_LengthTab
	
epl_INFOBLOCK:
;*** THE INFO BLOCK ***
epl_EditMode:
	dc.b	EDIT_PATTLIST
; The line we are editing (in the middle of the edit area)
epl_CurrentLine:
	dc.b	0
; The column we are editing
epl_CurrentColumn:
	dc.b	4
; When a character was entered where should we go?
; any nonzero here will make it down else right
epl_AdvanceMode:
	dc.b	0
epl_EditStep:
	dc.b	1
epl_InitRoutine:
	dc.w	EditPattList
epl_ScreenRoutine:
	dc.w	epl_Screen
epl_UpdateRoutine:
	dc.w	epl_Update
epl_KeyRoutine:
	dc.w	epl_CheckKeys
epl_TermRoutine:
	dc.w	UnEditPattList
epl_Length:
	dc.b	256-1
; Number of shifts
epl_Step:
	dc.b	0
epl_ColorTab:
	dc.b	LineNumColor,LineNumColor
	dc.b	0,0
	dc.b	Edit1Color,Edit1Color
	dc.b	0
	dc.b	Edit2Color,Edit2Color
	dc.b	0
	dc.b	Edit1Color,Edit1Color
	dc.b	0
	dc.b	Edit2Color,Edit2Color
	dc.b	0
	dc.b	Edit1Color,Edit1Color
	dc.b	0
	dc.b	Edit3Color,Edit3Color
	dc.b	0
epl_CursorTab:
	dc.b	CT_HIGHNYBBLE|CT_LINENUM,CT_LINENUM
	dc.b	0,0
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	0
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	0
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	0
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	0
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	0
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	0
epl_AddressTabLOW:
	dc.b	0,0,0,0
	dc.b	<pl_Tab1,<pl_Tab1
	dc.b	0
	dc.b	<pl_Tab2,<pl_Tab2
	dc.b	0
	dc.b	<pl_Tab3,<pl_Tab3
	dc.b	0
	dc.b	<pl_Tab4,<pl_Tab4
	dc.b	0
	dc.b	<pl_Tab5,<pl_Tab5
	dc.b	0
	dc.b	<pl_LengthTab,<pl_LengthTab
	dc.b	0
epl_AddressTabHIGH:
	dc.b	0,0,0,0
	dc.b	>pl_Tab1,>pl_Tab1
	dc.b	0
	dc.b	>pl_Tab2,>pl_Tab2
	dc.b	0
	dc.b	>pl_Tab3,>pl_Tab3
	dc.b	0
	dc.b	>pl_Tab4,>pl_Tab4
	dc.b	0
	dc.b	>pl_Tab5,>pl_Tab5
	dc.b	0
	dc.b	>pl_LengthTab,>pl_LengthTab
	dc.b	0

; eof
