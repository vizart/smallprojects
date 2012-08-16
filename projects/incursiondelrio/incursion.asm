    ; i8080 assembler code

    .binfile asaltodelrio.rom

    .nodump

stacksave	equ $20

	 
	.org $100

clrscr:
    di
	lxi h, $8000
clearscreen:
	xra a
	;out $10
	mov m, a
	inx h
	ora h
	jnz clearscreen

	; init stack pointer
	lxi sp, $100

	; enable interrupts

	; write ret to rst 7 vector	
	mvi a, $c9
	sta $38

	; initial stuff
	ei
	hlt
	call setpalette
	call showlayers

jamas:
	mvi a, 4
	out 2
	ei
	hlt
	xra a
	out 2

	; scroll
	mvi a, 88h
	out 0
	lda frame_scroll
	out 3

	; keep interrupts enabled to make errors obvious
	ei

	; prepare animated sprites
	call foe_animate

	lxi h, foe_1
	call foe_in_hl
	lxi h, foe_2
	call foe_in_hl
	lxi h, foe_3
	call foe_in_hl
	lxi h, foe_4
	call foe_in_hl
	lxi h, foe_5
	call foe_in_hl
	lxi h, foe_6
	call foe_in_hl
	lxi h, foe_7
	call foe_in_hl
	lxi h, foe_8
	call foe_in_hl

	call clearblinds
	call drawblinds_bottom

	lxi h, frame_number
	inr m

	lxi h, frame_scroll
	inr m

	;di
	;jmp .

	jmp jamas

frame_number:
	db 0
frame_scroll:
	db $ff

copyfoe_y:
	xchg					; 8
	lxi h, 0 				; 12
	dad sp 					; 12
	shld sprites_scratch 	; 16
	xchg					; 8
	sphl					; 8  = 64

	pop h       			; 12
	shld foeBlock 			; 16
	pop h       			; 12
	shld foeBlock + 2 		; 16
	pop h       			; 12
	shld foeBlock + 4 		; 16
	pop h       			; 12
	shld foeBlock + 6 		; 16  = 68

	lhld sprites_scratch  	; 16
	sphl				  	; 8  = 24  --> 84 + 68 + 24 = total 176
	ret

copyback_y:
	xchg		
	lxi h, 0 	
	dad sp 		
	shld sprites_scratch 
	xchg		
	lxi d, 8
	dad d
	sphl		

	lhld foeBlock + 6
	push h
	lhld foeBlock + 4
	push h
	lhld foeBlock + 2
	push h
	lhld foeBlock
	push h           

	lhld sprites_scratch 
	sphl				 
	ret


setpalette:
	lxi h, palette_data+15
	mvi c, 16
palette_loop:
	mov a, c
	dcr a
	out $2
	mov a, m
	out $c
	dcr c
	dcx h
	jnz palette_loop
	ret

;---
drawblinds_bottom:
	lxi h, $e000 + 70
	mvi b, $ff
	mvi c, 32
	jmp clearblinds_entry2

clearblinds:
	lxi h, $e2ff-16
	mvi b, 0
	mvi c, 28
clearblinds_entry2:
	lda frame_scroll
	add l
	mov l, a

	lxi d, 256+1
clearblinds_L1:
	mov m, b ; 8
	dcx h    ; 8
	mov m, b ; 8
	dad d    ; 12

	dcr c 	; 8
	jnz clearblinds_L1 ; 12   (8+12+8+12)*32 = 1280, (8+12+8+12+8+8)*32=1792

	ret	

	

FOEID_NONE 		equ 0
FOEID_SHIP 		equ 1
FOEID_COPTER 	equ 2
FOEID_RCOPTER	equ 3
FOEID_JET 		equ 4

	;; foe class
foeColumn		equ 0 			; X column
foeIndex		equ 1 			; X offset 0..7
foeDirection	equ 2 			; 1 = LTR, -1 RTL, 0 = not moving
foeBounce		equ 3 			; bounce flag
foeY			equ 4			; Y position of sprite start
foeLeftStop		equ 5			; column # of left limit
foeRightStop	equ 6 			; column # of right limit
foeId 			equ 7 			; id: 0 = none, 1 = ship, 2 = copter
foeSizeOf 		equ 8

	;; foe 0 descriptor
foeBlock:
	db 5,0,1,0,$10,3,15
	db 0 						; id
foeBlock_LTR:	
	dw 0 						; dispatch to sprite LTR 
foeBlock_RTL:
	dw 0 						; dispatch to sprite RTL

