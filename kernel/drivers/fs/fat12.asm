; ============================================================================
; show_disk_layout:	visualizes the layout of the disk, which sectors are full
; 				which are owned by root and the free sectors
; ============================================================================
show_disk_layout:
	pushad

    call fdc_show_status
	mov eax, 20
	call wait_frames
	call show_disk_stats
	jmp .display_disk_layout

.display_disk_layout:
    mov edi, [KERNEL_DATA_START]    
    mov dword [vis_x], 10           
    mov dword [vis_y], 20           
    xor ecx, ecx
    
.loop:
    
    ; Draw current block
    mov eax, [vis_x]
    mov ebx, [vis_y]
    mov ecx, 2
    mov edx, 4
    mov esi, 2
    call mode13_fill_rect
    mov eax, 1
    call wait_frames

    add dword [vis_x], 3
    inc dword [wrap_counter]
    
    cmp dword [wrap_counter], 300
    jl .no_wrap
    
    mov dword [vis_x], 10
    add dword [vis_y], 5
    mov dword [wrap_counter], 0
    
.no_wrap:
    dec edi
    jnz .loop
	
.size:
	mov edi, [KERNEL_DATA_SIZE]
	mov ecx, 0

    xor ecx, ecx
.loop1:
    
    ; Draw current block
    mov eax, [vis_x]
    mov ebx, [vis_y]
    mov ecx, 2
    mov edx, 4
    mov esi, 7
    call mode13_fill_rect
    
    add dword [vis_x], 3
    
    inc dword [wrap_counter]
    
    cmp dword [wrap_counter], 100
    jl .no_wrap1
    
    mov dword [vis_x], 10
    add dword [vis_y], 5
    mov dword [wrap_counter], 0
    mov eax, 1
    call wait_frames

.no_wrap1:
    dec edi
    jnz .loop1
    mov eax, 200
    call wait_frames
    popad
    ret
	


; ============================================================================
; Helper: Display current disk stats
; ============================================================================
show_disk_stats:
    pushad
    
    mov esi, filled
    mov eax, 170
    mov ebx, 170
    mov dl, 15
    call print_cool_string
    mov eax, 1
    call wait_frames
    
    ; Show data start sector
    mov eax, [KERNEL_DATA_START]
    call int_to_string
    mov eax, 300
    mov ebx, 170
    mov dl, 10
    call print_cool_string
    
    mov eax, 1
    call wait_frames
    
    mov esi, free
    mov eax, 170
    mov ebx, 180
    mov dl, 15
    call print_cool_string
    
    ; Show available sectors
    mov eax, [KERNEL_DATA_SIZE]
    call int_to_string
    mov eax, 285
    mov ebx, 180
    mov dl, 10
    call print_cool_string
    
    popad
    ret

; ============================================================================
; Filesystem Layout:
; Sector 34: Allocation bitmap (can track 4096 sectors with 512 bytes)
; Sector 35+: Actual data
; ============================================================================

BITMAP_SECTOR   equ 34
FIRST_DATA_SEC  equ 35

; ============================================================================
; init_filesystem: Initialize or load bitmap
; ============================================================================
init_filesystem:
    pushad
    
    ; Read bitmap sector
    mov eax, BITMAP_SECTOR
    mov ecx, 1
    mov edi, SECTOR_BITMAP
    call read_sectors
    
    ; Check if initialized (magic bytes)
    cmp dword [SECTOR_BITMAP], 0x46535359  ; 'FSSY' magic
    je .already_init
    
    ; First boot - initialize bitmap
    mov edi, SECTOR_BITMAP
    mov ecx, 512
    xor al, al
    rep stosb                       ; Clear all bits = all free
    
    ; Set magic
    mov dword [SECTOR_BITMAP], 0x46535359
    
    ; Write back to disk
    mov eax, BITMAP_SECTOR
    mov ecx, 1
    mov esi, SECTOR_BITMAP
    call write_sectors
    
