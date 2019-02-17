;
;	**************************************
;	*  PIEBUG			  VERSION 1.0	 *
;	*  PAIA INTERACTIVE EDITOR-DEBUGGER  *
;	*  WRITTEN BY ROGER WALTON			 *
;	*  COPYRIGHT 1977 BY PAIA			 *
;	*  ELECTRONICS, INC.				 *
;	**************************************
;
;
;
.ORG $0F00
;
KEY		=$0800			;BASE ADDR OF KEY PORTS
TEMP	=$EE			;TEMPORARY STORAGE
LASTKE	=$F8			;PREVIOUS KEY DECODED
BUFFER	=$F0			;KEY ENTRY BUFFER
DISP	=$0820			;LED DISPLAY
MSTACK	=$ED			;MONITOR STACK POINTER
PNTER	=$F6			;16 BIT ADDR POINTER
TAPE1	=$0E00			;START OF TAPE SYSTEM
CASS	=$0900			;CASSETTE PORT
;
ACC		=$F9			;REG STORAGE
YREG	=$FA
XREG	=$FB
PC		=$FC
STACKP	=$FE
PREG	=$FF			;REG STORAGE
;
;	DECODE KEY SUBROUTINE
;	THIS SUB SCANS THE ENTIRE KEYBAORD AND
;	RETURNS WITH DECODED KEY VALUE IN A AND Y.
;	CARRY IS CLEAR IF NEW KEY. X IS
;	DESTROYED. $18 IS "NO KEY" CODE.
;
DECODE  ldy #0			;CLEAR RESULT REG
        ldx #$21		;X IS PORT REG
LOOP	lda #1
        sta TEMP		;SET UP MASK
NEXT    lda KEY,x		;READ CURRENT KEY PORT
        and TEMP		;USE MASK TO SELECT KEY
        bne RESULT		;BRANCH IF KEY DOWN
        iny				;SET RESULT TO NEXT KEY
RESULT  asl TEMP		;SHIFT MASK TO NEXT KEY
        bcc NEXT		;BR IF MORE KEYS ON PORT
        txa
        asl a			;SELECT NEXT PORT
        tax
        bcc LOOP		;BRANCH IF NOT LAST PORT
        cpy LASTKE		;CLEAR CARRY IF NEW KEY
        sty LASTKE		;UPDATE LASTKEY
        tya				;MOVE KEY TO ACC
        rts				;RETURN
;
;
;
;	GETKEY SUBROUTINE
;	THIS SUB WAITS FOR A NEW KEY TO BE
;	TOUCHED AND THEN RETURNS WITH THE
;	KEY VALUE IN THE ACCUMULATOR.   
;	X AND Y ARE CLEARED.
;
;	BEEP SUBROUTINE (EMBEDDED IN GET KEY SUB)
;	THIS SUB PRODUCES A SHORT BEEP AT
;	THE CASSETTE PORT. CARRY MUST BE
;	CLEAR BEFORE ENTERING. X AND Y
;	ARE CLEAR.
;
GETKEY	jsr DECODE		;GET A KEY
BEEP	ldx #20			;ENTER HERE FOR BEEP SUB
NXTX	ldy #$3f
DELAY	bcs DLY			;SKIP TONE IF CARRY SET
        sty CASS		;GENERATE TONE
DLY		dey				;DELAY
        bne DELAY
        dex				;DELAY SOME MORE
        bne NXTX		;NEXT X
        bcs GETKEY		;BRANCH IF NOT NEW KEY
        rts				;RETURN
;
;
;
;
;	SHIFT BUFFER SUBROUTINE
;	THIS SUB SHIFTS THE LOWER 4 BITS OF
;	THE ACCUMLATOR INTO THE LEAST
;	SIGNIFICANT POSITION OF BUFFER. THE
;	ENTIRE BUFFER IS SHIFTED 4 TIMES AND
;	THE MOST SIGNIFICANT 4 BITS ARE LOST.
;	X AND Y ARE CLEARED. IF ON RETURN,
;	A SINGLE "ROL A" IS PERFORMED,
;	THE LOWER 4 BITS OF THE ACCUMULATOR
;	WILL CONTAIN THE 4 BITS THAT WERE
;	SHIFTED OUT OF BUFFER
;
SHIFT   asl a			;SHIFT KEY INFORMATION
        asl a			;TO UPPER 4 BITS OF ACC
        asl a
        asl a
        ldy #4
ROTATE  rol a			;SHIFT BIT TO CARRY
        ldx #$fa		;WRAP AROUND TO $FD
ROTNXT  rol BUFFER+6,x	;CARRY TO BUFFER TO CARRY
        inx				;AND SO ON
        bne ROTNXT		;UNTIL END OF BUFFER
        dey				;DONE 4 BITS?
        bne ROTATE		;BRANCH IF NOT
        rts				;RETURN
;
;	RESET ENTRY POINT
;
RESET   lda #0
        sta $08e0		;CLEAR DISPLAY AND PORTS
        beq COMAND		;BRANCH ALWAYS
