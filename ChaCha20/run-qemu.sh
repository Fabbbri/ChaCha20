#!/bin/bash

# Run QEMU with GDB server for ChaCha20 RISC-V implementation
echo "Starting QEMU with GDB server on port 1234..."
echo "In another terminal, run: gdb-multiarch chacha20.elf"
echo "Then in GDB: target remote :1234"
echo ""

qemu-system-riscv32 \
    -machine virt \
    -nographic \
    -bios none \
    -kernel chacha20.elf \
    -S \
    -gdb tcp::1234