;**************************************************************************
;*
;* FILE  docs.asm
;* Copyright (c) 2001 Daniel Kahlin <daniel@kahlin.net>
;* Written by Daniel Kahlin <daniel@kahlin.net>
;* $Id: docs.asm,v 1.4 2003/06/23 22:38:47 tlr Exp $
;*
;* DESCRIPTION
;*   Online documentation browser.
;*
;******

DOCSCREENSIZE	EQU 22*21

;**************************************************************************
;*
;* InitDocs
;*
;******
InitDocs:
	ldx	#<Docs
	ldy	#>Docs
	stx	DocPtr
	sty	DocPtr+1
	rts
DocPtr:
	dc.w	0

;**************************************************************************
;*
;* ViewDocs
;*
;******
ViewDocs:

	lda	DocPtr
	sta	DocZP
	lda	DocPtr+1
	sta	DocZP+1
	
vd_lp1:
	jsr 	UpdateDocs

vd_lp2:
	jsr	$ffe4
	beq	vd_lp2

	cmp	#19   ;home
	bne	vd_skp5
; Move home
	lda	#<Docs
	sta	DocZP
	lda	#>Docs
	sta	DocZP+1
	jmp	vd_lp1

vd_skp5:
	cmp	#147   ;shift home
	bne	vd_skp6
; Move end
	lda	#<(DocsEnd-DOCSCREENSIZE)
	sta	DocZP
	lda	#>(DocsEnd-DOCSCREENSIZE)
	sta	DocZP+1
	jmp	vd_lp1

vd_skp6:
	cmp	#17   ;down
	bne	vd_skp1

; already at end?
	lda	DocZP
	cmp	#<(DocsEnd-DOCSCREENSIZE)
	bne	vd_skp2
	lda	DocZP+1
	cmp	#>(DocsEnd-DOCSCREENSIZE)
	beq	vd_lp2
; no, step forward one row	
vd_skp2:
	lda	DocZP
	clc
	adc	#22
	sta	DocZP
	lda	DocZP+1
	adc	#0
	sta	DocZP+1
	jmp	vd_lp1
vd_skp1:
	cmp	#145  ;up	
	bne	vd_skp4

; already at beginning?
	lda	DocZP
	cmp	#<Docs
	bne	vd_skp3
	lda	DocZP+1
	cmp	#>Docs
	beq	vd_lp2
; no, step back one row	
vd_skp3:
	lda	DocZP
	sec
	sbc	#22
	sta	DocZP
	lda	DocZP+1
	sbc	#0
	sta	DocZP+1
	jmp	vd_lp1

vd_skp4:
	;exit on "any" key
vd_ex1:
	lda	DocZP
	sta	DocPtr
	lda	DocZP+1
	sta	DocPtr+1
	rts

;**************************************************************************
;*
;* Update A Docscreen
;*
;******
UpdateDocs:
	lda	DocZP+1
	pha

	ldx	#<ScreenRAM
	ldy	#>ScreenRAM
	stx	ScreenZP
	sty	ScreenZP+1
	ldx	#<ColorRAM
	ldy	#>ColorRAM
	stx	ColorZP
	sty	ColorZP+1

; view the docs
	ldy	#0
ud_lp1:
	lda	(DocZP),y
	cmp	#"~"
	bne	ud_skp3
	lda	#0  ;insert @ instead of '~'
ud_skp3:
	cmp	#"A"
	bcc	ud_skp1
	cmp	#"Z"+1
	bcs	ud_skp1
	and	#$3f	
ud_skp1:
	sta	(ScreenZP),y
	lda	#DocColor
	sta	(ColorZP),y
	iny
	bne	ud_skp2
	inc	DocZP+1
	inc	ScreenZP+1
	inc	ColorZP+1
ud_skp2:
	lda	ScreenZP+1
	cmp	#>(ScreenRAM+DOCSCREENSIZE)
	bne	ud_lp1
	cpy	#<(ScreenRAM+DOCSCREENSIZE)
	bne	ud_lp1

	pla
	sta	DocZP+1

	rts


