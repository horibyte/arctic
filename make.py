import os

BOOTLOADER_BIN = "boot.bin"
OSLOAD_BIN = "osload.bin"
REKANTO_BIN = "rekanto.bin"  # Path to your Rekanto Kernel binary
OUTPUT_IMG = "en-us_0.1.4_lab02_horibyte_arctic32_5628.img"
SECTOR_SIZE = 512
IMAGE_SIZE_MB = 1.44  # Standard floppy disk size (e.g., 1.44MB)

def create_disk_image():
    # Initialize IMAGE_SIZE_BYTES as a local variable
    image_size_bytes_current = int(IMAGE_SIZE_MB * 1024 * 1024)

    try:
        # --- Read Bootloader ---
        with open(BOOTLOADER_BIN, 'rb') as f:
            bootloader_data = f.read()
        
        if len(bootloader_data) > SECTOR_SIZE:
            print(f"Warning: {BOOTLOADER_BIN} is larger than {SECTOR_SIZE} bytes. Truncating.")
            bootloader_data = bootloader_data[:SECTOR_SIZE]
        elif len(bootloader_data) < SECTOR_SIZE:
            print(f"Warning: {BOOTLOADER_BIN} is smaller than {SECTOR_SIZE} bytes. Padding with zeros.")
            bootloader_data = bootloader_data.ljust(SECTOR_SIZE, b'\0')

        # --- Read OSLoad (Second-Stage Loader) ---
        with open(OSLOAD_BIN, 'rb') as f:
            osload_data = f.read()
        
        # OSLoad is typically 1 sector
        if len(osload_data) > SECTOR_SIZE:
            print(f"Warning: {OSLOAD_BIN} is larger than {SECTOR_SIZE} bytes. Truncating.")
            osload_data = osload_data[:SECTOR_SIZE]
        elif len(osload_data) < SECTOR_SIZE:
            print(f"Warning: {OSLOAD_BIN} is smaller than {SECTOR_SIZE} bytes. Padding with zeros.")
            osload_data = osload_data.ljust(SECTOR_SIZE, b'\0')

        # --- Read Rekanto Kernel (Third-Stage CLI) ---
        with open(REKANTO_BIN, 'rb') as f:
            rekanto_data = f.read()
        
        # Calculate how many sectors rekanto_data occupies and pad to that size
        rekanto_sectors = (len(rekanto_data) + SECTOR_SIZE - 1) // SECTOR_SIZE
        print(f"Info: {REKANTO_BIN} size: {len(rekanto_data)} bytes, occupying {rekanto_sectors} sectors.")
        
        # Pad rekanto_data to the next full sector
        rekanto_data_padded_size = rekanto_sectors * SECTOR_SIZE
        if len(rekanto_data) < rekanto_data_padded_size:
            rekanto_data = rekanto_data.ljust(rekanto_data_padded_size, b'\0')


        # --- Calculate required image size and adjust if necessary ---
        # bootloader_data (1 sector) + osload_data (1 sector) + rekanto_data (X sectors)
        required_image_size = SECTOR_SIZE + len(osload_data) + len(rekanto_data)
        
        if required_image_size > image_size_bytes_current:
            print(f"Warning: Calculated required image size ({required_image_size} bytes) "
                  f"exceeds initial nominal floppy size ({image_size_bytes_current} bytes). Expanding image.")
            # Set the image_size_bytes_current to the larger required size, rounded up to a full sector
            image_size_bytes_current = ((required_image_size + SECTOR_SIZE - 1) // SECTOR_SIZE) * SECTOR_SIZE


        # --- Create a blank image file first ---
        with open(OUTPUT_IMG, 'wb') as f:
            f.write(b'\0' * image_size_bytes_current) # Fill with zeros

        # --- Write binaries to the image ---
        with open(OUTPUT_IMG, 'r+b') as f:
            # Write bootloader to sector 0 (offset 0)
            f.write(bootloader_data)

            # Write osload to sector 1 (offset 512)
            f.seek(SECTOR_SIZE)
            f.write(osload_data)

            # Write rekanto to sector 2 (offset 512 + 512 = 1024)
            # This is LBA 2, which corresponds to BIOS sector 3 (CL=3)
            f.seek(SECTOR_SIZE * 2) # Offset for LBA 2
            f.write(rekanto_data)

        print(f"Successfully created {OUTPUT_IMG}.")
        print(f"  - {BOOTLOADER_BIN} (LBA 0)")
        print(f"  - {OSLOAD_BIN} (LBA 1, {len(osload_data)} bytes)")
        print(f"  - {REKANTO_BIN} (LBA 2, {len(rekanto_data)} bytes, padded to {rekanto_sectors} sectors)")
        print(f"Total image size: {os.path.getsize(OUTPUT_IMG)} bytes.")

    except FileNotFoundError as e:
        print(f"Error: {e}. Make sure all binary files are in the same directory.")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

if __name__ == "__main__":
    create_disk_image()
