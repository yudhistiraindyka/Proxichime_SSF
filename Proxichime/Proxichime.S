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
    CLR R24
    ; Clear UCSR0A, UBRR0H register
    STS UCSR0A, R24   
    STS UBRR0H, R24
    ; Set baud rate 9600
    LDI R24, 103      
    STS UBRR0L, R24
    ; Enable RXB & TXB
    LDI R24, 1<<RXEN0 | 1<<TXEN0  
    STS UCSR0B, R24
    ; Asynch, even parity, 1 stop, 8 bits
    LDI R24, 1<<UCSZ00 | 1<<UCSZ01 | 1<<UPM01
    STS UCSR0C, R24

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

    ; Display result to serial monitor
    MOV   R16, R28
    RCALL generate_ascii_msd
    RCALL is_lcd_buffer_ready
    STS   UDR0, R16
    RCALL generate_ascii_lsd
    RCALL is_lcd_buffer_ready
    STS   UDR0, R16

    ; Print \n\r to serial monitor
    RCALL is_lcd_buffer_ready
    LDI R16, 10
    STS UDR0, R16
    RCALL is_lcd_buffer_ready
    LDI R16, 13
    STS UDR0, R16

    ; Clear flag for next sensor reading
    OUT TIFR1, R21

    RET

;========================================================================

; Control the light based on the distance reading
light_logic:
    ; Turn on light when distance measured is < 200cm
    CPI R28, 50
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

;========================================================================

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

;========================================================================

; Tests data buffer if data can be sent
is_lcd_buffer_ready:
    LDS R27, UCSR0A
    SBRS R27, UDRE0
    RJMP is_lcd_buffer_ready
    RET

;========================================================================

; Generates ASCII representation of R16's most significant nibble
generate_ascii_msd:
    MOV R23, R16 ; save copy of result
    ANDI R16, 0xF0 ; extract & swap high-nibble
    SWAP R16 
    SUBI R16, -48 ; R16 = R16 - (48) = R16 + 48
    MOV R28, R16 ; save a copy of high-byte result
    SUBI R28, 58 ; if +ve       
    BRPL A_F_D1 ; branch & addz 7 to get ASCII A to F
generate_ascii_msd_ret: RET

;========================================================================

; Generates ASCII representation of R16's least significant nibble
generate_ascii_lsd:
    MOV R16, R23 ; restore copy of result
    ANDI R16, 0x0F ; extract low-nibble
    SUBI R16, -48 ; R16 = R16 - (48) = R16 + 48
    MOV R28, R16 ; save a copy of high-byte result
    SUBI R28, 58 ; if +ve
    BRPL A_F_D0 ; branch & add 7 to get ASCII A to F
generate_ascii_lsd_ret: RET    

;========================================================================

A_F_D1:
    SUBI R16, -7 ; R16 = R16 - (7) = R16 + 7
    RJMP generate_ascii_msd_ret

;========================================================================

A_F_D0:
    SUBI R16, -7 ; R16 = R16 - (7) = R16 + 7
    RJMP generate_ascii_lsd_ret
