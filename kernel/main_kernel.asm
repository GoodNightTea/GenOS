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
	cmp byte [menu_choice], -1
	je .entry
    call setup_fdc_idt      
	call init_fdc

    call fdc_show_status
	mov eax, 60
	call wait_frames

	mov eax, 0              ; Start at LBA 0
	mov ecx, 3              ; Read 3 sectors
	mov edi, 0x90000        ; Destination buffer
	call read_sectors

	cmp al, 0
	jne .read_error

	; uno byte
	mov esi, sector0_label
	mov eax, 20
	mov ebx, 90
	mov dl, 15
	call mode13_print_string

	mov al, [0x90000]       ; sector 0 
	call byte_to_hex
	mov eax, 80
	mov ebx, 90
	mov dl, 15
	call mode13_print_string

	; Sector 1
	mov esi, sector1_label
	mov eax, 20
	mov ebx, 100
	mov dl, 15
	call mode13_print_string

	mov al, [0x90200]       ; sector 1
	call byte_to_hex
	mov eax, 80
	mov ebx, 100
	mov dl, 15
	call mode13_print_string

	; Sector 2
	mov esi, sector2_label
	mov eax, 20
	mov ebx, 110
	mov dl, 15
	call mode13_print_string

	mov al, [0x90400]       ;sector 2
	call byte_to_hex
	mov eax, 80
	mov ebx, 110
	mov dl, 15
	call mode13_print_string
	mov eax, 200
	call wait_frames
	mov al, 0
	call mode13_clear_screen

	jmp .test_disk_layout

.read_error:
	mov esi, read_fail
	mov eax, 20
	mov ebx, 80
	mov dl, 4
	call mode13_print_string

.done:
.entry:


	cli
    ; god thats a sloppy fix, can just add an in_game variable but idk im lazy
    mov byte [is_tetris], 0
    mov byte [is_pong], 0  
    mov byte [is_debug], 0
    mov byte [is_cli], 0
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
    mov esi, TERMINAL
	add ebx, 10
    mov dl, 5
    call mode13_print_string
    
    mov esi, DEBUG
    add ebx, 10
    mov dl, 6
    call mode13_print_string
    mov byte [menu_choice], -1

.wait_for_choice:
	sti
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
    cmp al, 6
    je .cli
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
    
.test_disk_layout:
    call show_disk_layout
    
    ; Try writing to sector 0 (should work)
    mov edi, WRITE_BUFFER
    mov ecx, 512
    mov al, 0xAA
    rep stosb
    
    mov eax, 0              ; First data sector
    mov ecx, 1
    mov esi, WRITE_BUFFER
    call write_data_sectors
    
    cmp al, 0
    je .write_ok
    
    ; Error handling
    mov esi, write_failed_msg
    mov eax, 20
    mov ebx, 80
    mov dl, 4
    call mode13_print_string
    jmp .wait
    
.write_ok:
    mov esi, write_ok_msg
    mov eax, 20
    mov ebx, 80
    mov dl, 10
    call mode13_print_string
    
.wait:
    mov eax, 500
    call wait_frames
	jmp .done

write_ok_msg:       db 'WRITE OK', 0
write_failed_msg:   db 'WRITE FAILED', 0




; ============================================================================
; Disk Layout Constants (injected by build script)
; ============================================================================
%ifndef DATA_START_SECTOR
    %define DATA_START_SECTOR 34   
%endif

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
%include "games/gameoflife.asm"
%include "games/pong.asm"
%include "games/pacman.asm"
%include "games/global_functions.asm"
%include "games/snake.asm"
%include "games/terminal.asm"

; ============================================================================
; Include Drivers
; ============================================================================

%include "drivers/fonts/font1.asm"
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
read_fail:     db 'FUCK', 0

menu		      db 'CHOOSE A GAME', 0
SNAKE		  db '1 SNAKE', 0
TETRIS		  db '2 TETRIS', 0
GOF       	  db '3 GAMEOFLIFE', 0
PONG		      db '4 PONG', 0
PACMAN		  db '5 PACMAN', 0
TERMINAL		  db '6 TERMINAL', 0
DEBUG		  db '0 DEBUG', 0


TOTAL_DISK_SECTORS  equ 2880
KERNEL_START_SECTOR equ 2



; IDT structures
idt_desc:
    dw 2047                         ; Limit (256 entries * 8 bytes - 1)
    dd 0                            ; Base address (filled in by setup_idt)

WRITE_BUFFER    equ 0x200000
READ_BUFFER     equ 0x200200   ; 512 bytes after write buffer
