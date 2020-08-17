;**************************************************************************
;*
;* FILE  editor.asm
;* Copyright (c) 1994, 2003 Daniel Kahlin <daniel@kahlin.net>
;* Written by Daniel Kahlin <daniel@kahlin.net>
;* $Id: editor.asm,v 1.11 2003/08/07 12:53:35 tlr Exp $
;*
;* DESCRIPTION
;*   The main editor.  Does all the dirty work for editpattern.asm,
;*   editarp.asm, editpattlist.asm.
;*
;*   Public:
;*     ResetEditor
;*     EditRoutine
;*     UnEdit
;*     StartEdit
;*
;******
OffsetZP	EQU	$f7
PeekZP		EQU	$f9

	
;**************************************************************************
;*
;* EditorStuff
;*
;******
ResetEditor:
	ldx	#0
	txa
re_lp1:
	sta	INFOBLOCK,x
	inx
	cpx	#ib_sizeof
	bne	re_lp1
	; FALL THRU
InitEditor:
	lda	#>ColorRAM
	sta	ColorZP+1
	lda	#>ScreenRAM
	sta	ScreenZP+1
	rts


;**************************************************************************
;*
;* UnEdit
;*
;******
UnEdit:
	lda	TermRoutine
	ora	TermRoutine+1
	beq	ue_ex1
;Branch to TermRoutine
	lda	#>[ue_ret1-1]
	pha
	lda	#<[ue_ret1-1]
	pha
	jmpind	TermRoutine
ue_ret1:

ue_ex1:
	rts

;**************************************************************************
;*
;* StartEditor
;*
;******
StartEdit:
	jsr	SetColors
	jsr	PrintPattern

	lda	#<[ScreenRAM+22*9]
	sta	ScreenZP
	lda	#>[ScreenRAM+22*9]
	sta	ScreenZP+1
;Branch to ScreenRoutine
	lda	#>[se_ret1-1]
	pha
	lda	#<[se_ret1-1]
	pha
	jmpind	ScreenRoutine
se_ret1:

	jsr	ToggleCursor
	rts

;**************************************************************************
;*
;* Setup Colors for edit
;*
;******
SetColors:
; Setup the colors of the edit info line
	lda	#EditTextColor2
	sta	ColorRAM+22*9
	sta	ColorRAM+22*9+1

	ldx	#2
	lda	#EditTextColor
sc_lp3:
	sta	ColorRAM+22*9,x
	inx
	cpx	#22
	bne	sc_lp3

;Set up the colors of the edit area
	lda	#>ColorRAM
	sta	ColorZP+1
	lda	#<ColorRAM
	sta	ColorZP

	ldx	#8
sc_lp1:
	ldy	#21
sc_lp2:
	lda	ColorTab,y
	sta	(ColorZP),y	
	dey
	bpl	sc_lp2
	lda	ColorZP
	clc
	adc	#22
	sta	ColorZP
	dex
	bpl	sc_lp1
	rts


;**************************************************************************
;*
;* Update whole Pattern 
;*
;******
PrintPattern:
	lda	#>ScreenRAM
	sta	ScreenZP+1
	lda	CurrentLine
	sec
	sbc	#4
	sta	CLine
	lda	#0
	sbc	#0
	sta	CLine+1

	ldy	#0
pp_lp1:
	lda	ScreenTabLOW,y
	sta	ScreenZP

	lda	CLine+1
	bne	pp_skp1
	lda	Length
	cmp	CLine
	bcc	pp_skp1
	lda	CLine
	jsr	PrintEditLine
	jmp	pp_skp2
pp_skp1:
	jsr	BlankLine
pp_skp2:
	inc	CLine
	bne	pp_skp3
	inc	CLine+1
pp_skp3:
	iny
	cpy	#9
	bne	pp_lp1
	rts		
CLine:
	dc.w	0

;**************************************************************************
;*
;* Print A row in a pattern 
;*
;* A - Line
;*
;******
BlankLine:
	tya
	pha
	ldy	#0
bl_lp1:
	lda	#$20
	sta	(ScreenZP),y
	iny
	cpy	#22
	bne	bl_lp1
	pla
	tay
	rts

PrintEditLine:
	sta	LineTemp
	txa
	pha
	tya
	pha
	
	lda	#0
	sta	OffsetZP+1
	lda	LineTemp
	ldx	Step
	beq	pel_skp3
pel_lp2:
	asl
	rol	OffsetZP+1
	dex
	bne	pel_lp2
