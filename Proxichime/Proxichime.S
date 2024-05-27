#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main
.equ light_pin, 2 ; PB2 as Light bulb pin
.equ trig_pin, 1 ; PB1 as Trigger pin
.equ echo_pin, 0 ; PB0 as Echo pin

main:
    ; Setup input and output ports
    SBI DDRB, light_pin
    SBI DDRB, trig_pin
    CBI DDRB, echo_pin

    ; Setup serial monitor
    CLR R27
    ; Clear UCSR0A, UBRR0H register
    STS UCSR0A, R27   
    STS UBRR0H, R27
    ; Set baud rate 9600
    LDI R27, 103      
    STS UBRR0L, R27
    ; Enable RXB & TXB
    LDI R27, 1<<RXEN0 | 1<<TXEN0  
    STS UCSR0B, R27
    ; Asynch, even parity, 1 stop, 8 bits
    LDI R27, 1<<UCSZ00 | 1<<UCSZ01 | 1<<UPM01
    STS UCSR0C, R27

main_loop0:
    ; Get the distance measured by the HCSR04 sensor
    RCALL calculate_distance

    ; Control the light based on the distance reading
    RCALL light_logic

    ; Delay to ensure the sensor is ready
    RCALL delay_200ms

    RJMP  main_loop0

;========================================================================

; Get distance measurement using HCSR04 sensor
; Arguments (0)
; Returns (1): distance_in_cm (R25)
calculate_distance:
    ; Send 10us high pulse to sensor
    SBI PORTB, 1
    RCALL delay_timer0
    CBI PORTB, 1      

    ; Timer1 normal mode
    LDI R27, 0b00000000
    STS TCCR1A, R27

    ; Rising edge detection & prescaler=1024, noise cancellation ON
    LDI R27, 0b11000101 
    STS TCCR1B, R27     

calculate_distance_loop0:
    ; Loop until rising edge is detected
    IN R27, TIFR1
    SBRS R27, ICF1
    RJMP calculate_distance_loop0

    ; Store count value at rising edge
    PUSH R17
    LDS R17, ICR1L

    ; Clear flag for falling edge detection
    OUT TIFR1, R27

    ; Set for falling edge detection
    LDI R27, 0b10000101
    STS TCCR1B, R27

calculate_distance_loop1:
    ; Loop until falling edge is detected
    IN R27, TIFR1
    SBRS R27, ICF1
    RJMP calculate_distance_loop1

    ; Store count value at falling edge
    PUSH R16
    LDS R16, ICR1L

    ; Computer the difference
    SUB R16, R17

    ; Display result to serial monitor
    MOV R25, R16
    RCALL generate_ascii_msd
    RCALL is_lcd_buffer_ready
    STS   UDR0, R25
    MOV R25, R16
    RCALL generate_ascii_lsd
    RCALL is_lcd_buffer_ready
    STS   UDR0, R25

    ; Print \n\r to serial monitor
    RCALL is_lcd_buffer_ready
    LDI R26, 10
    STS UDR0, R26
    RCALL is_lcd_buffer_ready
    LDI R26, 13
    STS UDR0, R26

    ; Clear flag for next sensor reading
    OUT TIFR1, R27

    MOV R25, R16
    POP R16
    POP R17

    RET

;========================================================================

; Control the light based on the distance reading
; Arguments (1): distance_in_cm (R25)
; Returns (0)
light_logic:
    ; Turn on light when distance measured is < 200cm
    CPI R25, 50
    BRMI turn_on
    
    ; Else, turn off light
    CBI PORTB, 2
    RET

turn_on:
    ; Turn on light
    SBI PORTB, 2

    RET

;========================================================================

; 10us delay via Timer0
; Arguments (0)
; Returns (0)
delay_timer0:
    ; Initialize timer0 with count=0
    CLR R27
    OUT TCNT0, R27  

    ; OCR0 = 20
    LDI R27, 20
    OUT OCR0A, R27

    ; CTC mode, prescaler 8
    LDI R27, 0b00001010
    OUT TCCR0B, R27

delay_timer0_loop0:
    ; Get TIFR0 byte & check
    IN R27, TIFR0

    ; If OCF0=1, skip next instruction
    SBRS R27, OCF0A

    ; Else, loop back & check OCF0 flag
    RJMP delay_timer0_loop0

    ; Stop timer0
    CLR R27
    OUT TCCR0B, R27

    ; Clear OCF0 flag
    LDI R27, (1<<OCF0A)
    OUT TIFR0, R27

    RET

;========================================================================

; Make a 200ms delay using nested loops
; Arguments (0)
; Returns (0)
delay_200ms:
    LDI R27, 255
delay_200ms_loop0: 
    LDI R26, 255
delay_200ms_loop1:
    LDI R25, 50
delay_200ms_loop2:
    DEC R25
    BRNE delay_200ms_loop2
    DEC R26
    BRNE delay_200ms_loop1
    DEC R27
    BRNE delay_200ms_loop0
    RET

;========================================================================

; Tests data buffer if data can be sent
; Arguments (0)
; Returns (0)
is_lcd_buffer_ready:
    LDS R27, UCSR0A
    SBRS R27, UDRE0
    RJMP is_lcd_buffer_ready
    RET

;========================================================================

; Generates ASCII representation of the byte's most significant nibble
; Arguments (1): byte_to_be_converted (R25)
; Returns (1): converted_ascii (R25)
generate_ascii_msd:
    ; Extract & swap high-nibble
    ANDI R25, 0xF0
    SWAP R25

    ; Convert to ASCII (0 to 9)
    SUBI R25, -48
    ; Branch if the ascii character is >9 (A to F)
    MOV R27, R25
    SUBI R27, 58
    BRPL generate_ascii_msd_AtoF
    RET

generate_ascii_msd_AtoF:
    ; Convert to ASCII (A to F)
    SUBI R25, -7
    RET

;========================================================================

; Generates ASCII representation of the byte's least significant nibble
; Arguments (1): byte_to_be_converted (R25)
; Returns (1): converted_ascii (R25)
generate_ascii_lsd:
    ; Extract low-nibble
    ANDI R25, 0x0F

    ; Convert to ASCII (0 to 9)
    SUBI R25, -48
    ; Branch if the ascii character is >9 (A to F)
    MOV R27, R25
    SUBI R27, 58
    BRPL generate_ascii_lsd_AtoF
    RET

generate_ascii_lsd_AtoF:
    SUBI R25, -7
    RET

;========================================================================


