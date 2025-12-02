test:
    mov esp, 0x7000
    mov dword [freq], 600
    cmp byte [music], 1
    je .music
.display:
	; Input: EAX = x, EBX = y, ECX = width, EDX = height, ESI = color
	cmp dword [countd], 21
	je .next_row
	mov eax, dword [x]
	mov ebx, dword [y]
	mov ecx, 15
	mov edx, 15
	mov esi, dword [colord]
	call mode13_fill_rect
	mov eax, 2
	call wait_frames
	inc dword [countd]
	inc dword [colord]
	add dword [x], 15
	jmp .display
.next_row:	
	
	mov dword [x], 0
	add dword [y], 15
	mov dword [countd], 0
	inc dword [rowd]
	cmp dword [rowd], 12
	jge .hlt
	jmp .display

.hlt:
	sti
	hlt
	mov eax, 1000
	call wait_frames
	jmp .hlt
.music:
	mov al, 1
	call mode13_clear_screen
.loop:
	mov eax, dword [freq]
	hlt
	call play_tone
	mov eax, 1
	call wait_frames
	call stop_tone
	hlt
	mov eax, 1
	call wait_frames
	hlt
	
	
	jmp .loop
	
NOTE_E5  equ 659
NOTE_B4  equ 494
NOTE_C5  equ 523
NOTE_D5  equ 587
NOTE_A4  equ 440
NOTE_G4  equ 392

QUARTER  equ 30    
EIGHTH   equ 15    
DOTTED_Q equ 45    
SIXTEENTH equ 8    

play_tetris:

    mov eax, NOTE_E5
    call play_tone
    mov eax, QUARTER
    call wait_frames
    
    mov eax, NOTE_B4
    call play_tone
    mov eax, EIGHTH
    call wait_frames
    
    mov eax, NOTE_C5
    call play_tone
    mov eax, EIGHTH
    call wait_frames
    
    mov eax, NOTE_D5
    call play_tone
    mov eax, QUARTER
    call wait_frames
    
    mov eax, NOTE_C5
    call play_tone
    mov eax, EIGHTH
    call wait_frames
    
    mov eax, NOTE_B4
    call play_tone
    mov eax, EIGHTH
    call wait_frames
    

    mov eax, NOTE_A4
    call play_tone
    mov eax, QUARTER
    call wait_frames
    
    mov eax, NOTE_A4
    call play_tone
    mov eax, EIGHTH
    call wait_frames
    
    mov eax, NOTE_C5
    call play_tone
    mov eax, EIGHTH
    call wait_frames
    
    mov eax, NOTE_E5
    call play_tone
    mov eax, QUARTER
    call wait_frames
    
    mov eax, NOTE_D5
    call play_tone
    mov eax, EIGHTH
    call wait_frames
    
    mov eax, NOTE_C5
    call play_tone
    mov eax, EIGHTH
    call wait_frames
    

    mov eax, NOTE_B4
    call play_tone
    mov eax, QUARTER
    call wait_frames
    
    call stop_tone
    mov eax, EIGHTH
    call wait_frames
    
    mov eax, NOTE_C5
    call play_tone
    mov eax, EIGHTH
    call wait_frames
    
    mov eax, NOTE_D5
    call play_tone
    mov eax, QUARTER
    call wait_frames
    
    mov eax, NOTE_E5
    call play_tone
    mov eax, QUARTER
    call wait_frames
    

    mov eax, NOTE_C5
    call play_tone
    mov eax, QUARTER
    call wait_frames
    
    mov eax, NOTE_A4
    call play_tone
    mov eax, QUARTER
    call wait_frames
    
    mov eax, NOTE_A4
    call play_tone
    mov eax, QUARTER
    call wait_frames
    
    call stop_tone
    mov eax, QUARTER
    call wait_frames
    
    ret

x 		dd 0
y 		dd 0
colord   dd 0
countd  dd 0
rowd 	dd 0
music 	db 1
freq	dd 0
