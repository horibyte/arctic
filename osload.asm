; ******************************************************************
; *                                                                *
; * Horibyte Arctic32 Kernel Loader                                *
; * Loads 32-bit kernel (ReKanto32)                                *
; * Copyright (c) 2025 Horibyte                                    *
; *                                                                *
; ******************************************************************


[org 0x100000] ; Loaded by boot.asm at 1MB
bits 32

; --- Constants ---
; Video memory address for text mode (VGA)
VGA_TEXT_MODE_ADDR equ 0xB8000
; Attribute for text (white on black)
DEFAULT_CHAR_ATTR equ 0x07

; --- Entry Point for 32-bit Kernel ---
start_32bit_kernel:
    ; Initialize 32-bit segment registers
    ; Use the data segment selector from GDT (0x10 for our GDT)
    mov eax, 0x10
    mov ds, eax
    mov es, eax
    mov fs, eax
    mov gs, eax
    mov ss, eax ; Set SS to data segment for stack

    ; Setup 32-bit stack
    ; Assuming 0x100000 is base of kernel, stack can be at 0x1FFFFF (just below 2MB)
    mov esp, 0x1FFFFF

    ; Clear screen (using 32-bit direct video memory access)
    call clear_screen_pm

    ; Print boot screen messages
    mov esi, msg_testing_purpose
    call print_string_pm
    mov esi, msg_horibyte_arctic
    call print_string_pm
    mov esi, msg_mode_test
    call print_string_pm
    mov esi, msg_build_version
    call print_string_pm
    mov esi, msg_copyright
    call print_string_pm

    ; Add a blank line for readability
    mov esi, newline_char_pm
    call print_string_pm

    ; Jump to the main Rekanto kernel
    ; Assuming rekanto.bin is loaded immediately after osload.bin
    ; If osload.asm is 4KB (0x1000 bytes) long, then rekanto.asm starts at 0x100000 + 0x1000 = 0x101000
    jmp 0x101000 ; Adjust if rekanto.asm is loaded at a different offset

; --- Subroutines for 32-bit Protected Mode ---

; clear_screen_pm: Clears the entire screen by writing spaces
clear_screen_pm:
    pushad
    mov edi, VGA_TEXT_MODE_ADDR
    mov ecx, 80 * 25 ; Total characters on screen
    mov al, ' '      ; Character to fill with
    mov ah, DEFAULT_CHAR_ATTR ; Attribute
    mov edx, eax     ; Character + attribute
    shl edx, 8
    or edx, eax      ; edx = 0x07200720 (space with attribute, repeated twice)

    ; Fill dwords (4 bytes at a time)
    .loop:
        stosd ; Store EAX (char+attr) into [EDI], increment EDI by 4
        stosd ; Store EAX (char+attr) into [EDI], increment EDI by 4
        dec ecx ; Decrement character count by 2
        dec ecx
        test ecx, ecx
        jnz .loop

    popad
    ret

; print_string_pm: Prints a null-terminated string at ESI to VGA text mode
; ESI points to the string. Cursor position is handled by writing to VRAM directly.
print_string_pm:
    pushad
    mov edi, VGA_TEXT_MODE_ADDR ; Current video memory pointer (start)
    mov ebx, 0                  ; Character counter for newlines/scrolling

.loop:
    lodsb                       ; Load byte from [ESI] into AL, increment ESI
    cmp al, 0                   ; Check for null terminator
    je .done

    cmp al, 0x0D                ; Check for Carriage Return (CR)
    je .handle_cr

    cmp al, 0x0A                ; Check for Line Feed (LF)
    je .handle_lf

    ; Handle regular character
    mov ah, DEFAULT_CHAR_ATTR   ; Character attribute (white on black)
    stosw                       ; Store AL (char) and AH (attr) as a word into [EDI], increment EDI by 2
    inc ebx                     ; Increment character counter
    cmp ebx, 80                 ; Check if end of line
    jl .loop                    ; Not end of line, continue
    ; If end of line, implicitly move to next line because EDI advanced

    ; Fall through to handle_lf to move to the next line
    jmp .handle_lf_continue

.handle_cr:
    ; Reset EDI to the beginning of the current line
    ; Current line = ebx / 80. Start of current line is VGA_TEXT_MODE_ADDR + (ebx / 80 * 80 * 2)
    ; Or simply, calculate current row, then set column to 0.
    mov eax, edi
    sub eax, VGA_TEXT_MODE_ADDR  ; Get current offset from start of VRAM
    xor edx, edx
    mov ecx, 160                 ; Bytes per line (80 chars * 2 bytes/char)
    div ecx                      ; EAX = current row index, EDX = byte offset within row
    sub edi, edx                 ; Subtract current column offset to get to beginning of line
    jmp .loop

.handle_lf:
    ; Move EDI to the beginning of the next line
    ; Current column position: (EDI - VGA_TEXT_MODE_ADDR) % 160
    mov eax, edi
    sub eax, VGA_TEXT_MODE_ADDR  ; Get current offset from start of VRAM
    xor edx, edx
    mov ecx, 160                 ; Bytes per line (80 chars * 2 bytes/char)
    div ecx                      ; EAX = current row index, EDX = byte offset within row
    add edi, 160                 ; Move EDI to the start of the next line

.handle_lf_continue:
    ; Check for scrolling if we hit the end of the screen
    cmp edi, VGA_TEXT_MODE_ADDR + (80 * 25 * 2) ; Beyond last row?
    jl .loop ; No scrolling needed, continue

    ; Scroll screen up by one line
    push esi                    ; Save ESI
    mov esi, VGA_TEXT_MODE_ADDR + (80 * 2) ; Source: Second row
    mov edi, VGA_TEXT_MODE_ADDR         ; Destination: First row
    mov ecx, 80 * 24 * 2 / 4    ; Copy 24 rows, 2 bytes/char, in dwords
    rep movsd                   ; Move 24 rows up

    ; Clear the last row
    mov edi, VGA_TEXT_MODE_ADDR + (80 * 24 * 2) ; Start of last row
    mov ecx, 80                 ; 80 characters to clear
    mov al, ' '                 ; Space character
    mov ah, DEFAULT_CHAR_ATTR   ; Attribute
    .clear_last_row_loop:
        stosw                   ; Store character and attribute
        loop .clear_last_row_loop

    pop esi                     ; Restore ESI
    ; Reset EDI to the beginning of the new last line
    mov edi, VGA_TEXT_MODE_ADDR + (80 * 24 * 2)
    xor ebx, ebx                ; Reset character counter for the new line
    jmp .loop

.done:
    popad
    ret

; --- Bootscreen Messages ---
msg_testing_purpose  db "For testing purposes only.", 0x0D, 0x0A, 0
msg_horibyte_arctic  db "Horibyte Arctic Server", 0x0D, 0x0A, 0
msg_mode_test        db "32-BIT Protected Mode Developer Test", 0x0D, 0x0A, 0
msg_build_version    db "Pre-Alpha 0.1 Build 5 LAB02", 0x0D, 0x0A, 0
msg_copyright        db "Copyright (c) 2025 Horibyte", 0x0D, 0x0A, 0

newline_char_pm      db 0x0D, 0x0A, 0 ; General purpose newline for 32-bit mode

; --- Padding ---
; Pad osload.asm to 4KB (0x1000 bytes) to align rekanto.asm easily
; Important, do not change
; times (0x1000 - ($ - $$)) db 0