foePropeller_LTR:
	dw 0
foePropeller_RTL:
	dw 0

foe_1:
	db 5,0,1,0,$10,3,15
	db FOEID_SHIP
foe_2:
	db 5,0,1,0,$30,5,7
	db FOEID_COPTER
foe_3:
	db 5,0,1,0,$50,3,25
	db FOEID_SHIP
foe_4:
	db 7,0,1,0,$70,7,10
	db FOEID_RCOPTER
foe_5:
	db 5,0,1,0,$90,2,8
	db FOEID_SHIP
foe_6:
	db 5,0,4,0,$b0,255,30
	db FOEID_JET
foe_7:
	db 5,0,1,0,$d0,3,25
	db FOEID_SHIP
foe_8:
	db 9,0,1,0,$f0,8,23
	db FOEID_COPTER

	;; animate sprites
	;; should be called once per frame, before the first sprite
foe_animate:
	; animate the propeller
	lda frame_number
	ani $2
	jz  foe_byId_propA
	lxi h, propellerB_ltr_dispatch
	lxi d, propellerB_rtl_dispatch
	jmp foe_byId_propC
foe_byId_propA:
	lxi h, propellerA_ltr_dispatch
	lxi d, propellerA_rtl_dispatch
foe_byId_propC:
	shld foePropeller_LTR
	xchg
	shld foePropeller_RTL
	ret

foe_in_hl:
	push h
	call copyfoe_y
	call foe_byId
	pop h
	call copyback_y
	ret

foe_byId:
	lda foeBlock + foeId
	; if (foe.Id == 0) return;
	ora a
	rz		

	; prepare dispatches
	dcr a
	jz  foe_byId_ship		; 1 == ship
	dcr a
	jz  foe_byId_copter		; 2 == copter
	dcr a
	jz  foe_byId_rcopter	; 3 == redcopter
	dcr a
	jz 	foe_byId_jet 		; 4 == jet
	; default: return  
	ret
foe_byId_ship:
	lxi h, ship_ltr_dispatch
	shld foeBlock_LTR
	lxi h, ship_rtl_dispatch
	shld foeBlock_RTL
	jmp foe_frame

foe_byId_jet:
	lxi h, jet_ltr_dispatch
	shld foeBlock_LTR
	lxi h, jet_rtl_dispatch
	shld foeBlock_RTL
	jmp foe_frame

foe_byId_rcopter:
	; draw the copter body
	lxi h, redcopter_ltr_dispatch
	shld foeBlock_LTR
	lxi h, redcopter_rtl_dispatch
	shld foeBlock_RTL
	call foe_frame
	jmp foe_byId_copterpropeller
foe_byId_copter:
	; draw the copter body
	lxi h, copter_ltr_dispatch
	shld foeBlock_LTR
	lxi h, copter_rtl_dispatch
	shld foeBlock_RTL
	call foe_frame
foe_byId_copterpropeller:
	; animate the propeller
	lhld foePropeller_LTR
	shld foeBlock_LTR
	lhld foePropeller_RTL
	shld foeBlock_RTL

	; offset propeller Y position
	lxi h, foeBlock + foeY
	mov a, m
	push psw
	adi 4
	mov m, a
	push h
	; draw propeller
	call foe_paint_preload
	; restore copter Y position in the foe block
	pop h
	pop psw
	mov m, a
	ret

foe_frame:
foe_Move:
	; load Column to e
	lda foeBlock + foeColumn
	mov e, a 	

	; index = index + direction
	lda foeBlock + foeDirection
	mov b, a
	lda foeBlock + foeIndex
	add b
	; if (Index == -1  
	cpi $ff 
	jz foe_move_L4
	cpi $fe
	jz foe_move_L4
	;     || Index == 8)
	cpi $8
	jz foe_move_L4
	jmp foe_move_L1
foe_move_L4:
	; {
	; Index = Index % 8
	ani $7
	; save Index, update c
	sta foeBlock + foeIndex
	mov c, a
	; Column = Column + sgn(Direction)
	; column in e

	mov a, b
	; find direction sign
	ral
	mvi a, 1
	jnc foe_move_diradd
	mvi a, $ff
foe_move_diradd:
	add e

	sta foeBlock + foeColumn
	mov e, a
	; }
	jmp foe_move_CheckBounce
foe_move_L1:
	; save Index, update c
	sta foeBlock + foeIndex
	mov c, a
	; not at column boundary -> skip bounce check
	jmp foe_move_nobounce
