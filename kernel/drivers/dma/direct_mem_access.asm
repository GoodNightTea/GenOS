
; ============================================================================
; START AI GENERATED SECTION ;
; setup_dma_read: Configure DMA channel 2 for reading from FDC
; Input: ECX = number of bytes to transfer (typically 512)
; ============================================================================
setup_dma_read:
    pushad
    
    ; Disable DMA channel 2
    mov al, 0x06            ; Mask channel 2 (disable)
    mov dx, DMA_MASK
    out dx, al
    
    ; Clear byte pointer flip-flop
    mov dx, DMA_RESET_FF
    xor al, al
    out dx, al
    
    ; Set DMA mode: single transfer, address increment, read (FDC→Memory)
    mov al, 0x46            ; Channel 2, single, increment, verify off, read
    mov dx, DMA_MODE
    out dx, al
    
    ; Set address (DMA_BUFFER = 0x80000)
    ; Low 16 bits go to address register
    mov eax, DMA_BUFFER
    mov dx, DMA_ADDR_2
    out dx, al              ; Low byte
    shr eax, 8
    out dx, al              ; High byte
    
    ; Set page (bits 16-23 of address)
    shr eax, 8              ; Now AL = 0x08 (page)
    mov dx, DMA_PAGE_2
    out dx, al
    
    ; Set count (bytes - 1)
    mov eax, ecx
    dec eax                 ; DMA counts from 0
    mov dx, DMA_COUNT_2
    out dx, al              ; Low byte
    shr eax, 8
    out dx, al              ; High byte
    
    ; Enable DMA channel 2
    mov al, 0x02            ; Unmask channel 2
    mov dx, DMA_MASK
    out dx, al
    
    popad
    ret

; ============================================================================
; setup_dma_write: Configure DMA channel 2 for writing to FDC
; Input: ECX = number of bytes to transfer
; ============================================================================
setup_dma_write:
    pushad
    
    ; Disable channel
    mov al, 0x06
    mov dx, DMA_MASK
    out dx, al
    
    ; Clear flip-flop
    mov dx, DMA_RESET_FF
    xor al, al
    out dx, al
    
    ; Set mode: write (Memory→FDC)
    mov al, 0x4A            ; Channel 2, single, increment, verify off, write
    mov dx, DMA_MODE
    out dx, al
    
    ; Set address
    mov eax, DMA_BUFFER
    mov dx, DMA_ADDR_2
    out dx, al
    shr eax, 8
    out dx, al
    
    ; Set page
    shr eax, 8
    mov dx, DMA_PAGE_2
    out dx, al
    
    ; Set count
    mov eax, ecx
    dec eax
    mov dx, DMA_COUNT_2
    out dx, al
    shr eax, 8
    out dx, al
    
    ; Enable channel
    mov al, 0x02
    mov dx, DMA_MASK
    out dx, al
    
    popad
    ret

; ============================================================================
; fdc_read_sector: Read one sector from disk
; Input: 
;   AL = track (cylinder)
;   AH = head (side)
;   BL = sector (1-18)
; Output:
;   AL = 0 on success, error code on failure
;   Data in DMA_BUFFER (0x80000)
; ============================================================================
fdc_read_sector:
    pushad
    
    ; Save parameters
    mov [read_track], al
    mov [read_head], ah
    mov [read_sector], bl
    
    ; Turn motor on
    call fdc_motor_on
    
    ; Setup DMA for 512 bytes
    mov ecx, 512
    call setup_dma_read
    
    ; Clear IRQ flag
    mov byte [fdc_irq_fired], 0
    
    ; Send READ DATA command
    mov al, CMD_READ_DATA | CMD_MFM    ; 0x46 = read + MFM mode
    call fdc_write_byte
    
    ; Send head and drive
    mov al, [read_head]
    shl al, 2                   ; Head in bits 2
    ; Drive 0 is bits 0-1 (already 0)
    call fdc_write_byte
    
    ; Send track
    mov al, [read_track]
    call fdc_write_byte
    
    ; Send head again
    mov al, [read_head]
    call fdc_write_byte
    
    ; Send sector
    mov al, [read_sector]
    call fdc_write_byte
    
    ; Send bytes per sector (2 = 512 bytes)
    mov al, 2
    call fdc_write_byte
    
    ; Send end of track (last sector on track)
    mov al, 18                  ; 1.44MB = 18 sectors/track
    call fdc_write_byte
    
    ; Send GPL (gap3 length)
    mov al, 0x1B                ; Standard for 1.44MB
    call fdc_write_byte
    
    ; Send data length (0xFF when bytes/sector is specified)
    mov al, 0xFF
    call fdc_write_byte
    
    ; Wait for operation to complete
    call fdc_wait_irq
    
    ; Read result bytes (7 bytes)
    call fdc_read_byte
    mov [fdc_result_buffer + 0], al     ; ST0
    
    call fdc_read_byte
    mov [fdc_result_buffer + 1], al     ; ST1
    
    call fdc_read_byte
    mov [fdc_result_buffer + 2], al     ; ST2
    
    call fdc_read_byte
    mov [fdc_result_buffer + 3], al     ; Track
    
    call fdc_read_byte
    mov [fdc_result_buffer + 4], al     ; Head
    
    call fdc_read_byte
    mov [fdc_result_buffer + 5], al     ; Sector
    
    call fdc_read_byte
    mov [fdc_result_buffer + 6], al     ; Bytes per sector
    
    ; Check for errors in ST0
    mov al, [fdc_result_buffer]
    and al, 0xC0                ; Check error bits
    cmp al, 0
    jne .error
    
    
    popad
    xor al, al
    ret
    
.error:
    popad
    mov al, 1
    ret
; END OF AI GENERATED SECTION ;
test_dma_operations:
    mov al, 0
    call mode13_clear_screen
    
    ; Test 1: Write
    mov edi, 0x200000           ; Use high memory
    mov ecx, 512
    mov al, 'T'
    rep stosb
    
    mov eax, 0
    mov ecx, 1
    mov esi, 0x200000
    call write_data_sectors
    
    cmp al, 0
    jne .fail1
    
    ; Test 2: Read back
    mov eax, 0
    mov ecx, 1
    mov edi, 0x201000
    call read_data_sectors
    
    cmp al, 0
    jne .fail2
    
    ; Test 3: Verify
    cmp byte [0x201000], 'T'
    jne .fail3
    
    ; Success!
    mov esi, pass_msg
    mov eax, 100
    mov ebx, 100
    mov dl, 10
    call mode13_print_string
    jmp .done
    
.fail1:
    mov esi, write_fail
    jmp .show
.fail2:
    mov esi, read_fail
    jmp .show
.fail3:
    mov esi, verify_fail
.show:
    mov eax, 100
    mov ebx, 100
    mov dl, 4
    call mode13_print_string
    
.done:
    hlt
    jmp .done

pass_msg:       db 'PASS', 0
write_fail:     db 'WRITE FAIL', 0

verify_fail:    db 'VERIFY FAIL', 0



; ============================================================================
; Data for read_sector
; ============================================================================
read_track:     db 0
read_head:      db 0
read_sector:    db 0
