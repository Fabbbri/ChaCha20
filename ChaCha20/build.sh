#!/bin/bash

# Build script for C+assembly example
echo "Building C+assembly example..."

# Compile C source to object file
riscv64-unknown-elf-gcc \
    -march=rv32im \
    -mabi=ilp32 \
    -nostdlib \
    -ffreestanding \
    -g3 \
    -gdwarf-4 \
    -c \
    example.c \
    -o example.o

if [ $? -ne 0 ]; then
    echo "C compilation failed"
    exit 1
fi

# Compile startup assembly to object file
riscv64-unknown-elf-gcc \
    -march=rv32im \
    -mabi=ilp32 \
    -nostdlib \
    -ffreestanding \
    -g3 \
    -gdwarf-4 \
    -c \
    startup.s \
    -o startup.o

if [ $? -ne 0 ]; then
    echo "Startup assembly compilation failed"
    exit 1
fi

# Compile math assembly source to object file
riscv64-unknown-elf-gcc \
    -march=rv32im \
    -mabi=ilp32 \
    -nostdlib \
    -ffreestanding \
    -g3 \
    -gdwarf-4 \
    -c \
    math_asm.s \
    -o math_asm.o

if [ $? -ne 0 ]; then
    echo "Math assembly compilation failed"
    exit 1
fi

# Link object files together
riscv64-unknown-elf-gcc \
    -march=rv32im \
    -mabi=ilp32 \
    -nostdlib \
    -ffreestanding \
    -g3 \
    -gdwarf-4 \
    startup.o \
    example.o \
    math_asm.o \
    -T linker.ld \
    -o example.elf

if [ $? -eq 0 ]; then
    echo "Build successful: example.elf created"
    echo "Object files: example.o, math_asm.o"
else
    echo "Linking failed"
    exit 1
fi