pel_skp3:
	sta	OffsetZP

	ldy	#0
	ldx	#0
pel_lp1:
	sty	YTemp
	lda	CursorTab,x
	beq	pel_PBlank
	and	#CT_LINENUM	;LineNum?
	bne	pel_PLineNum
	lda	CursorTab,x
	and	#CT_DATA	;Data?
	bne	pel_PData

;*** Blank **
pel_PBlank:
	lda	#" "
	jmp	pelpd_Put

;*** LineNum ***
pel_PLineNum:
; Print every other line
	lda	LineTemp
	pha
	lda	CursorTab,x
	and	#CT_LINENUMHALF	;LineNum?
	beq	pelpln_skp1
	pla
	lsr
	bcs	pelpd_PutDash
	pha
pelpln_skp1:
	lda	CursorTab,x
	and	#CT_HIGHNYBBLE
	beq	pelln_skp1
	pla
	lsr
	lsr
	lsr
	lsr
	jsr	PutNybble
	jmp	pel_skp1
pelln_skp1:
	pla
	jsr	PutNybble
	jmp	pel_skp1

;*** Data
pel_PData:
	lda	CursorTab,x
	and	#CT_NOSTEP
	bne	pelpd_skp3
	lda	AddressTabLOW,x
	clc
	adc	OffsetZP
	sta	PeekZP
	lda	AddressTabHIGH,x
	adc	OffsetZP+1
	sta	PeekZP+1
	jmp	pelpd_skp4
pelpd_skp3:
	lda	AddressTabLOW,x
	clc
	adc	LineTemp
	sta	PeekZP
	lda	AddressTabHIGH,x
	adc	#0
	sta	PeekZP+1
pelpd_skp4:
	ldy	#0
	lda	CursorTab,x
	and	#CT_NOTE
	beq	pelpd_skp2
;Check for special case notes
	lda	(PeekZP),y
	beq	pelpd_PutDash
	cmp	#$80
	beq	pelpd_PutPlus
;Print ordinary nybble
pelpd_skp2:
	lda	CursorTab,x
	and	#CT_HIGHNYBBLE
	beq	pelpd_skp1

;High nybble...
	lda	(PeekZP),y
	lsr
	lsr
	lsr
	lsr
	ldy	YTemp
	jsr	PutNybble
	jmp	pel_skp1
;Low nybble...
pelpd_skp1:
	lda	(PeekZP),y
	ldy	YTemp
	jsr	PutNybble
pel_skp1:
	inx
	cpx	#22
	beq	pel_ex1
	jmp	pel_lp1
pel_ex1:
	pla
	tay
	pla
	tax
	rts

pelpd_PutDash:
	lda	#"-"
	jmp	pelpd_Put
pelpd_PutPlus:
	lda	#"+"
	;FALL THRU
pelpd_Put:
	ldy	YTemp
	sta	(ScreenZP),y
	iny
	jmp	pel_skp1


;**************************************************************************
;*
;* Main EditorRoutine
;*
;* Check keys and Handle cursor
;*
;******
EditRoutine:
	jsr	ToggleCursor

; check for cursor keys
	cmp	#17
	beq	ed_Down
	cmp	#145
	beq	ed_Up
	cmp	#29
	beq	ed_Right
	cmp	#157
	beq	ed_Left

;Branch to KeyRoutine
	tax
	lda	#>[ed_ret2-1]
	pha
	lda	#<[ed_ret2-1]
	pha
	txa
	jmpind	KeyRoutine
ed_ret2:
	beq	ed_ex1

; check if EditorKEys
	jsr	CheckEditorKeys
	beq	ed_ex1

; check if data is entered
	jsr	ByteInput
	jsr	CheckHex

	jsr	ToggleCursor
	rts
ed_ex1:
	lda	#>[ed_ret1-1]
	pha
	lda	#<[ed_ret1-1]
	pha
	jmpind	UpdateRoutine
ed_ret1:
	jsr	ToggleCursor
	lda	#0
	rts


;**************************************************************************
;*
;* Handle Cursor movement
;*
;* ed_Up
;* ed_Down
;* ed_Right
;* ed_Left
;*
;******
ed_Up:
	lda	CurrentLine
	bne	edu_skp1
	lda	Length
	sta	CurrentLine
	jmp	edu_skp2
edu_skp1:
	dec	CurrentLine
edu_skp2:
	jsr	PrintPattern
	jmp	ed_ex1
