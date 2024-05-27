; Define constants
.equ trigPin, 6
.equ echoPin, 5
.equ bulb, 9

; Setup
ldi r16, (1<<trigPin)|(1<<bulb) ; Set trigPin and bulb as output
out DDRD, r16
ldi r16, (1<<echoPin) ; Set echoPin as input
out DDRB, r16

; Main loop
loop:
; Trigger ultrasonic sensor
sbi PORTD, trigPin ; Set trigPin high
call delayMicroseconds ; Wait for 500 microseconds
cbi PORTD, trigPin ; Set trigPin low

; Measure echo
in r16, PINB
sbrc r16, echoPin
rjmp echo_high
rjmp echo_low

echo_high:
; Calculate distance
; ...

; Check if distance is less than 13
; ...

; If true, turn on light
sbi PORTD, bulb ; Set bulb high
call delaySeconds ; Wait for 15 seconds
cbi PORTD, bulb ; Set bulb low

rjmp loop ; Repeat the loop

; Subroutines for delay
delayMicroseconds:
; Delay for 500 microseconds
; ...
ret

delaySeconds:
; Delay for 15 seconds
; ...
ret
