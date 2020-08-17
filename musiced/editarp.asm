;**************************************************************************
;*
;* FILE  editarp.asm
;* Copyright (c) 1994, 2003 Daniel Kahlin <daniel@kahlin.net>
;* Written by Daniel Kahlin <daniel@kahlin.net>
;* $Id: editarp.asm,v 1.9 2003/08/02 15:42:00 tlr Exp $
;*
;* DESCRIPTION
;*   The arpeggio editor. (relies on editor.asm for the dirty work)
;*
;******

;**************************************************************************
;*
;* EditArp
;*
;******
EditArp:
	ldx	InitRoutine
	ldy	InitRoutine+1
	stx	eda_LastRoutine
	sty	eda_LastRoutine+1

	jsr	UnEdit

	ldx	#0
eda_lp1:
	lda	eda_INFOBLOCK,x
	sta	INFOBLOCK,x
	inx
	cpx	#ib_sizeof
	bne	eda_lp1

	jsr	StartEdit
	rts


UnEditArp:
	ldx	#0
ueda_lp1:
	lda	INFOBLOCK,x
	sta	eda_INFOBLOCK,x
	inx
	cpx	#ib_sizeof
	bne	ueda_lp1

	rts


eda_Screen:
	ldy	#22-1
eda_lp2:
	lda	Arp_MSG,y
	and	#$3f
	sta	(ScreenZP),y
	dey
	bpl	eda_lp2
	rts
Arp_MSG:
	dc.b	"       ARPEGGIOS      "


eda_Update:
	rts

eda_CheckKeys:
	cmp	#13
	beq	eda_Edit
	cmp	#"S"
	beq	eda_Sound
	cmp	#0
	rts

; Switch to Sound Edit
eda_Sound:
	jsr	EditSound
	ldx	eda_LastRoutine
	ldy	eda_LastRoutine+1
	stx	eds_LastRoutine
	sty	eds_LastRoutine+1
	jsr	ToggleCursor
	jmp	edae_ex1

eda_Edit:
;Branch to InitRoutine
	lda	#>[edae_ret1-1]
	pha
	lda	#<[edae_ret1-1]
	pha
	jmpind	eda_LastRoutine
edae_ret1:
	jsr	ToggleCursor
edae_ex1:
	lda	#0
	rts

eda_LastRoutine:
	dc.w	0

eda_INFOBLOCK:
;*** THE INFO BLOCK ***
eda_EditMode:
	dc.b	EDIT_ARP
; The line we are editing (in the middle of the edit area)
eda_CurrentLine:
	dc.b	0
; The column we are editing
eda_CurrentColumn:
	dc.b	3
; When a character was entered where should we go?
; any nonzero here will make it down else right
eda_AdvanceMode:
	dc.b	0
eda_EditStep:
	dc.b	1
eda_InitRoutine:
	dc.w	EditArp
eda_ScreenRoutine:
	dc.w	eda_Screen
eda_UpdateRoutine:
	dc.w	eda_Update
eda_KeyRoutine:
	dc.w	eda_CheckKeys
eda_TermRoutine:
	dc.w	UnEditArp
eda_Length:
	dc.b	32-1
; Number of shifts
eda_Step:
	dc.b	3
eda_ColorTab:
	dc.b	LineNumColor,LineNumColor
	dc.b	0
	dc.b	Edit3Color,Edit3Color
	dc.b	Edit1Color,Edit1Color
	dc.b	Edit2Color,Edit2Color
	dc.b	Edit1Color,Edit1Color
	dc.b	Edit2Color,Edit2Color
	dc.b	Edit1Color,Edit1Color
	dc.b	Edit2Color,Edit2Color
	dc.b	Edit1Color,Edit1Color
	dc.b	Edit2Color,Edit2Color
	dc.b	0
eda_CursorTab:
	dc.b	CT_LINENUMHALF|CT_HIGHNYBBLE|CT_LINENUM,CT_LINENUMHALF|CT_LINENUM
	dc.b	0
	dc.b	CT_NOSTEP|CT_HIGHNYBBLE|CT_DATA,CT_NOSTEP|CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	CT_HIGHNYBBLE|CT_DATA,CT_DATA
	dc.b	0
eda_AddressTabLOW:
	dc.b	0,0,0
	dc.b	<pl_ArpeggioConf,<pl_ArpeggioConf
	dc.b	<[pl_Arpeggios+0],<[pl_Arpeggios+0]
	dc.b	<[pl_Arpeggios+1],<[pl_Arpeggios+1]
	dc.b	<[pl_Arpeggios+2],<[pl_Arpeggios+2]
	dc.b	<[pl_Arpeggios+3],<[pl_Arpeggios+3]
	dc.b	<[pl_Arpeggios+4],<[pl_Arpeggios+4]
	dc.b	<[pl_Arpeggios+5],<[pl_Arpeggios+5]
	dc.b	<[pl_Arpeggios+6],<[pl_Arpeggios+6]
	dc.b	<[pl_Arpeggios+7],<[pl_Arpeggios+7]
	dc.b	0
eda_AddressTabHIGH:
	dc.b	0,0,0
	dc.b	>pl_ArpeggioConf,>pl_ArpeggioConf
	dc.b	>[pl_Arpeggios+0],>[pl_Arpeggios+0]
	dc.b	>[pl_Arpeggios+1],>[pl_Arpeggios+1]
	dc.b	>[pl_Arpeggios+2],>[pl_Arpeggios+2]
	dc.b	>[pl_Arpeggios+3],>[pl_Arpeggios+3]
	dc.b	>[pl_Arpeggios+4],>[pl_Arpeggios+4]
	dc.b	>[pl_Arpeggios+5],>[pl_Arpeggios+5]
	dc.b	>[pl_Arpeggios+6],>[pl_Arpeggios+6]
	dc.b	>[pl_Arpeggios+7],>[pl_Arpeggios+7]
	dc.b	0

; eof
