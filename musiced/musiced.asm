;**************************************************************************
;*
;* FILE  musiced.asm
;* Copyright (c) 1994, 2001, 2003 Daniel Kahlin <daniel@kahlin.net>
;* Written by Daniel Kahlin <daniel@kahlin.net>
;* $Id: musiced.asm,v 1.29 2003/08/09 19:12:23 tlr Exp $
;*
;* DESCRIPTION
;*   The main source of the vic-tracker music editor for the
;*   Commodore Vic20.  Atleast 16KB memory required!
;*
;******
	PROCESSOR 6502

	include "../include/macros.i"
	include	"../include/vic20.i"
	include "vt.i"

ScreenRAM	EQU	ScreenRAM_Exp
ColorRAM	EQU	ColorRAM_Exp

ColorZP		EQU	$ac
ScreenZP	EQU	$ae
PokeZP		EQU	$fb
DocZP		EQU	$fe

	seg	code
	org	$1201
;**************************************************************************
;*
;* Basic line!
;*
;******
StartOfFile:
	dc.w	EndLine
	dc.w	RELYEAR
        dc.b    TOKEN_SYS,"4629 /T.L.R/",0
;            200x SYS4629 /T.L.R/
;			 44444444444
;			 66666666666
;			 22222222233
;			 12345678901
EndLine:
	dc.w	0

;**************************************************************************
;*
;* SysAddress... When run we will enter here!
;*
;******
SysAddress:
	jsr	CheckPAL
	lda	HaveBeenRun
	bne	sa_skp1

; clear the song, when run the first time
	jsr	InitTune_force
	IFCONST HAVEFADEIN
	jsr	PrepareFade
	ELSE ;HAVEFADEIN
	lda	#1
	sta	HaveBeenRun
	ENDIF ;HAVEFADEIN
	
sa_skp1:
	jsr	VideoInit

; Enable key repeat
	lda	#255
	sta	650

	jsr	ResetEditor	;This must be the first editor routine to be
				;executed!!!
	jsr	ShowScreen

	IFCONST	HAVEDOCS
; setup doc pointer
	jsr	InitDocs
	ENDIF ;HAVEDOCS

; make us start by editing the pattlist
	jsr	EditPattList

	jsr	InitEditor
	jsr	StartEdit

	IFCONST HAVEFADEIN
	jsr	ShowInfo
	jsr	PrintPlayer
; Here the screen is completely setup...
	lda	HaveBeenRun
	bne	sa_skp2

	lda	#1
	sta	HaveBeenRun
	jsr	PerformFade
sa_skp2:
	ENDIF ;HAVEFADEIN

; Initialize interrupts
	jsr	pl_UnInit	;ensure that music is stopped.
	jsr	InterruptInit

; This is the main loop.
MainLoop:
	jsr	ShowInfo
ml_lp1:
	jsr	PrintPlayer
	jsr	$ffe4	;Wait for key
	beq	ml_lp1

	pha
	jsr	BlankStatus
	pla
	jsr	EditRoutine

	jsr	CheckPlayKeys
	jsr	CheckDiskKeys
	jsr	CheckEditKeys
	IFCONST HAVEDOCS
	jsr	CheckDocKeys
	ENDIF ;HAVEDOCS

	jmp	MainLoop

HaveBeenRun:
	dc.b	0

;**************************************************************************
;*
;* Includes
;*
;******
	include "screen.asm"
	include	"editor.asm"
	include	"editpattern.asm"
	include	"editpattlist.asm"
	include	"editarp.asm"
	include	"editsound.asm"
	include	"disk.asm"
	include	"keys.asm"
	IFCONST HAVEDOCS
	include	"docs.asm"
	ENDIF ;HAVEDOCS
	include	"playersupport.asm"
PlayerStart:
	include	"player.asm"
PlayerEnd:
EditorEnd:
	include	"playerdata.asm"

	SHOWRANGE "Editor    :",StartOfFile,EditorEnd
	IFCONST HAVEDOCS
	SHOWRANGE "Docs      :",Docs,DocsEnd
	ENDIF ;HAVEDOCS
	SHOWRANGE "Player    :",PlayerStart,PlayerEnd
	SHOWRANGE "Data (BSS):",TuneStart,TuneEnd

; eof