;
;
;
SHFTD   jsr SHIFT		;SHIFT KEY INTO BUFFER
DSPBUF  lda BUFFER		;GET BUFFER
SEE     sta DISP		;UPDATE DISPLAY
;
COMAND  ldx MSTACK
        txs				;SET MONITOR STACK
        jsr GETKEY		;WAIT FOR KEY
        cmp #$10		;IS IT CONTROL KEY
        bcc SHFTD		;BRANCH IF NOT
        tay				;CONTROL KEY INTO Y
        ldx TABLE-16,y	;GET COMMAND ADDR LOW
        stx TEMP		;SAVE IT
        ldx #$ff		;GET COMMAND ADDR HIGH
        stx TEMP+1		;ASSEMBLE COMMAND ADDR
        inx				;CLR X
        jmp (TEMP)		;EXECUTE COMMAND
;
;
        
PHIGH   clc
        lda PNTER		;MOVE POINTER TO BUFFER
        sta BUFFER
        lda PNTER+1
        sta BUFFER+1
        bcs DSPBUF		;BRANCH IF POINTER LOW
        bcc SEE			;BRANCH IF POINTER HIGH
;
;
DISPLA  lda BUFFER		;MOVE BUFFER TO POINTER
        sta PNTER
        lda BUFFER+1
        sta PNTER+1
        bcs LOAD		;BRANCH ALWAYS
;
;
BACKSP  lda PNTER		;DEC 16 BIT POINTER
        bne SKIP		;BRANCH IF NO BORROW
        dec PNTER+1
SKIP    dec PNTER
        bcs LOAD		;BRANCH ALWAYS
;
;
ENTER	lda BUFFER		;GET BYTE IN BUFFER
        sta (PNTER,x)	;STORE IT IN ACTIVE CELL
        inc PNTER		;INC 16 BIT POINTER
        bne LOAD		;BRANCH IF NO CARRY
        inc PNTER+1
LOAD    lda (PNTER,x)	;GET BYTE IN ACTIVE CELL
STABUF  sta BUFFER		;STORE IT IN BUFFER
        bcs DSPBUF		;BRANCH ALWAYS
;
;
RELADR  cld
        clc				;THIS ADDS 1 TO POINTER
        lda BUFFER		;GET BUFFER LOW
        sbc PNTER		;SUBTRACT POINTER LOW + 1
        sta BUFFER		;SAVE RESULTS
        lda BUFFER+1	;GET BUFFER HIGH
        sbc PNTER+1		;SUBTRACT POINTER HIGH
        tay				;SAVE RESULTS IN Y
        lda BUFFER		;GET RESULTS LOW
        bcs POS			;BR IF TOTAL RESULT POS
        bpl BAD			;BR IF RESULT LOW POS
        iny				;IN RESULT HIGH
CHK     tya				;CHECK RESULT HIGH
        bne BAD			;BR IF NOT ZERO
        beq DSPBUF		;BR ALWAYS, DISP REL ADDR
POS     bmi BAD			;BR IF RESULT LOW NEG
        bpl CHK			;BR ALWAYS
BAD     txa				;CLEAR ACC
        sec
        bcs STABUF		;BRANCH ALWAYS
;
;
        nop
;
;
;
;	BREAK ROUTINE ENTRY POINT
;
BREAK   sta ACC			;SAVE ACCUMULATOR
        sty YREG		;SAVE Y
        stx XREG		;SAVE X
        pla				;GET STATUS REG
        sta PREG		;SAVE IT
        pla				;GET PC LOW
        cld
        sec
        sbc #2			;CORRECT PC LOW
        sta PC			;SAVE IT
        pla				;GET PC HIGH
        sbc #0			;SUBTRACT CARRY
        sta PC+1		;SAVE IT
        tsx				;GET USER STACK POINTER
        stx STACKP		;SAVE IT
        lda #$bb		;BREAK INDICATION
        bcs STABUF		;BRANCH ALWAYS
;
;
RUN     ldx STACKP		;GET USER STAC POINTER
        txs				;INIT STACK
        lda BUFFER+1	;GET PC HIGH
        pha				;PUT IT ON STACK
        lda BUFFER		;GET PC LOW
        pha				;PUT IT ON STACK
        lda PREG		;GET STATUS REG
        pha				;PUT IT ON STACK
        ldx XREG		;RESTORE X
        ldy YREG		;RESTORE Y
        lda ACC			;RESTORE ACCUMULATOR
        rti				;RESTORE PC & STATUS REG
;						FROM STACK AND EXECUTE
;						USER'S PROGRAM
;
;
TAPE    jmp TAPE1		;EXECUTE TAPE OPTION
;
;
;				COMMAND ADDRESS TABLE
;				STORES LOW BYTE ONLY OF ENTRY
;				ADDRESS FOR EACH COMMAND
;
;RUN, DISPLA, BACKSP, ENTER, PHIGH, PLOW, TAPE, RELADR
TABLE   dc 7a 84 8e 6d 6e ef 9e 
03 00 					;NMI VECTOT
46 0f 					;RESET VECTOR
00 00					;IRQ VECTOR