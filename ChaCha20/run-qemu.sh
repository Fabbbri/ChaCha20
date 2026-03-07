#!/bin/bash

# Run QEMU with GDB server for ChaCha20 RISC-V implementation
echo "Starting QEMU with GDB server on port 1234..."
echo "In another terminal, run: gdb-multiarch chacha20.elf"
echo "Then in GDB: target remote :1234"
echo ""
echo "Useful GDB commands:"
echo "  break _start                    - break at program start"
echo "  break main                      - break at main()"
echo "  break chacha20_quarter_round    - break at quarter round"
echo "  info registers                  - show register values"
echo "  x/16xw \$a0                      - show state array"

qemu-system-riscv32 \
    -machine virt \
    -nographic \
    -bios none \
    -kernel chacha20.elf \
    -S \
    -gdb tcp::1234