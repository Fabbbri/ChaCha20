set pagination off
set confirm off
set disassemble-next-line on

target remote :1234

# Evidencia 1: Estado inicial
break chacha20.s:247
commands
    silent
    printf "\n========== EVIDENCIA 1: ESTADO INICIAL ==========\n"
    printf "Constantes RFC:\n"
    x/4xw $sp
    printf "\nClave (32 bytes):\n"
    x/8xw $sp+16
    printf "\nContador + Nonce:\n"
    x/4xw $sp+48
    printf "=================================================\n\n"
    continue
end

# Evidencia 2: Después de 20 rondas
break chacha20.s:271
commands
    silent
    printf "\n========== EVIDENCIA 2: DESPUES DE 20 RONDAS ==========\n"
    printf "Working state:\n"
    x/16xw $sp
    printf "\nOriginal state:\n"
    x/16xw $sp+64
    printf "=======================================================\n\n"
    continue
end

# Evidencia 3: Keystream final
break chacha20.s:284
commands
    silent
    printf "\n========== EVIDENCIA 3: KEYSTREAM FINAL ==========\n"
    x/16xw $sp
    printf "==================================================\n\n"
    continue
end

continue

# Evidencia 4: Tests completos
printf "\n========== EVIDENCIA 4: TESTS RFC 8439 ==========\n"
printf "(Ver salida arriba con los 3 PASS)\n"
printf "=================================================\n\n"
