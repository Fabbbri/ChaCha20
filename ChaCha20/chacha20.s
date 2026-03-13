.section .text

# =============================================================================
# chacha20_quarter_round
# =============================================================================
# Pseudocode (RFC 8439 Section 2.1):
#   a += b; d ^= a; d <<<= 16;
#   c += d; b ^= c; b <<<= 12;
#   a += b; d ^= a; d <<<= 8;
#   c += d; b ^= c; b <<<= 7;
#
# Parámetros: a0=state_ptr, a1=idx_a, a2=idx_b, a3=idx_c, a4=idx_d
# =============================================================================
.globl chacha20_quarter_round
.type  chacha20_quarter_round, @function
chacha20_quarter_round:
    # Convertir índices a offsets (índice * 4 bytes)
    slli    a1, a1, 2           # offset_a = idx_a * 4
    slli    a2, a2, 2           # offset_b = idx_b * 4
    slli    a3, a3, 2           # offset_c = idx_c * 4
    slli    a4, a4, 2           # offset_d = idx_d * 4

    # Cargar state[a], state[b], state[c], state[d]
    add     t0, a0, a1
    lw      t2, 0(t0)           # t2 = a = state[idx_a]
    add     t0, a0, a2
    lw      t3, 0(t0)           # t3 = b = state[idx_b]
    add     t0, a0, a3
    lw      t4, 0(t0)           # t4 = c = state[idx_c]
    add     t0, a0, a4
    lw      t5, 0(t0)           # t5 = d = state[idx_d]

    # Línea 1: a += b; d ^= a; d <<<= 16
    add     t2, t2, t3          # a += b
    xor     t5, t5, t2          # d ^= a
    slli    t0, t5, 16
    srli    t1, t5, 16
    or      t5, t0, t1          # d <<<= 16

    # Línea 2: c += d; b ^= c; b <<<= 12
    add     t4, t4, t5          # c += d
    xor     t3, t3, t4          # b ^= c
    slli    t0, t3, 12
    srli    t1, t3, 20
    or      t3, t0, t1          # b <<<= 12

    # Línea 3: a += b; d ^= a; d <<<= 8
    add     t2, t2, t3          # a += b
    xor     t5, t5, t2          # d ^= a
    slli    t0, t5, 8
    srli    t1, t5, 24
    or      t5, t0, t1          # d <<<= 8

    # Línea 4: c += d; b ^= c; b <<<= 7
    add     t4, t4, t5          # c += d
    xor     t3, t3, t4          # b ^= c
    slli    t0, t3, 7
    srli    t1, t3, 25
    or      t3, t0, t1          # b <<<= 7

    # Guardar resultados
    add     t0, a0, a1
    sw      t2, 0(t0)           # state[a] = t2
    add     t0, a0, a2
    sw      t3, 0(t0)           # state[b] = t3
    add     t0, a0, a3
    sw      t4, 0(t0)           # state[c] = t4
    add     t0, a0, a4
    sw      t5, 0(t0)           # state[d] = t5

    ret

# =============================================================================
# chacha20_inner_block
# =============================================================================
# Pseudocode (RFC 8439 Section 2.3.1):
#   QUARTERROUND(0, 4,  8, 12)  # column 0
#   QUARTERROUND(1, 5,  9, 13)  # column 1
#   QUARTERROUND(2, 6, 10, 14)  # column 2
#   QUARTERROUND(3, 7, 11, 15)  # column 3
#   QUARTERROUND(0, 5, 10, 15)  # diagonal 0
#   QUARTERROUND(1, 6, 11, 12)  # diagonal 1
#   QUARTERROUND(2, 7,  8, 13)  # diagonal 2
#   QUARTERROUND(3, 4,  9, 14)  # diagonal 3
#
# Parámetros: a0=state_ptr
# =============================================================================
.globl chacha20_inner_block
.type  chacha20_inner_block, @function
chacha20_inner_block:
    addi    sp, sp, -8
    sw      ra, 4(sp)
    sw      s0, 0(sp)
    mv      s0, a0              # s0 = state_ptr (preservar)

    # -------------------------------------------------------------------------
    # Column rounds
    # -------------------------------------------------------------------------
    
    # QUARTERROUND(0, 4, 8, 12) - columna 0
    mv      a0, s0
    li      a1, 0
    li      a2, 4
    li      a3, 8
    li      a4, 12
    call    chacha20_quarter_round

    # QUARTERROUND(1, 5, 9, 13) - columna 1
    mv      a0, s0
    li      a1, 1
    li      a2, 5
    li      a3, 9
    li      a4, 13
    call    chacha20_quarter_round

    # QUARTERROUND(2, 6, 10, 14) - columna 2
    mv      a0, s0
    li      a1, 2
    li      a2, 6
    li      a3, 10
    li      a4, 14
    call    chacha20_quarter_round

    # QUARTERROUND(3, 7, 11, 15) - columna 3
    mv      a0, s0
    li      a1, 3
    li      a2, 7
    li      a3, 11
    li      a4, 15
    call    chacha20_quarter_round

    # -------------------------------------------------------------------------
    # Diagonal rounds
    # -------------------------------------------------------------------------
    
    # QUARTERROUND(0, 5, 10, 15) - diagonal 0
    mv      a0, s0
    li      a1, 0
    li      a2, 5
    li      a3, 10
    li      a4, 15
    call    chacha20_quarter_round

    # QUARTERROUND(1, 6, 11, 12) - diagonal 1
    mv      a0, s0
    li      a1, 1
    li      a2, 6
    li      a3, 11
    li      a4, 12
    call    chacha20_quarter_round

    # QUARTERROUND(2, 7, 8, 13) - diagonal 2
    mv      a0, s0
    li      a1, 2
    li      a2, 7
    li      a3, 8
    li      a4, 13
    call    chacha20_quarter_round

    # QUARTERROUND(3, 4, 9, 14) - diagonal 3
    mv      a0, s0
    li      a1, 3
    li      a2, 4
    li      a3, 9
    li      a4, 14
    call    chacha20_quarter_round

    lw      s0, 0(sp)
    lw      ra, 4(sp)
    addi    sp, sp, 8
    ret

