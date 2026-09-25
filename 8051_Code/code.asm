;=========================================================
; AT89C51 Motor Controller Core (MIDE-51 / ASEM-51 safe)
; LCD: 8-bit, Data=P2, RS=P0.0, E=P0.2, RW=GND
; Keypad calculator 4x4:
;   Rows A-D -> P1.0..P1.3
;   Cols 1-4 -> P1.4..P1.7
; Motor driver L293D:
;   IN1=P3.0, IN2=P3.1, EN1(PWM)=P3.7
;
; Keys:
;   '+'  -> CW
;   '-'  -> CCW
;   'C'  -> clear digit entry
;   '='  -> apply speed (2 digits)
;   0..9 -> digits
;=========================================================

LCD_RS      BIT P0.0
LCD_E       BIT P0.2

;---------------- RAM ----------------
DUTY        DATA 30H     ; 0..99
DIR         DATA 31H     ; 0=STOP,1=CW,2=CCW
KEYBUF      DATA 32H     ; last read key
D1_ASC      DATA 33H     ; first digit ASCII or 0FFh
D2_ASC      DATA 34H     ; second digit ASCII or 0FFh

ORG 0000H
LJMP START

;=========================================================
START:
    MOV SP,#6FH
    MOV P1,#0FFH
    MOV P0,#0FFH
    MOV P2,#00H

    CLR P3.0
    CLR P3.1
    CLR P3.7

    MOV DUTY,#50
    MOV DIR,#00
    MOV KEYBUF,#00
    MOV D1_ASC,#0FFH
    MOV D2_ASC,#0FFH

    ACALL LCD_PWRDELAY
    ACALL LCD_INIT
    ACALL LCD_CLEAR
    ACALL SHOW_STATUS

MAIN_LOOP:
    ; ---- Read key ----
    ACALL GETKEY          ; A=ASCII or 00
    JZ  DO_PWM            ; no key

    MOV KEYBUF,A          ; save key safely

    ; ---- Handle direction ----
    MOV A,KEYBUF
    CJNE A,#'+',CHK_MINUS
    ACALL SET_CW
    ACALL SHOW_STATUS
    LJMP WAIT_RELEASE

CHK_MINUS:
    MOV A,KEYBUF
    CJNE A,#'-',CHK_CLR
    ACALL SET_CCW
    ACALL SHOW_STATUS
    LJMP WAIT_RELEASE

CHK_CLR:
    MOV A,KEYBUF
    CJNE A,#'C',CHK_EQ
    MOV D1_ASC,#0FFH
    MOV D2_ASC,#0FFH
    ACALL SHOW_STATUS
    LJMP WAIT_RELEASE

CHK_EQ:
    MOV A,KEYBUF
    CJNE A,#'=',CHK_DIGIT
    ACALL APPLY_SPEED
    ACALL SHOW_STATUS
    LJMP WAIT_RELEASE

CHK_DIGIT:
    ; accept '0'..'9'
    MOV A,KEYBUF
    CLR C
    SUBB A,#'0'
    JC  WAIT_RELEASE

    MOV A,KEYBUF
    CLR C
    SUBB A,#'9'+1
    JNC WAIT_RELEASE

    ; store digit 1 then digit 2
    MOV A,D1_ASC
    CJNE A,#0FFH,STORE_D2
    MOV A,KEYBUF
    MOV D1_ASC,A
    ACALL SHOW_STATUS
    LJMP WAIT_RELEASE

STORE_D2:
    MOV A,D2_ASC
    CJNE A,#0FFH,WAIT_RELEASE
    MOV A,KEYBUF
    MOV D2_ASC,A
    ACALL SHOW_STATUS
    LJMP WAIT_RELEASE

WAIT_RELEASE:
    ; wait until key released
WR1:
    ACALL GETKEY
    JNZ WR1
    LJMP DO_PWM

;=========================================================
DO_PWM:
    ACALL PWM_ONE_PERIOD
    LJMP MAIN_LOOP

;=========================================================
; Direction set
;=========================================================
SET_CW:
    MOV DIR,#01
    SETB P3.0
    CLR  P3.1
    RET

SET_CCW:
    MOV DIR,#02
    CLR  P3.0
    SETB P3.1
    RET

