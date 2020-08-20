NTSC    = 1
PAL     = 2

;SYSTEM = NTSC  ; 6560-101: 65 cycles per raster line, 261 lines
SYSTEM  = PAL   ; 6561-101: 71 cycles per raster line, 312 lines

.if SYSTEM & PAL
LINES = 312
CYCLES_PER_LINE = 71
.endif
.if SYSTEM & NTSC
LINES = 261
CYCLES_PER_LINE = 65
.endif

TIMER_VALUE = LINES * CYCLES_PER_LINE - 2

.macro raster line, effect

  ; disable NMIs
  lda #$7f
  sta $912e     ; disable and acknowledge interrupts
  sta $912d
  sta $911e     ; disable NMIs (Restore key)

  ;synchronize with the screen
  ldx #line     ; wait for this raster line (times 2)
@syncloop:
  cpx $9004
  bne @syncloop ; at this stage, the inaccuracy is 7 clock cycles
                ; the processor is in this place 2 to 9 cycles
                ; after $9004 has changed
  ldy #9
  bit $24       ; delay 3 cycles
@loop1:
  ldx $9004
  txa
  bit $24
.if SYSTEM & PAL
  ldx #24
.endif
.if SYSTEM & NTSC
  bit $24
  ldx #21
.endif
  dex
  bne *-1   ; first spend some time (so that the whole
  cmp $9004     ; loop will be 2 raster lines)
  bcs *+2    ; save one cycle if $9004 changed too late
  dey
  bne @loop1 
                ; now it is fully synchronized
                ; 6 cycles have passed since last $9004 change
                ; and we are on line 2(28+9)=74

  ; initialize the timers
  lda #$40      ; enable Timer A free run of both VIAs
  sta $911b
  sta $912b

  lda #<TIMER_VALUE
  ldx #>TIMER_VALUE
  sta $9116     ; load the timer low byte latches
  sta $9126

.if SYSTEM & PAL
  ldy #7        ; make a little delay to get the raster effect to the
  dey           ; right place
  bne *-1
  nop
  nop
.endif
.if SYSTEM & NTSC
  ldy #6
  dey
  bne *-1
  bit $24
.endif

  stx $9125     ; start the IRQ timer A
                ; 6560-101: 65 cycles from $9004 change
                ; 6561-101: 77 cycles from $9004 change
  ldy #10       ; spend some time (1+5*9+4=55 cycles)
  dey           ; before starting the reference timer
  bne *-1
  stx $9115     ; start the reference timer

  lda #<@irq     ; set the raster IRQ routine pointer
  sta $314
  lda #>@irq
  sta $315
  lda #$c0
  sta $912e     ; enable Timer A underflow interrupts
  rts           ; return

@irq:
; irq (event)   ; > 7 + at least 2 cycles of last instruction (9 to 16 total)
; pha           ; 3
; txa           ; 2
; pha           ; 3
; tya           ; 2
; pha           ; 3
; tsx           ; 2
; lda $0104,x   ; 4
; and #xx       ; 2
; beq           ; 3
; jmp ($314)    ; 5
                ; ---
                ; 38 to 45 cycles delay at this stage

  lda $9114     ; get the NMI timer A value
                ; (42 to 49 cycles delay at this stage)
  ;sta $1e00     ; uncomment these if you want to monitor
  ;ldy $9115     ; the reference timer on the screen
  ;sty $1e01
  cmp #8        ; are we more than 7 cycles ahead of time?
  bcc @l0 
  pha           ; yes, spend 8 extra cycles
  pla
  and #7        ; and reset the high bit
@l0:
  cmp #4
  bcc @l1 
  bit $24       ; waste 4 cycles
  and #3
@l1:
  cmp #2        ; spend the rest of the cycles
  bcs *+2
  bcs *+2
  lsr
  bcs *+2       ; now it has taken 82 cycles from the beginning of the IRQ

  nop
  ldx #(CYCLES_PER_LINE - 2 - 2 - 6 ) / 5 - 1; 2 cycles
: dex                                     ; 2 cycles
  bne :-                                  ; 3 cycles when taken, 2 cycles at exit
  jsr effect                              ; 6 cycles
  jmp $eabf     ; return to normal IRQ

.endmacro
