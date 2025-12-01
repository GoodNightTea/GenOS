
[BITS 32]
[ORG 0x100000]
kernel_entry:
    mov esp, 0x7C00
    cli
    
    call setup_idt
    call setup_timer_idt
    call init_pics
    call init_timer
    sti
    mov al, 0
    call mode13_clear_screen
    
    mov esi, menu
    mov eax, 130
    mov ebx, 80
    mov dl, 100
    call mode13_print_string
    
    mov esi, SNAKE
    mov eax, 30
    mov ebx, 90
    mov dl, 1
    call mode13_print_string

    mov esi, TETRIS
    add ebx, 10
    mov dl, 2
    call mode13_print_string
    
    mov esi, GOF
    add ebx, 10
    mov dl, 3
    call mode13_print_string
    
    mov esi, PONG
    add ebx, 10
    mov dl, 4
    call mode13_print_string
    mov esi, PACMAN
	add ebx, 10
    mov dl, 5
    call mode13_print_string
    
    mov esi, DEBUG
    add ebx, 10
    mov dl, 6
    call mode13_print_string
    mov byte [menu_choice], 0xff

.wait_for_choice:
    hlt                              ; Wait for keyboard interrupt
    mov al, [menu_choice]            ; Check what user pressed
    cmp al, 1
    je .snake
    cmp al, 2
    je .tetris
    cmp al, 3
    je .gof
    cmp al, 4
    je .pong
    cmp al, 5
    je .pacman
    cmp al, 0
    je .test
 	jmp .wait_for_choice             ; Keep waiting 
.pong:
	call pong
	jmp .pong
.pacman:
	call pacman
	jmp .pacman
.gof:
	call gameoflife
	jmp .gof
.test:
	call test
	jmp .test	
.snake:
	call snake
	jmp .snake
.tetris:
    call tetris_setup
	jmp .tetris
    



; ============================================================================
; Include Drivers
; ============================================================================

%include "drivers/fonts/font1.asm"
%include "drivers/vga/13h_vga.asm"
%include "drivers/keyboard/keyboard_driver.asm"
%include "drivers/timer/timer_driver.asm"
%include "drivers/audio/audio_driver.asm"

; ============================================================================
; Include Kernels
; ============================================================================

%include "games/tetris.asm"
%include "games/test.asm"
%include "games/gameoflife.asm"
%include "games/pong.asm"
%include "games/pacman.asm"
%include "games/global_functions.asm"
%include "games/snake.asm"


; ============================================================================
; Data Section
; ============================================================================
	 

menu		  db 'CHOOSE A GAME', 0
SNAKE		  db '1 SNAKE', 0
TETRIS		  db '2 TETRIS', 0
GOF       	  db '3 GAMEOFLIFE', 0
PONG		  db '4 PONG', 0
PACMAN		  db '5 PACMAN', 0
DEBUG		  db '0 DEBUG', 0

; IDT structures
idt_desc:
    dw 2047                         ; Limit (256 entries * 8 bytes - 1)
    dd 0                            ; Base address (filled in by setup_idt)