ed_Down:
	jsr	ed_GoDown
	jsr	PrintPattern
	jmp	ed_ex1

ed_GoDown:
	lda	CurrentLine
	cmp	Length
	bne	edd_skp1
	lda	#0
	sta	CurrentLine
	jmp	edd_skp2
edd_skp1:
	inc	CurrentLine
edd_skp2:
	rts

ed_Right:
	inc	CurrentColumn
	ldx	CurrentColumn
	cpx	#22
	bne	edr_skp1
	ldx	#0
	stx	CurrentColumn
edr_skp1:
	lda	CursorTab,x
	and	#CT_DATA
	beq	ed_Right
	jmp	ed_ex1
ed_Left:
	dec	CurrentColumn
	ldx	CurrentColumn
	bpl	edl_skp1
	ldx	#21
	stx	CurrentColumn
edl_skp1:
	lda	CursorTab,x
	and	#CT_DATA
	beq	ed_Left
	jmp	ed_ex1

;**************************************************************************
;*
;* ToggleCursor
;*
;* Inverts cursor position
;*
;******
ToggleCursor:
	pha
	ldx	CurrentColumn
	lda	ScreenRAM+22*4,x
	eor	#$80
	sta	ScreenRAM+22*4,x
	pla
	rts


;**************************************************************************
;*
;* ByteInput
;*
;* checks if a Special char was in ACC
;* if it was then change buffers.
;* advance down always
;*
;******
ByteInput:
	pha
	ldx	CurrentColumn
	lda	CursorTab,x
	and	#CT_NOTE
	beq	bi_skp1
	pla
;NOTE $80 may be written using Shift-Space
	cmp	#" "|$80
	beq	bi_FoundShiftSpace
	bne	bi_skp2
bi_skp1:
	pla
;Value $00 may be written using Space
bi_skp2:	
	cmp	#" "
	beq	bi_FoundSpace

	rts

bi_FoundSpace:
	lda	#$00
	sta	PokeByte
	jmp	bi_Found
bi_FoundShiftSpace:
	lda	#$80
	sta	PokeByte
bi_Found:
	pla	;Pull return Adress
	pla
	lda	#$00
	sta	PokeMask	;Update the whole byte
	jmp	ch_Poke		

;**************************************************************************
;*
;* HexInput (Controlled by AdvanceMode) 
;*
;* checks if a hex char was in ACC
;* if it was then change buffers.
;* advance according to AdvanceMode
;*
;******
CheckHex:

	ldx	#15
ch_lp1:
	cmp	HexTab_ASCII,x
	beq	ch_Found
	dex
	bpl	ch_lp1
	rts

HexTab_ASCII:
	dc.b	"0123456789ABCDEF"

;Found Hex Nybble (in x)
ch_Found:
	pla	;Pull return Adress
	pla

	stx	PokeByte
	lda	#$f0
	sta	PokeMask
	ldx	CurrentColumn
	lda	CursorTab,x
	and	#CT_HIGHNYBBLE
	beq	chf_skp1
;Highnybble if even column
	lda	PokeByte
	asl
	asl
	asl
	asl
	sta	PokeByte
	lda	#$0f
	sta	PokeMask
chf_skp1:
	;FALL THRU

ch_Poke:		
	lda	#0
	sta	OffsetZP+1
	lda	CurrentLine
	sta	OffsetZP

	lda	CursorTab,x
	and	#CT_NOSTEP
	bne	ch_skp3
	ldx	Step
	beq	ch_skp3
	lda	OffsetZP
ch_lp2:
	asl
	rol	OffsetZP+1
	dex
	bne	ch_lp2
	sta	OffsetZP
ch_skp3:

	ldx	CurrentColumn
	lda	AddressTabLOW,x
	clc
	adc	OffsetZP
	sta	PokeZP
	lda	AddressTabHIGH,x
	adc	OffsetZP+1
	sta	PokeZP+1

	ldy	#0
	lda	(PokeZP),y
	and	PokeMask
	ora	PokeByte
	sta	(PokeZP),y

	ldy	#4
	lda	#>ScreenRAM
	sta	ScreenZP+1
	lda	ScreenTabLOW,y
	sta	ScreenZP
	lda	CurrentLine
	jsr	PrintEditLine

	lda	PokeMask	;If mask is $00, Go down always
	beq	chf_Down

	lda	AdvanceMode
	beq	chf_Right

