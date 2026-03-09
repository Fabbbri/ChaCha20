.section .text

# =============================================================================
# chacha20_quarter_round
# =============================================================================
# Aplica una operación quarter round in-place sobre el array de estado
#
# Parámetros:
#   a0 = puntero al array de estado (16 x uint32_t)
#   a1 = índice a (0-15)
#   a2 = índice b (0-15)
#   a3 = índice c (0-15)
#   a4 = índice d (0-15)
#
# Operaciones Quarter Round (RFC 8439 Section 2.1):
#   a += b; d ^= a; d <<<= 16;
#   c += d; b ^= c; b <<<= 12;
#   a += b; d ^= a; d <<<= 8;
#   c += d; b ^= c; b <<<= 7;
# =============================================================================
.globl chacha20_quarter_round
chacha20_quarter_round:
    # =========================================================================
    # Prólogo: Guardar registros callee-saved
    # =========================================================================
    addi    sp, sp, -24
    sw      ra, 20(sp)
    sw      s0, 16(sp)
    sw      s1, 12(sp)
    sw      s2, 8(sp)
    sw      s3, 4(sp)
    sw      s4, 0(sp)

    # =========================================================================
    # Guardar puntero base y calcular offsets
    # =========================================================================
    mv      s0, a0              # s0 = puntero al estado
    
    # Calcular offsets en bytes (índice * 4)
    slli    a1, a1, 2           # offset_a = a1 * 4
    slli    a2, a2, 2           # offset_b = a2 * 4
    slli    a3, a3, 2           # offset_c = a3 * 4
    slli    a4, a4, 2           # offset_d = a4 * 4

    # =========================================================================
    # Cargar las 4 palabras del estado en registros
    # =========================================================================
    add     t0, s0, a1
    lw      s1, 0(t0)           # s1 = state[a]
    
    add     t0, s0, a2
    lw      s2, 0(t0)           # s2 = state[b]
    
    add     t0, s0, a3
    lw      s3, 0(t0)           # s3 = state[c]
    
    add     t0, s0, a4
    lw      s4, 0(t0)           # s4 = state[d]

    # =========================================================================
    # Quarter Round - Línea 1: a += b; d ^= a; d <<<= 16
    # =========================================================================
    add     s1, s1, s2          # a += b
    xor     s4, s4, s1          # d ^= a
    # d <<<= 16 (rotate left 16 bits)
    slli    t0, s4, 16          # t0 = d << 16
    srli    t1, s4, 16          # t1 = d >> 16
    or      s4, t0, t1          # d = (d << 16) | (d >> 16)

    # =========================================================================
    # Quarter Round - Línea 2: c += d; b ^= c; b <<<= 12
    # =========================================================================
    add     s3, s3, s4          # c += d
    xor     s2, s2, s3          # b ^= c
    # b <<<= 12 (rotate left 12 bits)
    slli    t0, s2, 12          # t0 = b << 12
    srli    t1, s2, 20          # t1 = b >> 20
    or      s2, t0, t1          # b = (b << 12) | (b >> 20)

    # =========================================================================
    # Quarter Round - Línea 3: a += b; d ^= a; d <<<= 8
    # =========================================================================
    add     s1, s1, s2          # a += b
    xor     s4, s4, s1          # d ^= a
    # d <<<= 8 (rotate left 8 bits)
    slli    t0, s4, 8           # t0 = d << 8
    srli    t1, s4, 24          # t1 = d >> 24
    or      s4, t0, t1          # d = (d << 8) | (d >> 24)

    # =========================================================================
    # Quarter Round - Línea 4: c += d; b ^= c; b <<<= 7
    # =========================================================================
    add     s3, s3, s4          # c += d
    xor     s2, s2, s3          # b ^= c
    # b <<<= 7 (rotate left 7 bits)
    slli    t0, s2, 7           # t0 = b << 7
    srli    t1, s2, 25          # t1 = b >> 25
    or      s2, t0, t1          # b = (b << 7) | (b >> 25)

    # =========================================================================
    # Guardar resultados de vuelta al estado
    # =========================================================================
    add     t0, s0, a1
    sw      s1, 0(t0)           # state[a] = s1
    
    add     t0, s0, a2
    sw      s2, 0(t0)           # state[b] = s2
    
    add     t0, s0, a3
    sw      s3, 0(t0)           # state[c] = s3
    
    add     t0, s0, a4
    sw      s4, 0(t0)           # state[d] = s4

    # =========================================================================
    # Epílogo: Restaurar registros y retornar
    # =========================================================================
    lw      s4, 0(sp)
    lw      s3, 4(sp)
    lw      s2, 8(sp)
    lw      s1, 12(sp)
    lw      s0, 16(sp)
    lw      ra, 20(sp)
    addi    sp, sp, 24
    ret

