# Horibyte Arctic

Welcome to the repository that holds the most basic and ass source code ever made on Planet Earth!

...jokes aside, this repository contains the source code for Arctic, a new, from-scratch operating system.

## Compiling

Due to its simplicity, you can easily compile it.

First off, grab your copy of the source code via `git clone` in your preferred terminal.

Use [NASM](https://nasm.us) (Netwide Assembler) to compile the assembly files to binary files using `nasm -f bin file.asm -o file.bin`. To compile the files in this repo, use `nasm -f bin bootloader.asm -o bootloader.bin`, `nasm -f bin rekanto.asm -o rekanto.bin` and `nasm -f bin osload.asm -o osload.bin` respectively.

Then to make the final bootable image, get [Python](https://python.org) and run `make.py` in the terminal, then a `.img` file should appear.

## Booting and testing

Arctic supports both [QEMU](https://qemu.org) and VMware Workstation.

### QEMU

Run a terminal console on your project directory (e.g C:\Users\Horibyte\Arctic or /home/user/Arctic) and run `qemu-system-i386 -fda diskimagefilename*.img`.
The system should boot just fine, this should be the final window:

![QEMU_b1](https://github.com/user-attachments/assets/5050928b-c2a1-465d-9fac-68e45c8baaed)

### VMware

This time, it's just as simple as making a new VM (Workstation 5.x compatibility recommended, though any version works fine), and setting the Floppy image to the generated .img file.
This should be the final window:

![Horibyte Arctic Pre-Alpha 0 1 Build 3 - VMware Workstation_b1](https://github.com/user-attachments/assets/e5ac4b9b-a114-453d-b326-dabccb1b5e44)

It's literally as simple as that lmao

Either way, thanks for checking this shitty project out, development might and WILL be slow, so don't expect that much of this if im going to be honest.

Have a great day :)

\- Horibyte
