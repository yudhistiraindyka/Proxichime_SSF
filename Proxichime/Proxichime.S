#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main
.equ light_pin, 2 ; PB2 as Light bulb pin
.equ trig_pin, 1 ; PB1 as Trigger pin
.equ echo_pin, 0 ; PB0 as Echo pin

main:
    SBI DDRB, light_pin
    SBI DDRB, trig_pin
    CBI DDRB, echo_pin

main_loop0:
    ; Get the distance measured by the HCSR04 sensor
    RCALL calculate_distance

    ; Control the light based on the distance reading
    RCALL light_logic

    ; Delay to ensure the sensor is ready
    RCALL delay_200ms

    RJMP  main_loop0

;===============================================================

; Get distance measurement using HCSR04 sensor
calculate_distance:
    ; Send 10us high pulse to sensor
    SBI PORTB, 1
    RCALL delay_timer0
    CBI PORTB, 1      

    ; Timer1 normal mode
    LDI R20, 0b00000000
    STS TCCR1A, R20

    ; Rising edge detection & prescaler=1024, noise cancellation ON
    LDI R20, 0b11000101 
    STS TCCR1B, R20     

calculate_distance_loop0:
    ; Loop until rising edge is detected
    IN R21, TIFR1
    SBRS R21, ICF1
    RJMP calculate_distance_loop0

    ; Store count value at rising edge
    LDS R16, ICR1L

    ; Clear flag for falling edge detection
    OUT TIFR1, R21

    ; Set for falling edge detection
    LDI R20, 0b10000101
    STS TCCR1B, R20

calculate_distance_loop1:
    ; Loop until falling edge is detected
    IN R21, TIFR1
    SBRS R21, ICF1
    RJMP calculate_distance_loop1

    ; Store count value at falling edge
    LDS R28, ICR1L

    ; Count diff R22 = R22 - R16
    SUB R28, R16

    ; Clear flag for next sensor reading
    OUT TIFR1, R21

    RET

;===============================================================

; Control the light based on the distance reading
light_logic:
    ; Turn on light when distance measured is < 200cm
    CPI R28, 201
    BRMI turn_on
    
    ; Else, turn off light
    CBI PORTB, 2
    RET

turn_on:
    ; Turn on light
    SBI PORTB, 2

    RET

;===============================================================

; 10us delay via Timer0
delay_timer0:
    ; Initialize timer0 with count=0
    CLR R20
    OUT TCNT0, R20  

    ; OCR0 = 20
    LDI R20, 20
    OUT OCR0A, R20

    ; CTC mode, prescaler 8
    LDI R20, 0b00001010
    OUT TCCR0B, R20

delay_timer0_loop0:
    ; Get TIFR0 byte & check
    IN R20, TIFR0

    ; If OCF0=1, skip next instruction
    SBRS R20, OCF0A

    ; Else, loop back & check OCF0 flag
    RJMP delay_timer0_loop0

    ; Stop timer0
    CLR R20
    OUT TCCR0B, R20

    ; Clear OCF0 flag
    LDI R20, (1<<OCF0A)
    OUT TIFR0, R20

    RET

;===============================================================

; Make a 200ms delay using nested loops
delay_200ms:
    LDI R21, 255
delay_200ms_loop0: 
    LDI R22, 255
delay_200ms_loop1:
    LDI R23, 50
delay_200ms_loop2:
    DEC R23
    BRNE delay_200ms_loop2
    DEC R22
    BRNE delay_200ms_loop1
    DEC R21
    BRNE delay_200ms_loop0
    RET