# =============================================================================
# chacha20_block
# =============================================================================
# Pseudocode (RFC 8439 Section 2.3.1):
#   chacha20_block(key, counter, nonce):
#       state = constants | key | counter | nonce    # PASO 1
#       working_state = state                        # PASO 2
#       for i = 1 upto 10:                           # PASO 3
#           inner_block(working_state)
#       working_state += state                       # PASO 4
#       return serialize(working_state)              # PASO 5
#
# Parámetros: a0=key, a1=counter, a2=nonce, a3=output
# Stack: sp+0..63 = working_state, sp+64..127 = state
# =============================================================================
.globl chacha20_block
.type  chacha20_block, @function
chacha20_block:
    # --- Prólogo ---
    addi    sp, sp, -176
    sw      ra, 172(sp)
    sw      s0, 168(sp)
    sw      s1, 164(sp)
    sw      s2, 160(sp)
    sw      s3, 156(sp)
    sw      s4, 152(sp)

    # Guardar parámetros en callee-saved
    mv      s0, a0              # s0 = key
    mv      s1, a1              # s1 = counter
    mv      s2, a2              # s2 = nonce
    mv      s3, a3              # s3 = output

    # -------------------------------------------------------------------------
    # PASO 1: state = constants | key | counter | nonce
    # -------------------------------------------------------------------------
    # state[0..3] = "expand 32-byte k"
    li      t0, 0x61707865; sw t0, 0(sp)    # state[0] = "expa"
    li      t0, 0x3320646e; sw t0, 4(sp)    # state[1] = "nd 3"
    li      t0, 0x79622d32; sw t0, 8(sp)    # state[2] = "2-by"
    li      t0, 0x6b206574; sw t0, 12(sp)   # state[3] = "te k"

    # state[4..11] = key (32 bytes = 8 words)
    lw t0, 0(s0);  
    sw t0, 16(sp)            # state[4]  = key[0..3]

    lw t0, 4(s0) 
    sw t0, 20(sp)            # state[5]  = key[4..7]
    
    lw t0, 8(s0)  
    sw t0, 24(sp)            # state[6]  = key[8..11]
    
    lw t0, 12(s0)
    sw t0, 28(sp)            # state[7]  = key[12..15]
   
    lw t0, 16(s0)
    sw t0, 32(sp)            # state[8]  = key[16..19]
    
    lw t0, 20(s0)
    sw t0, 36(sp)            # state[9]  = key[20..23]
   
    lw t0, 24(s0)
    sw t0, 40(sp)            # state[10] = key[24..27]
   
    lw t0, 28(s0)
    sw t0, 44(sp)            # state[11] = key[28..31]

    # state[12] = counter
    sw      s1, 48(sp)                      # state[12] = counter

    # state[13..15] = nonce (12 bytes = 3 words)
    lw t0, 0(s2); sw t0, 52(sp)             # state[13] = nonce[0..3]
    lw t0, 4(s2); sw t0, 56(sp)             # state[14] = nonce[4..7]
    lw t0, 8(s2); sw t0, 60(sp)             # state[15] = nonce[8..11]

    # -------------------------------------------------------------------------
    # PASO 2: working_state = state
    # -------------------------------------------------------------------------
    # Copiar sp+0..63 → sp+64..127 (preservar state original)
    li      t1, 0
