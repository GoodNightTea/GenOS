test:
    mov esp, 0x7000
    mov dword [freq], 100
.display:
	cmp byte [song], 1
	je .song
	; Input: EAX = x, EBX = y, ECX = width, EDX = height, ESI = color
	cmp dword [count], 21
	je .next_row
	mov eax, dword [x]
	mov ebx, dword [y]
	mov ecx, 15
	mov edx, 15
	mov esi, dword [colord]
	call mode13_fill_rect
	mov eax, 2
	call wait_frames
	inc dword [count]
	inc dword [colord]
	add dword [x], 15
	jmp .display
.next_row:
	
	mov dword [x], 0
	add dword [y], 15
	mov dword [count], 0
	inc dword [rowd]
	cmp dword [rowd], 12
	jge .hlt
	jmp .display

.hlt:
	mov byte [song], 1
	jmp .display
.song:

	mov eax, dword [freq]
	call play_tone
	mov eax, dword [length]
	call stop_tone
	jmp .display
	
x 		dd 0
y 		dd 0
colord   dd 0
count  dd 0
rowd 	dd 0
song		db 0
freq 	dd 0
length  dd 2
