; ========================================================================================
; | Modulname:	main.s                                   | Prozessor:  STM32G474         |
; |--------------------------------------------------------------------------------------|
; | Ersteller: Seyedmasih Tabaei INF4/Platz 7| Datum:  24.11.2022          |
; |--------------------------------------------------------------------------------------|
; | Version:	V1.0 | Projekt:  Lauflicht / Blinkerfunktion| Assembler:  ARM-ASM        |
; |--------------------------------------------------------------------------------------|
; | Aufgabe:     Lauflicht / Blinkerfunktion                                             |
; |                                                                                      |
; |                                                                                      |
; |--------------------------------------------------------------------------------------|
; | Bemerkungen:                                                                         |
; |              - Bei Implementierung wurde versucht, auf AAPCS für Regulierung der	 |
; |                Aufrufkonventionen zu achten.		             					 |
; |				  																		 |
; |--------------------------------------------------------------------------------------|
; | Aenderungen:                                                                         |
; |     24.11.2022		Seyedmasih Tabaei		Final Version                |
; |                                                                                      |
; ========================================================================================

; ------------------------------- includierte Dateien ------------------------------------
    INCLUDE STM32G4xx_REG_ASM.inc

; ------------------------------- exportierte Variablen ------------------------------------


; ------------------------------- importierte Variablen ------------------------------------		
		

; ------------------------------- exportierte Funktionen -----------------------------------		
	EXPORT  main

			
; ------------------------------- importierte Funktionen -----------------------------------


; ------------------------------- symbolische Konstanten ------------------------------------


; ------------------------------ Datensection / Variablen -----------------------------------


; ------------------------------- Codesection / Programm ------------------------------------
	AREA	main_s,code
	


			
; -----------------------------------  Einsprungpunkt - --------------------------------------


	; Anfang der get_state - Prozedur 
	; Diese Prozedur wird zum Abfragen des aktuellen Zustands des GPIOC_IDR verwendet.
	; R0: Der verwendete Register für den Rückgabewert (Zustand des GPIOC_IDR)
get_state PROC
	LDR R0, =GPIOC_IDR
	LDR R1, [R0]
	; Bit-Filterung (Filterung der für uns relevanten Bits)
	LDR R2, =0x00000003
	AND R0, R1, R2	
	
	BX LR
	; Ende der get-state - Prozedur
	ENDP

	; Anfang der delay - Prozedur
	; Diese Prozedur wird zur Realisierung einer Warteschleife verwendet.
	; R3: Der verwendete Register für den Eingabeparameter (Zeit in Milisekunden)
delay PROC
	PUSH {R4, LR} ; 3 Takten
	MOV R4, #5323 ; 1 Takt
	MUL R4, R4, R3 ; 1 Takt

delay_loop
	SUBS R4, R4, #1 ; 1 Takt
	BNE delay_loop ; 2 Takten mit NOP
	NOP
	
	POP {R4, PC} ; 3 Takten
	; Ende der delay - Prozedur
	ENDP
		
	; Anfang der setup - Prozedur
	; Diese Prodezur wird nur einmal am Anfang ausgeführt und wird für Initialisierungen verwendet.
setup PROC
	; Aktivierung der Clocks für Ports A und C 
	LDR R0, =RCC_AHB2ENR
	MOV R1, #5
	STR R1, [R0]
   
	; Setzen der Pins 0 .. 7 von Port A als Ausgang
	LDR R0, =GPIOA_MODER
	LDR R1, [R0]
	LDR R2, =0xFFFF0000
	AND R1, R1, R2
	LDR R2, =0x00005555
	ORR R1, R1, R2
	STR R1, [R0]
	
	; Setzen der Pins 0 .. 1 von Port C als Eingang
	LDR R0, =GPIOC_MODER
	LDR R1, [R0]
	LDR R2, =0xFFFFFFF0
	AND R1, R1, R2
	STR R1, [R0]	
	
	; Laden der Adresse von GPIOA_ODR in R0
	LDR R0, =GPIOA_ODR
	MOV R2, #0x03
	
	BX LR
	; Ende der setup - Prozedur
	ENDP

	
	; Anfang der update - Prozedur 
	; Diese Prodezur enthält eine Schleife, die das Programm am Laufen hält.
	; R2: Der verwendete Register für den echten (aktuellen) Zustand der Taster
	; R5: Der verwendete Register für den neuen (möglicherweise nicht richtigen) Zustand der Taster
	; R6: Der verwendete Register zum temporären Speichern des Werts von R5, damit ein Vergleich möglich ist
