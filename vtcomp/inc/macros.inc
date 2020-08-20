; BASIC start macro, which generates a line in BASIC that you can RUN.
.macro basicstart line, start, text
  .word bs_end
        .ifblank text
          .word line
        .else
          .word 1
        .endif
        .byte $9e
        .byte .lobyte(start/1000 .mod 10) + $30
        .byte .lobyte(start/100 .mod 10) + $30
        .byte .lobyte(start/10 .mod 10) + $30
        .byte .lobyte(start/1 .mod 10) + $30
        .ifnblank text
          .byte  $3a         ; colon symbol token
          .byte  $8f         ; REM token
          .byte  " "
          .res  14,$14      ; Backspace characters to make line invisible
          .byte text
        .endif
        .byte 0 
bs_end: .word 0  
.endmacro

; 16 bit macros

; Increments a 16 bit number
;   side effects:
;     - none
;   adressing mode absolute  
.macro inc16 number
        inc number+0
        bne :+
:       inc number+1
.endmacro

; Decrements a 16 bit number
;   side effects:
;     - none
;   adressing mode absolute  
.macro dec16 number
        lda number+0 
        bne :+
        dec number+1
:       dec number+0
.endmacro

; Unsigned 16 bit compare
;   side effects:
;     - trashes a
;   adressing mode absolute
;   carry contains the result
.macro cmp16 number1, number2
        lda number1+0
        cmp number2+0
        lda number1+1
        sbc number2+1
.endmacro  

; Unsigned 16 bit immediate compare
;   side effects:
;     - trashes a
.macro cpi16 number, address
        lda #<number
        cmp address+0
        bne :+
        lda #>number
        cmp address+1
:        
.endmacro 

; Store a 16 bit number
;   side effects:
;     - trashes a
.macro sti16 number, address
        lda #<(number)
        sta address+0
        lda #>(number)
        sta address+1
.endmacro  

; sub 8 bit immediate as 16 bit
.macro sub16 number, address
        sec
        lda address+0
        sbc #number
        sta address
        lda address+1
        sbc #0
        sta address+1
.endmacro  

; stack tools

; save cpu, a, x, y to stack
.macro pushall
        php
        pha
        txa
        pha
        tya
        pha
.endmacro  

; load cpu, a, x, y from stack
.macro pullall
        pla
        tay
        pla
        tax
        pla
        plp
.endmacro  

; swap x and y, using a temp memory location
; define a temp: .byte 0 in you VDATA
.macro swapxy
        stx temp+0
        sty temp+1
        ldx temp+1
        ldy temp+0
.endmacro  