foe_move_CheckBounce:
	; check for bounce
	; we are here if Index == 0 || Index == 7
	; e = Column
	lda foeBlock + foeRightStop
	cmp e
	jz foe_move_yes_bounce
	lda foeBlock + foeLeftStop
	cmp e
	jnz foe_move_nobounce
	; yes, bounce
foe_move_yes_bounce:
	; Bounce = 1
	mvi a, 1
	sta foeBlock + foeBounce
	; Direction = -Direction
	mov a, b
	cma 
	inr a
	sta foeBlock + foeDirection
	; do the Move() once again
	jmp foe_Move

	;; additional entry point for sprites with precalculated position
	;; used for propellers
foe_paint_preload:
	lda foeBlock + foeColumn
	mov e, a
	lda foeBlock + foeIndex
	mov c, a
	lda foeBlock + foeDirection
	mov b, a

foe_move_nobounce: 
	;; foeBlock movement calculation ends here

foe_paint:
	;; paint foe
	; e contains column
	mov a, e

	; de = base addr ($8000 + foe.Y)
	adi $80
	mov d, a
	lda foeBlock + foeY
	mov e, a

	; de == base address
	; c == index
	; b == Direction
	mov a, b

	; b = Bounce, Bounce = 0
	lxi h, foeBlock + foeBounce
	mov b, m
	mvi m, 0

	ora a
	jm  sprite_rtl
	jmp sprite_ltr

sprites_scratch:	dw 0

	;; c = offset
	;; de = column base address
	;; b = bounce
sprite_ltr:
	; load dispatch table	
	lhld foeBlock_LTR

	; if (Index != 0) -> regular, no pre-wipe
	mov a, c
	ora a
	jnz sprite_ltr_regular

	; if (Bounce) -> regular, no pre-wipe 
	mov a, b 	
	ora a
	jnz  sprite_ltr_regular

	; Index == 0, no bounce -> wipe previous column
	dcr d
	; jump to _ltr_inf [dispatch - 2]

	jmp sprite_ltr_rtl_dispatchjump

	;; Draw ship without prepending column for wiping
sprite_ltr_regular:
	; index 0..7 -> 1..8
	inr c
	;lxi h, sprite_ltr_dispatch+2
	jmp sprite_ltr_rtl_dispatchjump

	;; c = offset
	;; de = column base address
	;; b = bounce
sprite_rtl:

sprite_rtl_regular:
	lhld foeBlock_RTL

sprite_ltr_rtl_dispatchjump:
	mvi b, 0
	mov a, c
	rlc
	mov c, a
	dad b 		
	;jmp [h]
	shld .+4
	lhld 0000	
	pchl

    .include ship.inc

c_black		equ $00
c_blue		equ $c1
c_green 	equ $73 ; 01 110 011
c_yellow 	equ $bf ; 
c_magenta 	equ $8d ;
c_white		equ $f6
c_grey		equ $09 ; 00 010 010
c_cyan		equ $f4	; 10 011 001
c_dkblue	equ $81	; 10 010 001

palette_data:
	db c_blue,   	c_black,  c_white,  	c_black
	db c_magenta, 	c_black,  c_grey,		c_black
	db c_green, 	c_black,  c_cyan,  		c_black
	db c_yellow,    c_black,  c_dkblue, 	c_black


	;; Depuración y basura

	; pintar los colores
showlayers:
	lxi h, $ffff
	; 1 0 0 0
	shld $81fe 

	; 0 1 0 0 
	shld $a2fe

	; 1 1 0 0
	shld $83fe
	shld $a3fe

	; 0 0 1 0
	shld $c4fe

	; 1 0 1 0
	shld $85fe	
	shld $c5fe

	; 0 1 1 0
	shld $a6fe	
	shld $c6fe

	; 1 1 1 0
	shld $87fe	
	shld $a7fe
	shld $c7fe

	; x x x 1
	shld $e8fe	

	; test bounds
	shld $8306
	shld $8308
	shld $830a
	shld $830c
	shld $830e
	shld $8310
	shld $8312

	shld $9306
	shld $9308
	shld $930a
	shld $930c
	shld $930e
	shld $9310
	shld $9312

	; time marks
	lxi h, $c0c0
	shld $e000
	shld $e010
	shld $e020
	shld $e030
	shld $e040
	shld $e050
	shld $e060
	shld $e070
	shld $e080
	shld $e090
	shld $e0a0
	shld $e0b0
	shld $e0c0
	shld $e0d0
	shld $e0e0
	shld $e0f0
	shld $e0fe
	ret

