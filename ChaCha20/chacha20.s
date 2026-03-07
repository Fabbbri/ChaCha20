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