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
; Helper: Display current disk layout
; ============================================================================
show_disk_layout:
    pushad
    
    mov esi, layout_msg
    mov eax, 10
    mov ebx, 40
    mov dl, 15
    call mode13_print_string
    
    ; Show data start sector
    mov eax, [KERNEL_DATA_START]
    call int_to_string
    mov eax, 10
    mov ebx, 50
    mov dl, 10
    call mode13_print_string
    
    ; Show available sectors
    mov eax, [KERNEL_DATA_SIZE]
    call int_to_string
    mov eax, 10
    mov ebx, 60
    mov dl, 10
    call mode13_print_string
    
    popad
    ret

; Data
data_bounds_error:  db 'SECTOR OUT OF BOUNDS', 0
layout_msg:         db 'DATA START AVAILABLE', 0	

; ============================================================================
; Data Section
; ============================================================================


ws_lba:     dd 0
ws_count:   dd 0
ws_src:     dd 0

rs_lba:     dd 0
rs_count:   dd 0
rs_dest:    dd 0
