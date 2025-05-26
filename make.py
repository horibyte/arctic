import os

BOOTLOADER_BIN = "bootloader.bin"
OSLOAD_BIN = "osload.bin"
OUTPUT_IMG = "en-us_0.1.3_horibyte_arctic_prealpha_6799.img"
SECTOR_SIZE = 512
IMAGE_SIZE_MB = 1.44  # Standard floppy disk size
IMAGE_SIZE_BYTES = int(IMAGE_SIZE_MB * 1024 * 1024)

def create_disk_image():
    try:
        with open(BOOTLOADER_BIN, 'rb') as f:
            bootloader_data = f.read()
        if len(bootloader_data) != SECTOR_SIZE:
            print(f"Warning: {BOOTLOADER_BIN} is not exactly {SECTOR_SIZE} bytes. Padding/truncating.")
            bootloader_data = bootloader_data[:SECTOR_SIZE].ljust(SECTOR_SIZE, b'\0')

        with open(OSLOAD_BIN, 'rb') as f:
            osload_data = f.read()

        # Create a blank image file first
        with open(OUTPUT_IMG, 'wb') as f:
            f.write(b'\0' * IMAGE_SIZE_BYTES) # Fill with zeros

        # Write bootloader to sector 0
        with open(OUTPUT_IMG, 'r+b') as f:
            f.write(bootloader_data)

            # Write osload to sector 1 (512 bytes offset from start)
            f.seek(SECTOR_SIZE)
            f.write(osload_data)

        print(f"Successfully created {OUTPUT_IMG} with {BOOTLOADER_BIN} and {OSLOAD_BIN}.")
        print(f"Total size: {os.path.getsize(OUTPUT_IMG)} bytes.")

    except FileNotFoundError as e:
        print(f"Error: {e}. Make sure '{BOOTLOADER_BIN}' and '{OSLOAD_BIN}' are in the same directory.")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

if __name__ == "__main__":
    create_disk_image()