.already_init:
    popad
    ret

; ============================================================================
; allocate_sector: Find and allocate a free sector
; Output: EAX = sector number (relative to FIRST_DATA_SEC), or -1 if full
; ============================================================================
allocate_sector:
    push ebx
    push ecx
    push edx
    push edi
    
    mov edi, SECTOR_BITMAP + 4      ; Skip magic bytes
    xor ebx, ebx                    ; Sector counter
    
.byte_loop:
    cmp ebx, DATA_SECTORS
    jge .no_space
    
    mov al, [edi]
    cmp al, 0xFF                    ; All bits used?
    je .next_byte
    
    ; Find first free bit in this byte
    xor ecx, ecx                    ; Bit counter (0-7)
    
.bit_loop:
    cmp ecx, 8
    jge .next_byte
    
    bt [edi], ecx                   ; Test bit
    jc .bit_used                    ; Carry set = bit is 1 (used)
    
    ; Found free bit! Set it and calculate sector
    bts [edi], ecx                  ; Set bit
    
    ; Calculate absolute sector number
    mov eax, edi
    sub eax, SECTOR_BITMAP + 4      ; Byte offset
    shl eax, 3                      ; * 8 bits per byte
    add eax, ecx                    ; + bit offset
    
    ; Save bitmap back to disk
    push eax
    mov eax, BITMAP_SECTOR
    mov ecx, 1
    mov esi, SECTOR_BITMAP
    call write_sectors
    pop eax
    
    jmp .done
    
.bit_used:
    inc ecx
    jmp .bit_loop
    
.next_byte:
    inc edi
    add ebx, 8
    jmp .byte_loop
    
.no_space:
    mov eax, -1
    
.done:
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret

; ============================================================================
; free_sector: Mark sector as free
; Input: EAX = sector number (relative to FIRST_DATA_SEC)
; ============================================================================
free_sector:
    push ebx
    push ecx
    push edx
    
    ; Calculate byte and bit
    mov ebx, eax
    shr eax, 3                      ; Byte offset = sector / 8
    and ebx, 7                      ; Bit offset = sector % 8
    
    ; Clear bit
    lea ecx, [SECTOR_BITMAP + 4 + eax]
    btr [ecx], ebx                  ; Clear bit
    
    ; Write bitmap back
    mov eax, BITMAP_SECTOR
    mov ecx, 1
    mov esi, SECTOR_BITMAP
    call write_sectors
    
    pop edx
    pop ecx
    pop ebx
    ret

; ============================================================================
; count_free_sectors: Count available sectors
; Output: EAX = number of free sectors
; ============================================================================
count_free_sectors:
    push ebx
    push ecx
    push edi
    
    xor eax, eax                    ; Free count
    mov edi, SECTOR_BITMAP + 4
    mov ecx, DATA_SECTORS / 8       ; Number of bytes to check
    
.byte_loop:
    mov bl, [edi]
    not bl                          ; Invert: 1 = free
    
    ; Count bits in BL
    xor edx, edx
.bit_loop:
    test bl, bl
    jz .next_byte
    
    inc edx
    mov bh, bl
    sub bh, 1
    and bl, bh                      ; Clear lowest set bit
    jmp .bit_loop
    
.next_byte:
    add eax, edx
    inc edi
    loop .byte_loop
    
    pop edi
    pop ecx
    pop ebx
    ret

; ============================================================================
; lba_to_chs: Convert logical sector to Track/Head/Sector
; Input: EAX = LBA (logical sector, 0-2879 for 1.44MB)
; Output: 
;   AL = track (0-79)
;   AH = head (0-1)
;   BL = sector (1-18)
; ============================================================================
lba_to_chs:
    push ecx
    push edx
    
    ; Track = LBA / (heads * sectors_per_track)
    ; Head = (LBA / sectors_per_track) % heads
    ; Sector = (LBA % sectors_per_track) + 1
    
    xor edx, edx
    mov ecx, SECTORS_PER_TRACK
    div ecx                     ; EAX = LBA / 18, EDX = LBA % 18
    
    mov bl, dl
    inc bl                      ; Sector = remainder + 1
    
    xor edx, edx
    mov ecx, HEADS
    div ecx                     ; EAX = track, EDX = head
    
    mov ah, dl                  ; Head
    ; AL already = track
    
    pop edx
    pop ecx
    ret