chf_Down:
	lda	EditStep
	sec
	sbc	#1
	beq	chf_skp2
	tax
chf_lp1:
	jsr	ed_GoDown
	dex
	bne	chf_lp1
chf_skp2:
	jmp	ed_Down
chf_Right:
	jmp	ed_Right



;**************************************************************************
;*
;* HexConvert 
;*
;******
PutNybble:
	pha
	stx	XTemp
	and	#$0f
	jsr	ph_rec
	ldx	XTemp
	pla
	rts
YTemp:
	dc.b	0
XTemp:
	dc.b	0

PutHex:
	stx	XTemp
	pha
	lsr
	lsr
	lsr
	lsr
	jsr	ph_rec
	pla
	and	#$0f
	jsr	ph_rec
	ldx	XTemp
	rts
ph_rec:
	tax
	lda	HexTab_SCREEN,x
	sta	(ScreenZP),y
	iny
	rts
HexTab_SCREEN:
	dc.b	"0123456789",1,2,3,4,5,6


;**************************************************************************
;*
;* Editor keys
;*
;******
CheckEditorKeys:
	cmp	#137	;F2
	beq	ced_ChangeAdvance
	cmp	#19	;HOME
	beq	ced_Home

;check for SHIFTED numbers
	cmp	#33		;SHIFT-1
	bcc	ced_skp1
	cmp	#42		;SHIFT-0 + 1
	bcc	ced_ShiftNum
ced_skp1:

	jsr	ced_EditStep

	cmp	#0
	rts

ced_ChangeAdvance:
	lda	AdvanceMode
	eor	#$ff
	sta	AdvanceMode
	jmp	ced_ex1

ced_Home:
	lda	#0
	sta	CurrentLine
	jmp	ced_ex2
ced_End:
	lda	Length
	sta	CurrentLine
	jmp	ced_ex2

ced_ShiftNum:
	sec
	sbc	#33		;SHIFT-1
	tax
	beq	ced_Home
	cpx	#8
	beq	ced_End
	lda	Length
	clc
	adc	#1
	ror
	lsr
	lsr
	sta	PeekZP	;Temp
	lda	#0
cedsn_lp1:
	clc
	adc	PeekZP	
	dex
	bne	cedsn_lp1
	sta	CurrentLine
	jmp	ced_ex2

ced_EditStep
	ldx	#10
cedes_lp1:
	cmp	ced_Tab-1,x
	beq	cedes_skp1
	dex
	bne	cedes_lp1
	rts
cedes_skp1:
	stx	EditStep	
	lda	#0
	rts

ced_ex2:
	jsr	PrintPattern
ced_ex1:
	lda	#0
	rts
ced_Tab:	;ASCII for CTRL-1..CTRL-0 
	dc.b	144,5,28,159,156,30,31,158,18,146

;**************************************************************************
;*
;* Data 
;*
;******
ScreenTabLOW:
	dc.b	<[ScreenRAM+22*0]
	dc.b	<[ScreenRAM+22*1]
	dc.b	<[ScreenRAM+22*2]
	dc.b	<[ScreenRAM+22*3]
	dc.b	<[ScreenRAM+22*4]
	dc.b	<[ScreenRAM+22*5]
	dc.b	<[ScreenRAM+22*6]
	dc.b	<[ScreenRAM+22*7]
	dc.b	<[ScreenRAM+22*8]
LineTemp:
	dc.b	0

PokeByte:
	dc.b	0
PokeMask:
	dc.b	0

INFOBLOCK:
;*** THE INFO BLOCK ***
EditMode:
	dc.b	0
; The line we are editing (in the middle of the edit area)
CurrentLine:
	ds.b	1
; The column we are editing
CurrentColumn:
	ds.b	1
; When a character was entered where should we go?
; any nonzero here will make it down else right
AdvanceMode:
	ds.b	1
EditStep:
	ds.b	1
InitRoutine:
	ds.w	1
ScreenRoutine:
	ds.w	1
UpdateRoutine:
	ds.w	1
KeyRoutine:
	ds.w	1
TermRoutine:
	ds.w	1
Length:
	ds.b	1
; Number of shifts
Step:
	ds.b	1
ColorTab:
	ds.b	22
CursorTab:
	ds.b	22
AddressTabLOW:
	ds.b	22
AddressTabHIGH:
	ds.b	22
INFOBLOCKEND:

ib_sizeof	EQU	INFOBLOCKEND-INFOBLOCK

; eof