;**************************************************************************
;*
;* The Docs:
;*
;******
Docs:
	dc.b	"VIC-TRACKER ONLINE HLP"
	dc.b	"USE CRSR KEYS TO MOVE!"
	dc.b	"@@@@@@@@@@@@@@@@@@@@@@"
	dc.b	"*ALWAYS*              "
	dc.b	"HELP              H   "
	dc.b	"LOAD        SHIFT-L   "
	dc.b	"SAVE        SHIFT-S   "
	dc.b	"DIR         SHIFT-D   "
	dc.b	"INIT        SHIFT-I   "
	dc.b	"PLAY SONG         M   "
	dc.b	"TOGGLE PLAY       P   "
	dc.b	"PLAY FROM STEP    F1  "
	dc.b	"SET STARTSTEP     F3  "
	dc.b	"SET ENDSTEP       F5  "
	dc.b	"INC STARTSPEED    F7  "
	dc.b	"DEC STARTSPEED    F8  "
	dc.b	"                      "
	dc.b	"*ALL EDITORS*         "
	dc.b	"ADVANCE MODE      F2  "
	dc.b	"ENTER DATA        0-F "
	dc.b	"MOVE AROUND       CRSR"
	dc.b	"GO TO TOP         HOME"
	dc.b	"SET EDITSTEP CTRL-1..0"
	dc.b	"GO TO POS   SHIFT-1..9"
	dc.b	"                      "
	dc.b	"*PATTERNEDIT*         "
	dc.b	"GO TO ARPEDIT     R   "
	dc.b	"EXIT PATTERNEDIT  RET "
	dc.b	"                      "
	dc.b	"*PATTERNLIST*         "
	dc.b	"GO TO ARPEDIT     R   "
	dc.b	"EDIT PATTERNS     RET "
	dc.b	"                      "
	dc.b	"*ARPEDIT*             "
	dc.b	"EXIT ARPEDIT      RET "
	dc.b	"                      "
	dc.b	"@@@@@@@@@@@@@@@@@@@@@@"
	dc.b	"                      "
	dc.b	"PATTERNEDIT, 4 DIGITS "
	dc.b	"PER NOTE: 0000        "
	dc.b	"                      "
	dc.b	"NOTEFMT VOICE 1-3     "
	dc.b	"  OCT NOTE EFF PRM    "
	dc.b	"NOTEFMT VOICE 4 NOISE "
	dc.b	"  OCT NOTE EFF PRM    "
	dc.b	"NOTEFMT VOICE 5 VOLUME"
	dc.b	"  SPD VOL  EFF PRM    "
	dc.b	"                      "
	dc.b	"  EFFECT       PARAM  "
	dc.b	"1 PORT UP        SPEED"
	dc.b	"2 PORT DWN       SPEED"
	dc.b	"3 ARPEGGIO      ARPNUM"
	dc.b	"5 PORT UP SLOW   SPEED"
	dc.b	"6 PORT DWN SLOW  SPEED"
	dc.b	"                      "
	dc.b	"@@@@@@@@@@@@@@@@@@@@@@"
	dc.b	"                      "
	dc.b	"VIC-TRACKER WAS CODED "
	dc.b	" IN 1994 AND SOME IN  "
	dc.b	"2001 BY DANIEL KAHLIN "
        dc.b    " <DANIEL~KAHLIN.NET>  "
        dc.b    " WITH SUPPORTAGE FROM "
        dc.b    "   PATRIK WALLSTROM   "
        dc.b    "  <PAWAL~BLIPP.COM>   "
	dc.b	"                      "
	dc.b	"GREETINGS TO:   ACE-3D"
	dc.b	"MR.Z-UC-FRZ-BYMP-PITCH"
	dc.b	"SIKIS-HZ-CDC-TBS-ROMF-"
	dc.b	"THE NINJA-WIC-BACCHUS+"
	dc.b	"FLT-HT-S451-AGILE...  "
	dc.b	"                      "
DocsEnd:

; Tecken
;
; @ horisontellt
; ] lodrät
; k lodrät-V
; s lodrät-H
; q horisontellt-N
; r horisontellt-U
; p ÖV-hörn
; n ÖH-hörn
; m NV-hörn
; } NH-hörn
; [ Jätteplus
;

; eof
