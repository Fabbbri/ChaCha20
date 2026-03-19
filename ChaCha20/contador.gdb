set pagination off
set confirm off
set disassemble-next-line on

target remote :1234


break chacha20.s:373
commands
    silent
    printf "ANTES del incremento:   s1 = %u (0x%08x)\n", $s1, $s1
    continue
end

break chacha20.s:374
commands
    silent
    printf "DESPUES del incremento: s1 = %u (0x%08x)\n\n", $s1, $s1
    continue
end

continue