;=========================================================
; Apply speed from 2 digits if present
; DUTY = (d1*10 + d2)
;=========================================================
APPLY_SPEED:
    MOV A,D1_ASC
    CJNE A,#0FFH,AS1
    RET
AS1:
    MOV A,D2_ASC
    CJNE A,#0FFH,AS2
    RET
AS2:
    MOV A,D1_ASC
    ANL A,#0FH
    MOV B,#10
    MUL AB               ; A=tens*10
    MOV R4,A

    MOV A,D2_ASC
    ANL A,#0FH
    ADD A,R4             ; 0..99
    MOV DUTY,A

    ; clear input digits after applying
    MOV D1_ASC,#0FFH
    MOV D2_ASC,#0FFH
    RET

;=========================================================
; PWM: 100-step software PWM on P3.7
; If DIR=0 => stop
;=========================================================
PWM_ONE_PERIOD:
    MOV A,DIR
    JNZ PWM_GO
    CLR P3.7
    RET

PWM_GO:
    MOV R6,#100          ; steps
PWM_L:
    ; step = 100 - R6 (0..99)
    MOV A,#100
    CLR C
    SUBB A,R6
    MOV R5,A

    MOV A,R5
    CLR C
    SUBB A,DUTY
    JC  PWM_ON

PWM_OFF:
    CLR P3.7
    ACALL PWM_DELAY
    DJNZ R6,PWM_L
    RET

PWM_ON:
    SETB P3.7
    ACALL PWM_DELAY
    DJNZ R6,PWM_L
    RET

PWM_DELAY:
    MOV R7,#60
PD1:DJNZ R7,PD1
    RET

;=========================================================
; LCD Status:
; Line1: DIR:CW / DIR:CCW / DIR:STOP
; Line2: SPD:xx%  (or shows entered digits if typing)
;=========================================================
SHOW_STATUS:
    ACALL LCD_CLEAR

    MOV DPTR,#MSG_DIR
    ACALL LCD_PUTS

    MOV A,DIR
    CJNE A,#01,SD_CCW
    MOV DPTR,#MSG_CW
    ACALL LCD_PUTS
    SJMP SD_L2
SD_CCW:
    CJNE A,#02,SD_STOP
    MOV DPTR,#MSG_CCW
    ACALL LCD_PUTS
    SJMP SD_L2
SD_STOP:
    MOV DPTR,#MSG_STOP
    ACALL LCD_PUTS

SD_L2:
    ACALL LCD_LINE2
    MOV DPTR,#MSG_SPD
    ACALL LCD_PUTS

    ; If user is entering digits, show them
    MOV A,D1_ASC
    CJNE A,#0FFH,SHOW_D1
    SJMP SHOW_DUTY

SHOW_D1:
    MOV A,D1_ASC
    ACALL LCD_DATA
    MOV A,D2_ASC
    CJNE A,#0FFH,SHOW_D2
    MOV A,#'_'
    ACALL LCD_DATA
    MOV A,#'%'
    ACALL LCD_DATA
    RET

SHOW_D2:
    MOV A,D2_ASC
    ACALL LCD_DATA
    MOV A,#'%'
    ACALL LCD_DATA
    RET

SHOW_DUTY:
    MOV A,DUTY
    MOV B,#10
    DIV AB               ; A=tens, B=ones
    ADD A,#'0'
    ACALL LCD_DATA
    MOV A,B
    ADD A,#'0'
    ACALL LCD_DATA
    MOV A,#'%'
    ACALL LCD_DATA
    RET

;=========================================================
; Keypad: full scan + map (calculator keypad)
; Returns ASCII in A, 00 if none
;=========================================================
GETKEY:
    MOV P1,#0FEH          ; Row A
    ACALL READCOL
    JZ  ROWB
    ACALL MAP_ROWA
    RET

ROWB:
    MOV P1,#0FDH          ; Row B
    ACALL READCOL
    JZ  ROWC
    ACALL MAP_ROWB
    RET

ROWC:
    MOV P1,#0FBH          ; Row C
    ACALL READCOL
    JZ  ROWD
    ACALL MAP_ROWC
    RET

ROWD:
    MOV P1,#0F7H          ; Row D
    ACALL READCOL
    JZ  NONE
    ACALL MAP_ROWD
    RET