update PROC
	PUSH {LR} ; Speichern den Link-Register (Dieser Register enthält die Rücksprungsadresse)
loop
	; Abfragen des aktuellen Zustands des GPIOC_Registers
	PUSH {R0, R1, R2}
	BL get_state
	MOV R5, R0
	POP {R0, R1, R2}
	; Überprüfen, ob überhaupt Taster gedrückt wurden
	CMP R5, #0x03
	BEQ further_check
	; Überprüfen, ob der vorherige Zustand sich geändert hat
	CMP R5, R2
	BEQ continue
	; Entscheiden, ob wir weitermachen oder unterbrechen müssen (Teil der einfachen Tasterentprellung)
	CMP R5, R6
	BEQ new_start
	B new_start_ensure
	; Überprüfen, ob Taster wirklich nicht gedrückt wurden oder nur losgelassen wurden
further_check
	CMP R5, R2
	BEQ loop
	B continue
	; Starten der gewünschten Funktion (1. Linksblinker, 2. Rechtsblinker, 3. Warnblinkerfunktion)
new_start
	MOV R2, R5 ; Aktualisiern des aktuellen Zustands
	MOV R1, #0
	MOV R4, #5 ; Setzen des Sequenz-Zählregisters
	B continue
	; Überprüfen vor dem Starten, ob wirklich eine Änderung vorliegt (Teil der einfahcen Tasterentprellung)
new_start_ensure
	MOV R3, #5
	CMP R2, #0x00
	BNE start_ensure_delay
	; Übrprüfen, ob beide Taster gedrückt sind (dann 5 ms mehr warten)
	ADD R3, R3, #5
start_ensure_delay	
	BL delay
	MOV R6, R5
	B loop
	; Fortsetzng der Sequenz
continue
	; Verzögerung für 100 ms, bevor die nächste LED(s) eingeschaltet wird (werden)
	MOV R3, #100
	BL delay
	STR R1, [R0]
	CMP R1, #0xFF
	BNE turn_next_led_on
	
	; Verzögerung für 200 ms, bevor alle LEDs ausgehen
	; Da 200 ms relativ lang ist und ein Ereignis in dieser Zeit ausgelöst werden könnte,
	; überprüfen wir hier mehrmals (jede 20 ms), ob eine Änderung vorliegt.
	MOV R7, #5
end_delay_loop
	PUSH {R0, R1, R2}
	BL get_state
	MOV R5, R0
	POP {R0, R1, R2}
	CMP R5, #0x03
	BEQ end_delay_loop_continue
	CMP R5, R2
	BNE new_start_ensure
end_delay_loop_continue
	MOV R3, #40
	BL delay	
	SUBS R7, R7, #1
	CMP R7, #0
	BNE end_delay_loop
	MOV R1, #0
	STR R1, [R0]
	
	; Überprüfen, ob die Sequenz 5 mal wiederholt wurde
	SUBS R4, R4, #1
	BNE loop
	MOV R1, #1
	MOV R2, #0x03
	B loop
	; Einschalten der nächsten LED(s) und Überprüfen, welcher Blinkvorgang zu starten ist
turn_next_led_on
	CMP R2, #0x00
	BEQ flasher
	CMP R2, #0x01
	BEQ right_indicator
	B left_indicator
	; Starten der Warnblinkerfunktion (Label, kein UP)
flasher
	LDR R1, [R0]
	LDR R6, =0xF0
	AND R3, R1, R6
	LSL R3, R3, #1
	LDR R6, =0x0F
	AND R7, R1, R6
	LSR R7, R7, #1
	ORR R3, R3, R7
	LDR R7, = 0x18
	ORR R1, R3, R7
	B loop
	; Starten der Rechtblinkerfunktion (Label, kein UP)
right_indicator	
	LSR R1, R1, #1
	ADD R1, R1, #0x80
	B loop
	; Starten der Linkblinkerfunktion (Label, kein UP)
left_indicator
	LSL R1, R1, #1
	ADD R1, R1, #1
	B loop
	
	POP {PC}
	; Ende der update - Prozedur
	ENDP

	; Anfang der main - Prozedur (Einstiegspunkt)
main PROC
	BL setup
	BL update
	; Ende der main - Prozedudr
	ENDP
	; Ende des Programms
	END
		