; ******************************************************************
; * *
; * Horibyte Arctic32 Midori Bootloader                            *
; * Loads 32-bit kernel (osload.bin and rekanto.bin) and switches  *
; * to Protected Mode.                                             *
; * Copyright (c) 2025 Horibyte                                    *
; * *
; ******************************************************************

; I welcome you to the most ass bootloader ever - horibyte

[org 0x7C00]
bits 16

; --- CONSTANTS ---
OSLOAD_LBA          equ 1
OSLOAD_SECTORS      equ 10
REKANTO_LBA         equ OSLOAD_LBA + OSLOAD_SECTORS
REKANTO_SECTORS     equ 30

KERNEL_LOAD_ADDR    equ 0x100000      ; 1MB (20-bit linear address)
REKANTO_LOAD_ADDR   equ KERNEL_LOAD_ADDR + (OSLOAD_SECTORS * 512) ; Load Rekanto immediately after osload (0x101400)

; Corrected segment and offset calculations for BIOS INT 13h (AH=0x42) DAP
; The segment must be <= 0xFFFF. The offset must be <= 0xFFFF.
; For KERNEL_LOAD_ADDR (0x100000):
KERNEL_LOAD_OFFSET  equ 0x0000
KERNEL_LOAD_SEGMENT equ 0x1000        ; (0x1000 * 16 = 0x10000, 0x10000 + 0x0000 = 0x100000)

; For REKANTO_LOAD_ADDR (0x101400):
; We can keep the same segment as KERNEL_LOAD_SEGMENT and adjust the offset.
REKANTO_LOAD_OFFSET equ REKANTO_LOAD_ADDR - (KERNEL_LOAD_SEGMENT * 16) ; 0x101400 - 0x10000 = 0x1400
REKANTO_LOAD_SEGMENT equ KERNEL_LOAD_SEGMENT                         ; 0x1000

CODE_SEG equ 0x08
DATA_SEG equ 0x10

; --- ENTRY POINT ---
start:
    ; Set up segments
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax          ; Set SS to 0 (to use a stack below 0x7C00)
    mov sp, 0x7C00      ; Stack grows downwards from 0x7C00

    ; For debugging, print a message
    mov si, initial_msg
    call print_string_16bit

    ; --- Load osload.bin ---
    mov si, loading_osload_msg
    call print_string_16bit
    mov word [dap + 2], OSLOAD_SECTORS      ; Number of sectors
    mov word [dap + 4], KERNEL_LOAD_OFFSET  ; Offset of data buffer
    mov word [dap + 6], KERNEL_LOAD_SEGMENT ; Segment of data buffer
    mov dword [dap + 8], OSLOAD_LBA         ; LBA start address

    mov ah, 0x42
    mov dl, byte [boot_drive]
    mov si, dap
    int 0x13
    jc disk_error                           ; Jump if Carry Flag is set (error)
    mov si, osload_loaded_msg
    call print_string_16bit

    ; --- Load rekanto.bin ---
    mov si, loading_rekanto_msg
    call print_string_16bit
    mov word [dap + 2], REKANTO_SECTORS     ; Number of sectors
    mov word [dap + 4], REKANTO_LOAD_OFFSET ; Offset of data buffer
    mov word [dap + 6], REKANTO_LOAD_SEGMENT; Segment of data buffer
    mov dword [dap + 8], REKANTO_LBA         ; LBA start address

    mov ah, 0x42
    mov dl, byte [boot_drive]
    mov si, dap
    int 0x13
    jc disk_error
    mov si, rekanto_loaded_msg
    call print_string_16bit

    ; --- Enable A20 Line ---
    mov si, a20_enabling_msg
    call print_string_16bit
    mov ax, 0x2401  ; Enable A20
    int 0x15
    jc a20_error
    mov si, a20_enabled_msg
    call print_string_16bit

    ; --- Load GDT ---
    mov si, loading_gdt_msg
    call print_string_16bit
    lgdt [GDT_POINTER]                      ; Load GDT register
    mov si, gdt_loaded_msg
    call print_string_16bit

    ; --- Disable Interrupts ---
    cli
    mov si, cli_msg
    call print_string_16bit

    ; --- Prepare for Protected Mode Switch ---
    mov si, switching_to_pm_msg
    call print_string_16bit

    ; --- Set CR0 to enable Protected Mode ---
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; --- Far Jump to 32-bit Code ---
    ; After setting CR0.PE, CPU is in Protected Mode.
    ; CS is still a 16-bit segment register, so reload it with a Protected Mode selector.
    ; JMP target: CODE_SEG is selector, KERNEL_LOAD_ADDR is linear address.
    jmp CODE_SEG:pm32_entry

    [bits 32]
