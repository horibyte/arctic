; Horibyte Arctic-Midori Bootloader
; Copyright (c) 2025 Horibyte.

[org 0x7c00] ; Bootloader will be loaded at 0x7c00

; --- Constants for loading ---
LOAD_ADDRESS    equ 0x8000  ; Where to load the OS loader (e.g., Stage 2)
LOAD_SECTORS    equ 4       ; Number of sectors to load for the OS loader (e.g., 4 sectors = 2KB)

; --- Start of Bootloader Execution ---
start:
    ; Set up segment registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    ; Set Stack Pointer (SP) at 0x7c00 + 512 - 2 = 0x7dff.
    ; This places the stack at the very end of the 512-byte boot sector,
    ; growing downwards into memory *above* the boot sector.
    ; This is a common and safe practice.
    mov sp, 0x7dff      

    ; --- Print Initial Messages ---
    mov si, msg_system_booting
    call print_string

    mov si, msg_version_short
    call print_string

    mov si, msg_loading_osload_short
    call print_string

; --- Perform a Disk Reset (AH=0x00) before attempting to read ---
    mov ah, 0x00        ; BIOS Reset Disk System function
    mov dl, 0x00        ; Drive 0x00 (first floppy disk)
    mov ch, 0x00        ; Explicitly set Cylinder to 0
    mov dh, 0x00        ; Explicitly set Head to 0
    int 0x13            ; Call BIOS disk services
    jc disk_error_reset ; Re-enable this! This is crucial for debugging now.

; --- Load the OS Loader (Stage 2) from disk ---
    mov ah, 0x02        ; BIOS Read Sectors function
    mov al, LOAD_SECTORS ; Number of sectors to read
    mov ch, 0x00        ; Cylinder 0
    mov cl, 0x02        ; Start reading from Sector 2 (Sector 1 is this bootloader)
    mov dh, 0x00        ; Head 0
    mov dl, 0x00        ; Drive 0x00 (first floppy disk)

    mov bx, LOAD_ADDRESS ; Load segment address into BX
    mov es, bx          ; ES:BX is the destination address (LOAD_ADDRESS:0x0000)
    xor bx, bx          ; Clear BX (ES:BX is ES:0000 + BX offset)

    int 0x13            ; Call BIOS disk services

    jc disk_error_read  ; Re-enable this! If Carry Flag is set, an error occurred during read

    ; --- Jump to the loaded OS Loader ---
    jmp LOAD_ADDRESS:0x0000 ; Jump to the start of the loaded OS loader

; --- Error Handling ---
disk_error_reset:
    mov si, error_reset_short
    call print_string
    mov al, ah          ; Get the error code from AH
    call print_hex_byte
    jmp $               ; Infinite loop on error

disk_error_read:
    mov si, error_read_short
    call print_string
    mov al, ah          ; Get the error code from AH
    call print_hex_byte
    jmp $               ; Infinite loop on error

; --- Helper Function to Print String ---
print_string:
    mov ah, 0x0e        ; BIOS teletype function
.loop:
    lodsb               ; Load byte from DS:SI into AL, increment SI
    or al, al
    jz .done
    int 0x10            ; Print character
    jmp .loop
.done:
    ret

; --- Helper Function to Print 2-Digit Hex Byte ---
print_hex_byte:
    push ax
    push bx
    push cx

    mov bl, al          ; Copy AL to BL
    shr bl, 4           ; Get upper nibble into lower 4 bits of BL
    call .print_nibble  ; Print upper nibble

    mov al, bl          ; AL already has original byte from before SHR
    and al, 0x0F        ; Get lower nibble
    call .print_nibble  ; Print lower nibble

    pop cx
    pop bx
    pop ax
    ret

.print_nibble:
    cmp al, 9
    jg .alpha
    add al, '0'
    jmp .print
.alpha:
    add al, 'A' - 10
.print:
    mov ah, 0x0e
    int 0x10
    ret

; --- Data Messages ---
msg_system_booting         db 'Booting from PhysicalDrives/FDA1', 0x0d, 0x0a, 0
msg_version_short          db 'Horibyte Arctic Pre-Alpha 0.1 Build 5', 0x0d, 0x0a, 0
msg_loading_osload_short   db 'Loading OS Loader...', 0x0d, 0x0a, 0
error_reset_short          db 'FAILED (Reset): 0x', 0x0d, 0x0a, 0
error_read_short           db 'FAILED (Read): 0x', 0x0d, 0x0a, 0

; --- Boot Sector Padding and Signature ---
times 510 - ($ - $$) db 0
dw 0xaa55