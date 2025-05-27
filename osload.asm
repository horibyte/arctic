; osload.asm
; Horibyte Arctic-ReKanto Kernel Loader (Second-Stage)
; This loads the main Rekanto Kernel (rekanto.bin)
; Copyright (c) 2025 Horibyte

[org 0x0000]    ; This code will be loaded by the bootloader (e.g., at 0x8000),
                ; so it starts at 0x0000 relative to that load address.
bits 16         ; Still in 16-bit Real Mode

; --- ENTRY POINT OF OSLOAD.ASM ---
start_osload:
    ; Set up segment registers relative to where this code was loaded (0x8000)
    ; This ensures data (messages) within osload.asm are accessible.
    mov ax, cs      ; CS already contains 0x8000 from the JMP in bootloader
    mov ds, ax      ; Set DS to 0x8000
    mov es, ax      ; Set ES to 0x8000 (if used for string ops here)

    ; For stack, generally keep it in low memory to avoid conflicts
    xor ax, ax      ; Clear AX
    mov ss, ax      ; Set SS to 0x0000 (stack in lower memory)
    mov sp, 0x7FF0  ; Stack Pointer for 0x0000:0x7FF0

    ; Clear the screen (optional, but good for visual confirmation)
    call clear_screen

    ; --- Print Initial Messages (from osload.asm) ---
    mov si, os_version_msg
    call print_string_osload

    mov si, osload_success_msg
    call print_string_osload

    ; --- Print a blank line after success messages ---
    mov si, newline_char
    call print_string_osload

    ; --- Print "Loading Rekanto Kernel..." message ---
    mov si, loading_rekanto_msg
    call print_string_osload

    ; --- Load rekanto.bin (the main kernel/CLI) ---
    ; Assume rekanto.bin starts at LBA 2 (sector 3, if 0-indexed)
    ; and is loaded to address 0x2000:0x0000 (Physical address 0x20000)

    mov ax, 0x2000     ; Segment for Rekanto Kernel loading
    mov es, ax         ; Set ES to 0x2000
    xor bx, bx         ; Offset for Rekanto Kernel loading (ES:BX = 0x2000:0x0000)

    mov ah, 0x02       ; AH=02h (Read Sectors from Drive)
    mov al, 8          ; AL=8 (Number of sectors to read - assuming rekanto.bin is up to 8 sectors for now)
                       ; **ADJUST AL based on actual rekanto.bin size in sectors!**
    mov ch, 0          ; CH=0 (Cylinder 0)
    mov cl, 3          ; CL=3 (Start at Sector 3 = LBA 2, if boot.bin=LBA0, osload.bin=LBA1)
                       ; **ADJUST CL based on where rekanto.bin is placed in your combined image!**
    mov dh, 0          ; DH=0 (Head 0)
    mov dl, 0          ; DL=0 (Drive 0 - BIOS passes boot drive in DL to us, so use it)
    int 13h            ; Call BIOS disk services
    jc disk_error_rekanto ; Jump if error

    ; If successful, print a success message for rekanto load
    mov si, rekanto_load_success_msg
    call print_string_osload

    ; --- Print a blank line before jumping ---
    mov si, newline_char
    call print_string_osload

    ; --- Jump to loaded Rekanto Kernel ---
    ; Assuming Rekanto Kernel entry point is at 0x2000:0x0000
    jmp 0x2000:0x0000  ; Far jump to the Rekanto Kernel's entry point (start_rekanto)

disk_error_rekanto:
    ; Simple error handling for rekanto load
    mov si, rekanto_load_error_msg
    call print_string_osload
    cli                ; Disable interrupts
    hlt                ; Halt the CPU

; --- Subroutines (used by osload.asm itself) ---

; clear_screen: Clears the entire screen
clear_screen:
    mov ax, 0x0600  ; AH=06h (scroll window up), AL=00h (clear window)
    mov bh, 0x07    ; BH=07h (attribute: white on black)
    xor cx, cx      ; CH=0, CL=0 (upper-left corner row 0, col 0)
    mov dx, 0x184f  ; DH=24, DL=79 (lower-right corner row 24, col 79)
    int 0x10        ; Call BIOS video services
    ret

; print_string_osload: Prints a null-terminated string at DS:SI
print_string_osload:
    mov ah, 0x0e        ; BIOS teletype function (display character, advance cursor)
.loop:
    lodsb               ; Load byte from DS:SI into AL, increment SI
    or al, al           ; Check if AL is zero (end of string)
    jz .done            ; If zero, jump to done
    int 0x10            ; Otherwise, print the character
    jmp .loop           ; Loop back
.done:
    ret                 ; Return from function

; --- Data Messages (for osload.asm) ---
os_version_msg      db 'Horibyte Arctic [Version 0.1.4]', 0x0d, 0x0a, 0

newline_char        db 0x0d, 0x0a, 0

osload_success_msg  db 'Horibyte Arctic-ReKanto Kernel Load Success', 0x0d, 0x0a
                    db 'Copyright (c) 2025 Horibyte', 0x0d, 0x0a, 0

loading_rekanto_msg   db 'Loading Rekanto Kernel (rekanto.bin)...', 0x0d, 0x0a, 0

rekanto_load_success_msg db 'Kernel load SUCCESS!', 0x0d, 0x0a, 0
rekanto_load_error_msg db 'ERROR: Failed to load ReKanto Kernel!', 0x0d, 0x0a, 0

; --- Padding (optional, recommended to fill a full sector if needed) ---
; Ensure osload.bin fits within the expected size for the primary bootloader
; to load. Default is 1 sector (512 bytes).
times 512 - ($ - $$) db 0 ; Pad to exactly one 512-byte sector