pm32_entry:
    ; Reload segment registers with data selector
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Set up stack pointer
    mov esp, 0x90000 ; This stack pointer is fine if 0x90000 is within your data segment

    ; Here you can add your 32-bit kernel code
    ; For now just infinite loop to prevent triple fault
.loop:
    jmp .loop

; --- Error Handlers ---
disk_error:
    mov si, disk_error_msg
    call print_string_16bit
    jmp $

a20_error:
    mov si, a20_error_msg
    call print_string_16bit
    jmp $

; --- Subroutines (16-bit) ---
; print_string_16bit: Prints a null-terminated string at DS:SI using BIOS INT 10h
print_string_16bit:
    pusha
    mov ah, 0x0e
.loop:
    lodsb           ; Load byte from DS:SI into AL, increment SI
    or al, al       ; Check if AL is null terminator
    jz .done
    int 0x10        ; BIOS Teletype Output
    jmp .loop
.done:
    popa
    ret

; ====================================================================
; --- Data Sections (Moved to after executable code for .bin) ---
; ====================================================================

; --- DISK ADDRESS PACKET (DAP) ---
dap:
    db 0x10             ; Size of packet (16 bytes)
    db 0                ; Reserved
    dw 0                ; Number of blocks (sectors) to read (filled later)
    dw 0                ; Offset of data buffer (filled later)
    dw 0                ; Segment of data buffer (filled later)
    dd 0                ; Lower 32 bits of LBA (filled later)
    dd 0                ; Upper 32 bits of LBA (not used for current LBA range)

; --- GLOBAL DESCRIPTOR TABLE (GDT) ---
GDT_START:
    ; Null Descriptor (required)
    dw 0x0000           ; Limit (low)
    dw 0x0000           ; Base (low)
    db 0x00             ; Base (middle)
    db 0x00             ; Access
    db 0x00             ; Granularity
    db 0x00             ; Base (high)

CODE_SEG_DESCRIPTOR:
    dw 0xFFFF           ; Limit (low) - 4GB limit for 32-bit mode (0xFFFFF * 4KB = 4GB)
    dw 0x0000           ; Base (low)
    db 0x00             ; Base (middle)
    db 10011010b        ; Access byte: P=1 (present), DPL=00 (ring 0), S=1 (code/data), E=1 (executable), C=0 (conforming), R=1 (readable), A=0 (accessed)
    db 11001111b        ; Granularity byte: G=1 (4KB granularity), D/B=1 (32-bit default op size), L=0 (64-bit not used), AVL=0 (available)
    db 0x00             ; Base (high)

DATA_SEG_DESCRIPTOR:
    dw 0xFFFF           ; Limit (low)
    dw 0x0000           ; Base (low)
    db 0x00             ; Base (middle)
    db 10010010b        ; Access byte: P=1, DPL=00, S=1, E=0 (data), W=1 (writable), A=0
    db 11001111b        ; Granularity byte: G=1, D/B=1, L=0, AVL=0
    db 0x00             ; Base (high)
GDT_END:

GDT_POINTER:
    dw GDT_END - GDT_START - 1  ; Limit of GDT (size - 1)
    dd GDT_START                ; Base address of GDT (absolute physical address)

; CODE_SEG and DATA_SEG are now defined as direct values, not relative to GDT_START
; because they are used as selectors, not offsets from the GDT_POINTER base.
; This is consistent with the hardcoded values (0x08 and 0x10) above.
; If you prefer, you could keep them as `equ CODE_SEG_DESCRIPTOR - GDT_START` etc.
; but for now, let's stick with what you have that works.


; --- String Messages ---
initial_msg         db 'Booting Arctic32...', 0x0d, 0x0a, 0
loading_osload_msg  db 'Load osload...', 0
osload_loaded_msg   db 'Ok!', 0x0d, 0x0a, 0
loading_rekanto_msg db 'Load rekanto...', 0
rekanto_loaded_msg  db 'Ok!', 0x0d, 0x0a, 0
a20_enabling_msg    db 'A20...', 0
a20_enabled_msg     db 'A20 ok!', 0x0d, 0x0a, 0
loading_gdt_msg     db 'Load GDT...', 0
gdt_loaded_msg      db 'GDT ok!', 0x0d, 0x0a, 0
cli_msg             db 'Ints off.', 0x0d, 0x0a, 0
switching_to_pm_msg db 'To PM...', 0x0d, 0x0a, 0
disk_error_msg      db 'Disk Err! Halted.', 0x0d, 0x0a, 0
a20_error_msg       db 'A20 Err! Halted.', 0x0d, 0x0a, 0
boot_drive          db 0x80

; --- Padding ---
times 510 - ($ - $$) db 0
dw 0xAA55