read_sectors:
    pushad
    
    mov [rs_lba], eax
    mov [rs_count], ecx
    mov [rs_dest], edi
    
.loop:
    cmp dword [rs_count], 0
    je .done
    
    ; Read
    mov eax, [rs_lba]
    call lba_to_chs
    call fdc_read_sector
    
    ; Copy from DMA
    push esi
    push edi
    push ecx
    mov esi, DMA_BUFFER
    mov edi, [rs_dest]
    mov ecx, 512
    rep movsb
    mov [rs_dest], edi
    pop ecx
    pop edi
    pop esi
    
    inc dword [rs_lba]
    dec dword [rs_count]
    jmp .loop
    
.done:
    popad
    xor al, al
    ret


; ============================================================================
; write_sectors: Write to any data region
; Input: EAX = data sector offset, ECX = count, ESI = source buffer
; Output: AL = 0 on success
; ============================================================================

write_sectors:
    pushad
    
    mov [ws_lba], eax
    mov [ws_count], ecx
    mov [ws_src], esi
    
.loop:
    cmp dword [ws_count], 0
    je .done
    
    ; Copy to DMA
    push esi
    push edi
    push ecx
    mov esi, [ws_src]
    mov edi, DMA_BUFFER
    mov ecx, 512
    rep movsb
    mov [ws_src], esi
    pop ecx
    pop edi
    pop esi
    
    ; Write
    mov eax, [ws_lba]
    call lba_to_chs
    call fdc_write_sector
    
    inc dword [ws_lba]
    dec dword [ws_count]
    jmp .loop
    
.done:
    popad
    xor al, al
    ret

; ============================================================================
; write_data_sectors: Write to safe data region
; Input: EAX = data sector offset, ECX = count, ESI = source buffer
; Output: AL = 0 on success
; ============================================================================
write_data_sectors:
    pushad
    
    ; Bounds check
    mov ebx, eax
    add ebx, ecx
    cmp ebx, [KERNEL_DATA_SIZE]
    jg .error
    
    ; Convert to absolute LBA
    add eax, [KERNEL_DATA_START]
    call write_sectors
    
    popad
    xor al, al
    ret
    
.error:
    popad
    mov al, 1
    ret

; ============================================================================
; read_data_sectors: Read from safe data region  
; Input: EAX = data sector offset, ECX = count, EDI = dest buffer
; Output: AL = 0 on success
; ============================================================================
read_data_sectors:
    pushad
    
    ; Bounds check
    mov ebx, eax
    add ebx, ecx
    cmp ebx, [KERNEL_DATA_SIZE]
    jg .error
    
    ; Convert to absolute LBA
    add eax, [KERNEL_DATA_START]
    call read_sectors
    
    popad
    xor al, al
    ret
    
.error:
    popad
    mov al, 1
    ret

.result_color: db 10



	
; ============================================================================
; Data Section
; ============================================================================
SECTOR_BITMAP:  times 512 db 0     ; In-memory copy of bitmap
data_bounds_error:  db 'SECTOR OUT OF BOUNDS', 0
filled:         db 'FILLED SECTORS', 0	
free:         db 'FREE SECTORS', 0	

write_ok_msg:       db 'WRITE OK', 0
write_failed_msg:   db 'WRITE FAILED', 0

ws_lba:     dd 0
ws_count:   dd 0
ws_src:     dd 0

rs_lba:     dd 0
rs_count:   dd 0
rs_dest:    dd 0


vis_x:          dd 10
vis_y:          dd 20
wrap_counter:   dd 0

