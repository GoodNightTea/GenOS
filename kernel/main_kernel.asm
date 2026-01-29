[BITS 32]
[ORG 0x100000]
kernel_entry:
    mov esp, 0x7C00
	; init of idt's, pics and fdc
    cli
    call setup_idt
    call setup_timer_idt
    call init_pics

    call init_timer
	sti
	cmp byte [menu_choice], -1
	je .entry

	; debug - remove after done
	call detect_fdc
	cmp al, 1
	je .skip_fdc_init
	call init_fdc
.skip_fdc_init:
	; debug - remove after done
    
    
    call setup_fdc_idt      
	call init_fdc
	call show_disk_stats
	call show_disk_layout
	
	mov eax, 1
	call wait_frames
.entry:
	cli
    ; god thats a sloppy fix, can just add an in_game variable but idk im lazy
    mov byte [is_tetris], 0
    mov byte [is_pong], 0  
    mov byte [is_debug], 0
    mov byte [is_cli], 0
.render:
	mov dword [grad_start_idx], 0xE0
	mov dword [grad_end_idx], 0xEF	
	mov eax, 0
	mov ebx, 0
	mov ecx, 320
	mov edx, 200
	call draw_gradient_rect
	
	; choice menu
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

    
    mov esi, PONG
    add ebx, 10
    mov dl, 3
    call mode13_print_string
    ; removed pacman due to it being oos of this project
    mov esi, TERMINAL
	add ebx, 10
    mov dl, 4
    call mode13_print_string
    mov esi, FONT
	add ebx, 10
    mov dl, 5
    call mode13_print_string
    
    mov esi, DEBUG
    add ebx, 10
    mov dl, 6
    call mode13_print_string
    mov byte [menu_choice], -1
    
	; logo    
    mov esi, welcome
    mov eax, 20
	mov ebx, 30
    mov dl, 3
    call mode13_print_string
    sub ebx, 10
    add eax, 85
    mov esi, 15
	call print_LOGO
	

.wait_for_choice:

	sti
    hlt               ; Wait for keyboard interrupt
    mov al, [menu_choice]            ; Check what user pressed
    cmp al, 1
    je .snake
    cmp al, 2
    je .tetris
    cmp al, 3
    je .pong
    cmp al, 4
    je .cli
    cmp al, 5
    je .font_tester
    cmp al, 0
    je .test
 	jmp .wait_for_choice             ; Keep waiting 
.pong:
	call pong
	jmp .pong
.cli:
	call terminal
	jmp .cli
.test:
	call test
	mov byte [is_debug], 1
	jmp .test
	
.snake:
	call snake
	jmp .snake
.tetris:
    call tetris_setup
	jmp .tetris
	
.font_tester:
    call font_tester
	jmp .font_tester
    





; ============================================================================
; Disk Layout Constants (injected by build script)
; ============================================================================
%ifndef DATA_START_SECTOR
    %define DATA_START_SECTOR 34   
%endif
	; fallback
%ifndef DATA_SECTORS
    %define DATA_SECTORS 2846      
%endif


KERNEL_DATA_START:  dd DATA_START_SECTOR
KERNEL_DATA_SIZE:   dd DATA_SECTORS

; ============================================================================
; Include Kernels
; ============================================================================

%include "games/tetris.asm"
%include "games/test.asm"
%include "games/pong.asm"
%include "games/global_functions.asm"
%include "games/snake.asm"
%include "games/terminal.asm"
%include "misc/font_tester.asm"

; ============================================================================
; Include Drivers
; ============================================================================

%include "drivers/fonts/font1.asm"
%include "drivers/fonts/font2.asm"
%include "drivers/fonts/GenOS_logo.asm"
%include "drivers/vga/13h_vga.asm"
%include "drivers/keyboard/keyboard_driver.asm"
%include "drivers/timer/timer_driver.asm"
%include "drivers/audio/audio_driver.asm"
%include "drivers/fs/fat12.asm"
%include "drivers/fdc/floppydisk_controller.asm"
%include "drivers/dma/direct_mem_access.asm"
; ============================================================================
; Data Section
; ============================================================================
 sector0_label: db 'UNO:', 0
sector1_label: db 'DOS:', 0
sector2_label: db 'TRES:', 0
read_fail:     db 'ERROR', 0

welcome		      db 'WELCOME TO', 0
menu		      db 'CHOOSE A GAME', 0
SNAKE		      db '1 SNAKE', 0
TETRIS		      db '2 TETRIS', 0
GOF       	      db '3 GAMEOFLIFE', 0
PONG		      db '4 PONG', 0
TERMINAL		  db '5 TERMINAL', 0
FONT		      db '6 FONT TESTER', 0
DEBUG		      db '0 DEBUG', 0


TOTAL_DISK_SECTORS  equ 2880
KERNEL_START_SECTOR equ 2



; IDT structures
idt_desc:
    dw 2047                         ; Limit (256 entries * 8 bytes - 1)
    dd 0                            ; Base address (filled in by setup_idt)

WRITE_BUFFER    equ 0x200000
READ_BUFFER     equ 0x200200   ; 512 bytes after write buffer