NONE:
    MOV A,#00H
    MOV P1,#0FFH
    RET

; A=1..4 column
MAP_ROWA:
    CJNE A,#1,MA2
    MOV A,#'7'
    SJMP MEND
MA2:CJNE A,#2,MA3
    MOV A,#'8'
    SJMP MEND
MA3:CJNE A,#3,MA4
    MOV A,#'9'
    SJMP MEND
MA4:
    MOV A,#'/'
MEND:
    MOV P1,#0FFH
    RET

MAP_ROWB:
    CJNE A,#1,MB2
    MOV A,#'4'
    SJMP MEND2
MB2:CJNE A,#2,MB3
    MOV A,#'5'
    SJMP MEND2
MB3:CJNE A,#3,MB4
    MOV A,#'6'
    SJMP MEND2
MB4:
    MOV A,#'*'
MEND2:
    MOV P1,#0FFH
    RET

MAP_ROWC:
    CJNE A,#1,MC2
    MOV A,#'1'
    SJMP MEND3
MC2:CJNE A,#2,MC3
    MOV A,#'2'
    SJMP MEND3
MC3:CJNE A,#3,MC4
    MOV A,#'3'
    SJMP MEND3
MC4:
    MOV A,#'-'
MEND3:
    MOV P1,#0FFH
    RET

MAP_ROWD:
    CJNE A,#1,MD2
    MOV A,#'C'
    SJMP MEND4
MD2:CJNE A,#2,MD3
    MOV A,#'0'
    SJMP MEND4
MD3:CJNE A,#3,MD4
    MOV A,#'='
    SJMP MEND4
MD4:
    MOV A,#'+'
MEND4:
    MOV P1,#0FFH
    RET

;---------------------------------------------------------
; READCOL: A=1..4 if any column low, else 0
;---------------------------------------------------------
READCOL:
    ACALL DLY_1MS
    JB P1.4,RC2
    MOV A,#01
    RET
RC2:
    JB P1.5,RC3
    MOV A,#02
    RET
RC3:
    JB P1.6,RC4
    MOV A,#03
    RET
RC4:
    JB P1.7,RNONE
    MOV A,#04
    RET
RNONE:
    MOV A,#00
    RET

DLY_1MS:
    MOV R6,#5
DMS1:
    MOV R7,#250
DMS2:DJNZ R7,DMS2
    DJNZ R6,DMS1
    RET

;=========================================================
; LCD routines (8-bit, robust)
;=========================================================
LCD_PWRDELAY:
    ACALL LCD_LONG
    ACALL LCD_LONG
    RET

LCD_INIT:
    MOV A,#038H
    ACALL LCD_CMD
    MOV A,#00CH
    ACALL LCD_CMD
    MOV A,#006H
    ACALL LCD_CMD
    RET

LCD_CLEAR:
    MOV A,#001H
    ACALL LCD_CMD
    ACALL LCD_LONG
    RET

LCD_LINE2:
    MOV A,#0C0H
    ACALL LCD_CMD
    RET

LCD_CMD:
    CLR LCD_RS
    MOV P2,A
    SETB LCD_E
    ACALL LCD_SHORT
    CLR LCD_E
    ACALL LCD_SHORT
    RET

LCD_DATA:
    SETB LCD_RS
    MOV P2,A
    SETB LCD_E
    ACALL LCD_SHORT
    CLR LCD_E
    ACALL LCD_SHORT
    RET

LCD_PUTS:
LP1: CLR A
     MOVC A,@A+DPTR
     JZ  LP2
     ACALL LCD_DATA
     INC DPTR
     SJMP LP1
LP2: RET

LCD_SHORT:
    MOV R7,#80
LS1:DJNZ R7,LS1
    RET

LCD_LONG:
    MOV R6,#200
LL1: MOV R7,#250
LL2: DJNZ R7,LL2
     DJNZ R6,LL1
     RET

;---------------- Strings ----------------
MSG_DIR:  DB 'DIR:',0
MSG_CW:   DB 'CW',0
MSG_CCW:  DB 'CCW',0
MSG_STOP: DB 'STOP',0
MSG_SPD:  DB 'SPD:',0

END