.Lcopy_state:
    add     t2, sp, t1
    lw      t0, 0(t2)
    sw      t0, 64(t2)          # state[i] = working_state[i]
    addi    t1, t1, 4
    li      t3, 64
    blt     t1, t3, .Lcopy_state

    # -------------------------------------------------------------------------
    # PASO 3: for i = 1 upto 10: inner_block(working_state)
    # -------------------------------------------------------------------------
    li      s4, 10              # 10 iteraciones
.Linner_block_loop:
    mv      a0, sp              # a0 = &working_state
    call    chacha20_inner_block
    addi    s4, s4, -1
    bnez    s4, .Linner_block_loop

    # -------------------------------------------------------------------------
    # PASO 4: working_state += state
    # -------------------------------------------------------------------------
    li      t3, 0
.Ladd_state:
    add     t4, sp, t3
    lw      t0, 0(t4)           # t0 = working_state[i]
    lw      t1, 64(t4)          # t1 = state[i]
    add     t0, t0, t1          # working_state[i] += state[i]
    sw      t0, 0(t4)
    addi    t3, t3, 4
    li      t5, 64
    blt     t3, t5, .Ladd_state

    # -------------------------------------------------------------------------
    # PASO 5: return serialize(working_state)
    # -------------------------------------------------------------------------
    li      t3, 0
.Lserialize:
    add     t4, sp, t3
    lw      t0, 0(t4)           # t0 = working_state[i]
    add     t5, s3, t3
    sw      t0, 0(t5)           # output[i] = working_state[i]
    addi    t3, t3, 4
    li      t5, 64
    blt     t3, t5, .Lserialize

    # --- Epílogo ---
    lw      s4, 152(sp)
    lw      s3, 156(sp)
    lw      s2, 160(sp)
    lw      s1, 164(sp)
    lw      s0, 168(sp)
    lw      ra, 172(sp)
    addi    sp, sp, 176
    ret

# =============================================================================
# chacha20_encrypt
# =============================================================================
# Cifra (o descifra) un mensaje de longitud arbitraria.
# RFC 8439, Sección 2.4:
#   - Por cada bloque de 64 bytes: generar keystream con chacha20_block
#   - XOR del keystream con el bloque de plaintext → ciphertext
# =============================================================================
.globl chacha20_encrypt
.type  chacha20_encrypt, @function
chacha20_encrypt:
    addi sp, sp, -92
    sw   ra,  88(sp)
    sw   s0,  84(sp)
    sw   s1,  80(sp)
    sw   s2,  76(sp)
    sw   s3,  72(sp)
    sw   s4,  68(sp)
    sw   s5,  64(sp)

    mv   s0, a0             # s0 = puntero a key
    mv   s1, a1             # s1 = contador actual
    mv   s2, a2             # s2 = puntero a nonce
    mv   s3, a3             # s3 = entrada (plaintext)
    mv   s4, a4             # s4 = salida (ciphertext)
    mv   s5, a5             # s5 = cantidad de bytes por cifrar

.Lprocess_next_chunk:
    beqz s5, .Lfinish_encrypt

    # Construir bloque de keystream en el espacio local del stack
    mv   a0, s0             # key
    mv   a1, s1             # counter
    mv   a2, s2             # nonce
    addi a3, sp, 0          # destino del bloque generado
    call chacha20_block

    # Se procesan hasta 64 bytes o lo que quede pendiente
    li   t0, 0              # índice dentro del bloque
    li   t1, 64             # tamaño máximo del bloque ChaCha20

.Lbyte_mix_loop:
    bgeu t0, s5, .Lend_byte_mix   # salir si ya no quedan bytes
    bgeu t0, t1, .Lend_byte_mix   # salir si ya se procesaron 64 bytes

    add  t2, s3, t0         # dirección de plaintext[i]
    lbu  t3, 0(t2)          # cargar byte del mensaje

    add  t2, sp, t0         # dirección de keystream[i]
    lbu  t4, 0(t2)          # cargar byte del flujo de clave

    xor  t3, t3, t4         # byte cifrado = mensaje XOR keystream

    add  t2, s4, t0         # dirección de ciphertext[i]
    sb   t3, 0(t2)          # escribir resultado

    addi t0, t0, 1
    j    .Lbyte_mix_loop

.Lend_byte_mix:
    # Mover punteros según los bytes ya transformados
    add  s3, s3, t0         # avanzar entrada
    add  s4, s4, t0         # avanzar salida
    sub  s5, s5, t0         # descontar bytes ya cifrados

    addi s1, s1, 10          # siguiente bloque => incrementar contador
    j    .Lprocess_next_chunk

.Lfinish_encrypt:
    lw   s5,  64(sp)
    lw   s4,  68(sp)
    lw   s3,  72(sp)
    lw   s2,  76(sp)
    lw   s1,  80(sp)
    lw   s0,  84(sp)
    lw   ra,  88(sp)
    addi sp, sp, 92
    ret