# =============================================================================
# chacha20_block - PASO 1: Inicialización del estado
# =============================================================================
# Genera un bloque de 64 bytes de keystream según RFC 8439 Section 2.3.1
#
# Parámetros:
#   a0 = puntero a la clave (32 bytes)
#   a1 = contador de bloque (32 bits)
#   a2 = puntero al nonce (12 bytes)
#   a3 = puntero al buffer de salida (64 bytes)
#
# Layout del estado en memoria (stack):
#   sp+0  a sp+63:  working_state (16 x uint32)
#   sp+64 a sp+127: initial_state (copia para sumar al final)
# =============================================================================
.globl chacha20_block
chacha20_block:
    # =========================================================================
    # Prólogo: Reservar espacio en stack
    # =========================================================================
    addi    sp, sp, -176        # Decrementar sp para reservar 176 bytes
                                # (el stack crece hacia direcciones bajas)
    # Guardar ra: dirección de retorno.
    sw      ra, 172(sp)         # Guardar return address en sp+172
    
    # Guardar registros callee-saved (s0-s4).
    sw      s0, 168(sp)         # Guardar s0 en sp+168
    sw      s1, 164(sp)         # Guardar s1 en sp+164
    sw      s2, 160(sp)         # Guardar s2 en sp+160
    sw      s3, 156(sp)         # Guardar s3 en sp+156
    sw      s4, 152(sp)         # Guardar s4 en sp+152

    # =========================================================================
    # Copiar parámetros de entrada a registros callee-saved
    # =========================================================================
    mv      s0, a0              # s0 = puntero a la clave (32 bytes)
    mv      s1, a1              # s1 = contador de bloque (uint32)
    mv      s2, a2              # s2 = puntero al nonce (12 bytes)
    mv      s3, a3              # s3 = puntero al buffer de salida (64 bytes)

    # =========================================================================
    # PASO 1A: Cargar constantes en state[0..3]
    # Estas son las constantes "expand 32-byte k" en little-endian
    # =========================================================================
    li      t0, 0x61707865      # "expa" -> state[0]
    sw      t0, 0(sp)

    li      t0, 0x3320646e      # "nd 3" -> state[1]
    sw      t0, 4(sp)

    li      t0, 0x79622d32      # "2-by" -> state[2]
    sw      t0, 8(sp)

    li      t0, 0x6b206574      # "te k" -> state[3]
    sw      t0, 12(sp)

    # =========================================================================
    # PASO 1B: Cargar clave (32 bytes) en state[4..11]
    # La clave se lee como 8 palabras de 32 bits en little-endian
    # =========================================================================
    lw      t0, 0(s0)           # key[0..3]   -> state[4] usar la dirección que está en s0 + desplazamiento 0
    sw      t0, 16(sp)          # Guardar en sp + 16
    
    lw      t0, 4(s0)           # key[4..7]   -> state[5]
    sw      t0, 20(sp)
    
    lw      t0, 8(s0)           # key[8..11]  -> state[6]
    sw      t0, 24(sp)
    
    lw      t0, 12(s0)          # key[12..15] -> state[7]
    sw      t0, 28(sp)
    
    lw      t0, 16(s0)          # key[16..19] -> state[8]
    sw      t0, 32(sp)
    
    lw      t0, 20(s0)          # key[20..23] -> state[9]
    sw      t0, 36(sp)
    
    lw      t0, 24(s0)          # key[24..27] -> state[10]
    sw      t0, 40(sp)
    
    lw      t0, 28(s0)          # key[28..31] -> state[11]
    sw      t0, 44(sp)

    # =========================================================================
    # PASO 1C: Cargar contador en state[12]
    # =========================================================================
    sw      s1, 48(sp)          # counter -> state[12]

    # =========================================================================
    # PASO 1D: Cargar nonce (12 bytes) en state[13..15]
    # =========================================================================
    lw      t0, 0(s2)           # nonce[0..3]  -> state[13]
    sw      t0, 52(sp)
    
    lw      t0, 4(s2)           # nonce[4..7]  -> state[14]
    sw      t0, 56(sp)
    
    lw      t0, 8(s2)           # nonce[8..11] -> state[15]
    sw      t0, 60(sp)

    # =========================================================================
    # FIN PASO 1 - El estado está inicializado en sp+0 a sp+63
    # Próximo paso: Copiar a initial_state (sp+64 a sp+127)
    # =========================================================================

    # =========================================================================
    # PASO 2: Copiar estado inicial
    # =========================================================================
    # Copiamos working_state (sp+0..63) a initial_state (sp+64..127)
    # Esto es necesario porque después de las 20 rondas, el algoritmo
    # requiere sumar el estado inicial al resultado final:
    #   final_state = working_state + initial_state
    #
    # Usamos un bucle para copiar las 16 palabras (64 bytes)
    # =========================================================================
    
    li      t1, 0               # t1 = índice (0, 4, 8, ... 60)
