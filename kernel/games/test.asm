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
	
	; wait for input

	call play_tone
	mov eax, 1
	call wait_frames
	call stop_tone
	mov eax, 1
	call wait_frames
	hlt
	hlt
	mov eax, dword [freq]
	jmp .loop
	
	

x 		dd 0
y 		dd 0
colord   dd 0
countd  dd 0
rowd 	dd 0
music 	db 1
freq	dd 0
