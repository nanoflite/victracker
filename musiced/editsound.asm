;**************************************************************************
;*
;* FILE  editsound.asm
;* Copyright (c) 1994, 2003 Daniel Kahlin <daniel@kahlin.net>
;* Written by Daniel Kahlin <daniel@kahlin.net>
;* $Id: editsound.asm,v 1.4 2003/08/02 15:42:00 tlr Exp $
;*
;* DESCRIPTION
;*   The sound editor. (relies on editor.asm for the dirty work)
;*
;******

;**************************************************************************
;*
;* EditSound
;*
;******
EditSound:
	ldx	InitRoutine
	ldy	InitRoutine+1
	stx	eds_LastRoutine
	sty	eds_LastRoutine+1

	jsr	UnEdit

	ldx	#0
eds_lp1:
	lda	eds_INFOBLOCK,x
	sta	INFOBLOCK,x
	inx
	cpx	#ib_sizeof
	bne	eds_lp1

	jsr	StartEdit
	rts


UnEditSound:
	ldx	#0
ueds_lp1:
	lda	INFOBLOCK,x
	sta	eds_INFOBLOCK,x
	inx
	cpx	#ib_sizeof
	bne	ueds_lp1

	rts


eds_Screen:
	ldy	#22-1
eds_lp2:
	lda	Sound_MSG,y
	and	#$3f
	sta	(ScreenZP),y
	dey
	bpl	eds_lp2
	rts
Sound_MSG:
	dc.b	"        SOUNDS        "

eds_Update:
	rts

eds_CheckKeys:
	cmp	#13
	beq	eds_Edit
	cmp	#"R"
	beq	eds_Arp
	cmp	#0
	rts

; Switch to Arpeggio Edit
eds_Arp:
	jsr	EditArp
	ldx	eds_LastRoutine
	ldy	eds_LastRoutine+1
	stx	eda_LastRoutine
	sty	eda_LastRoutine+1
	jsr	ToggleCursor
	jmp	edsc_ex1

eds_Edit:
;Branch to InitRoutine
	lda	#>[edse_ret1-1]
	pha
	lda	#<[edse_ret1-1]
	pha
	jmpind	eds_LastRoutine
edse_ret1:
	jsr	ToggleCursor
edsc_ex1:
	lda	#0
	rts

eds_LastRoutine:
	dc.w	0

eds_INFOBLOCK:
;*** THE INFO BLOCK ***
eds_EditMode:
	dc.b	EDIT_SOUND
; The line we are editing (in the middle of the edit area)
eds_CurrentLine:
	dc.b	0
; The column we are editing
eds_CurrentColumn:
	dc.b	4
; When a character was entered where should we go?
; any nonzero here will make it down else right
eds_AdvanceMode:
	dc.b	0
eds_EditStep:
	dc.b	1
eds_InitRoutine:
	dc.w	EditSound
eds_ScreenRoutine:
	dc.w	eds_Screen
eds_UpdateRoutine:
	dc.w	eds_Update
eds_KeyRoutine:
	dc.w	eds_CheckKeys
eds_TermRoutine:
	dc.w	UnEditSound
eds_Length:
	dc.b	16-1
; Number of shifts
eds_Step:
	dc.b	3
eds_ColorTab:
	dc.b	LineNumColor,LineNumColor
	dc.b	0,0
	dc.b	Edit1Color,Edit1Color
	dc.b	Edit2Color,Edit2Color
	dc.b	Edit1Color,Edit1Color
	dc.b	Edit2Color,Edit2Color
	dc.b	Edit1Color,Edit1Color
	dc.b	Edit2Color,Edit2Color
	dc.b	Edit1Color,Edit1Color
	dc.b	Edit2Color,Edit2Color
	dc.b	0,0
eds_CursorTab:
	dc.b	CT_HIGHNYBBLE|CT_LINENUM,CT_LINENUM
	dc.b	0,0
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	0,0
eds_AddressTabLOW:
	dc.b	0,0,0,0
	dc.b	<[pl_Sounds+0],<[pl_Sounds+0]
	dc.b	<[pl_Sounds+1],<[pl_Sounds+1]
	dc.b	<[pl_Sounds+2],<[pl_Sounds+2]
	dc.b	<[pl_Sounds+3],<[pl_Sounds+3]
	dc.b	<[pl_Sounds+4],<[pl_Sounds+4]
	dc.b	<[pl_Sounds+5],<[pl_Sounds+5]
	dc.b	<[pl_Sounds+6],<[pl_Sounds+6]
	dc.b	<[pl_Sounds+7],<[pl_Sounds+7]
	dc.b	0,0
eds_AddressTabHIGH:
	dc.b	0,0,0,0
	dc.b	>[pl_Sounds+0],>[pl_Sounds+0]
	dc.b	>[pl_Sounds+1],>[pl_Sounds+1]
	dc.b	>[pl_Sounds+2],>[pl_Sounds+2]
	dc.b	>[pl_Sounds+3],>[pl_Sounds+3]
	dc.b	>[pl_Sounds+4],>[pl_Sounds+4]
	dc.b	>[pl_Sounds+5],>[pl_Sounds+5]
	dc.b	>[pl_Sounds+6],>[pl_Sounds+6]
	dc.b	>[pl_Sounds+7],>[pl_Sounds+7]
	dc.b	0,0

; eof