.Lcopy_initial_state:
    add     t2, sp, t1          # t2 = dirección de working_state[i]
    lw      t0, 0(t2)           # t0 = working_state[i]
    addi    t2, t2, 64          # t2 = dirección de initial_state[i] (sp+64+i)
    sw      t0, 0(t2)           # initial_state[i] = working_state[i]
    addi    t1, t1, 4           # i += 4 (siguiente palabra de 32 bits)
    li      t3, 64              # límite: 64 bytes
    blt     t1, t3, .Lcopy_initial_state  # si i < 64, continuar

    # =========================================================================
    # FIN PASO 2 - Estado inicial copiado en sp+64 a sp+127
    # =========================================================================

    # =========================================================================
    # PASO 3: Ejecutar 20 rondas (10 iteraciones de inner_block)
    # =========================================================================
    # Según RFC 8439 Section 2.3.1, inner_block ejecuta 8 quarter rounds:
    #
    #   Column rounds (operan en columnas de la matriz 4x4):
    #     QUARTERROUND(0, 4,  8, 12)  - columna 0
    #     QUARTERROUND(1, 5,  9, 13)  - columna 1
    #     QUARTERROUND(2, 6, 10, 14)  - columna 2
    #     QUARTERROUND(3, 7, 11, 15)  - columna 3
    #
    #   Diagonal rounds (operan en diagonales):
    #     QUARTERROUND(0, 5, 10, 15)  - diagonal principal
    #     QUARTERROUND(1, 6, 11, 12)  - diagonal +1
    #     QUARTERROUND(2, 7,  8, 13)  - diagonal +2
    #     QUARTERROUND(3, 4,  9, 14)  - diagonal +3
    #
    # La matriz 4x4 del estado:
    #    0  1  2  3
    #    4  5  6  7
    #    8  9 10 11
    #   12 13 14 15
    # =========================================================================
    
    li      s4, 10              # s4 = contador de iteraciones (10 veces)

.Linner_block_loop:
    # =====================================================================
    # Column Rounds - operan en columnas verticales
    # =====================================================================
    
    # QUARTERROUND(0, 4, 8, 12) - columna 0
    mv      a0, sp              # a0 = puntero al estado (working_state)
    li      a1, 0               # índice a = 0
    li      a2, 4               # índice b = 4
    li      a3, 8               # índice c = 8
    li      a4, 12              # índice d = 12
    call    chacha20_quarter_round

    # QUARTERROUND(1, 5, 9, 13) - columna 1
    mv      a0, sp
    li      a1, 1
    li      a2, 5
    li      a3, 9
    li      a4, 13
    call    chacha20_quarter_round

    # QUARTERROUND(2, 6, 10, 14) - columna 2
    mv      a0, sp
    li      a1, 2
    li      a2, 6
    li      a3, 10
    li      a4, 14
    call    chacha20_quarter_round

    # QUARTERROUND(3, 7, 11, 15) - columna 3
    mv      a0, sp
    li      a1, 3
    li      a2, 7
    li      a3, 11
    li      a4, 15
    call    chacha20_quarter_round

    # =====================================================================
    # Diagonal Rounds - operan en diagonales
    # =====================================================================
    
    # QUARTERROUND(0, 5, 10, 15) - diagonal principal
    mv      a0, sp
    li      a1, 0
    li      a2, 5
    li      a3, 10
    li      a4, 15
    call    chacha20_quarter_round

    # QUARTERROUND(1, 6, 11, 12) - diagonal +1
    mv      a0, sp
    li      a1, 1
    li      a2, 6
    li      a3, 11
    li      a4, 12
    call    chacha20_quarter_round

    # QUARTERROUND(2, 7, 8, 13) - diagonal +2
    mv      a0, sp
    li      a1, 2
    li      a2, 7
    li      a3, 8
    li      a4, 13
    call    chacha20_quarter_round

    # QUARTERROUND(3, 4, 9, 14) - diagonal +3
    mv      a0, sp
    li      a1, 3
    li      a2, 4
    li      a3, 9
    li      a4, 14
    call    chacha20_quarter_round

    # =====================================================================
    # Decrementar contador y repetir si no hemos terminado
    # =====================================================================
    addi    s4, s4, -1          # s4 -= 1
    bnez    s4, .Linner_block_loop  # si s4 != 0, repetir

    # =========================================================================
    # FIN PASO 3 - Se ejecutaron 20 rondas (10 × 8 quarter rounds)
    # =========================================================================

    # TODO: Paso 4 - Sumar estado inicial
    # TODO: Paso 5 - Serializar salida

    # Epílogo temporal
    lw      s4, 152(sp)
    lw      s3, 156(sp)
    lw      s2, 160(sp)
    lw      s1, 164(sp)
    lw      s0, 168(sp)
    lw      ra, 172(sp)
    addi    sp, sp, 176
    ret

