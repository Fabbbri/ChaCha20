.section .text

# =============================================================================
# chacha20_quarter_round (LEAF FUNCTION - optimizada sin prólogo/epílogo)
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
#
# Registros utilizados (todos caller-saved, no requiere guardar/restaurar):
#   a0     = puntero base (preservado para stores finales)
#   a1-a4  = offsets calculados
#   t2-t5  = valores a, b, c, d
#   t0, t1 = temporales para rotaciones
# =============================================================================
.globl chacha20_quarter_round
chacha20_quarter_round:
    # =========================================================================
    # Calcular offsets en bytes (índice * 4)
    # =========================================================================
    slli    a1, a1, 2           # offset_a = a1 * 4
    slli    a2, a2, 2           # offset_b = a2 * 4
    slli    a3, a3, 2           # offset_c = a3 * 4
    slli    a4, a4, 2           # offset_d = a4 * 4

    # =========================================================================
    # Cargar las 4 palabras del estado en registros temporales
    # =========================================================================
    add     t0, a0, a1
    lw      t2, 0(t0)           # t2 = state[a]
    
    add     t0, a0, a2
    lw      t3, 0(t0)           # t3 = state[b]
    
    add     t0, a0, a3
    lw      t4, 0(t0)           # t4 = state[c]
    
    add     t0, a0, a4
    lw      t5, 0(t0)           # t5 = state[d]

    # =========================================================================
    # Quarter Round - Línea 1: a += b; d ^= a; d <<<= 16
    # =========================================================================
    add     t2, t2, t3          # a += b
    xor     t5, t5, t2          # d ^= a
    # d <<<= 16 (rotate left 16 bits)
    slli    t0, t5, 16          # t0 = d << 16
    srli    t1, t5, 16          # t1 = d >> 16
    or      t5, t0, t1          # d = (d << 16) | (d >> 16)

    # =========================================================================
    # Quarter Round - Línea 2: c += d; b ^= c; b <<<= 12
    # =========================================================================
    add     t4, t4, t5          # c += d
    xor     t3, t3, t4          # b ^= c
    # b <<<= 12 (rotate left 12 bits)
    slli    t0, t3, 12          # t0 = b << 12
    srli    t1, t3, 20          # t1 = b >> 20
    or      t3, t0, t1          # b = (b << 12) | (b >> 20)

    # =========================================================================
    # Quarter Round - Línea 3: a += b; d ^= a; d <<<= 8
    # =========================================================================
    add     t2, t2, t3          # a += b
    xor     t5, t5, t2          # d ^= a
    # d <<<= 8 (rotate left 8 bits)
    slli    t0, t5, 8           # t0 = d << 8
    srli    t1, t5, 24          # t1 = d >> 24
    or      t5, t0, t1          # d = (d << 8) | (d >> 24)

    # =========================================================================
    # Quarter Round - Línea 4: c += d; b ^= c; b <<<= 7
    # =========================================================================
    add     t4, t4, t5          # c += d
    xor     t3, t3, t4          # b ^= c
    # b <<<= 7 (rotate left 7 bits)
    slli    t0, t3, 7           # t0 = b << 7
    srli    t1, t3, 25          # t1 = b >> 25
    or      t3, t0, t1          # b = (b << 7) | (b >> 25)

    # =========================================================================
    # Guardar resultados de vuelta al estado
    # =========================================================================
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
# chacha20_inner_block - Executa 8 quarter rounds (1 double round)
# =============================================================================
# Aplica las operaciones column rounds + diagonal rounds sobre el estado
#
# Parámetro:
#   a0 = puntero al array de estado (16 x uint32_t)
#
# RFC 8439 Section 2.3:
#   Column rounds:   QR(0,4,8,12)  QR(1,5,9,13)  QR(2,6,10,14) QR(3,7,11,15)
#   Diagonal rounds: QR(0,5,10,15) QR(1,6,11,12) QR(2,7,8,13)  QR(3,4,9,14)
# =============================================================================
.globl chacha20_inner_block
chacha20_inner_block:
    # Prólogo: guardar ra y s0 (llamamos a quarter_round)
    addi    sp, sp, -8
    sw      ra, 4(sp)
    sw      s0, 0(sp)
    
    mv      s0, a0              # s0 = puntero al estado (preservar)

    # =====================================================================
    # Column Rounds
    # =====================================================================
    # QUARTERROUND(0, 4, 8, 12)
    mv      a0, s0
    li      a1, 0
    li      a2, 4
    li      a3, 8
    li      a4, 12
    call    chacha20_quarter_round

    # QUARTERROUND(1, 5, 9, 13)
    mv      a0, s0
    li      a1, 1
    li      a2, 5
    li      a3, 9
    li      a4, 13
    call    chacha20_quarter_round

    # QUARTERROUND(2, 6, 10, 14)
    mv      a0, s0
    li      a1, 2
    li      a2, 6
    li      a3, 10
    li      a4, 14
    call    chacha20_quarter_round

    # QUARTERROUND(3, 7, 11, 15)
    mv      a0, s0
    li      a1, 3
    li      a2, 7
    li      a3, 11
    li      a4, 15
    call    chacha20_quarter_round

    # =====================================================================
    # Diagonal Rounds
    # =====================================================================
    # QUARTERROUND(0, 5, 10, 15)
    mv      a0, s0
    li      a1, 0
    li      a2, 5
    li      a3, 10
    li      a4, 15
    call    chacha20_quarter_round

    # QUARTERROUND(1, 6, 11, 12)
    mv      a0, s0
    li      a1, 1
    li      a2, 6
    li      a3, 11
    li      a4, 12
    call    chacha20_quarter_round

    # QUARTERROUND(2, 7, 8, 13)
    mv      a0, s0
    li      a1, 2
    li      a2, 7
    li      a3, 8
    li      a4, 13
    call    chacha20_quarter_round

    # QUARTERROUND(3, 4, 9, 14)
    mv      a0, s0
    li      a1, 3
    li      a2, 4
    li      a3, 9
    li      a4, 14
    call    chacha20_quarter_round

    # Epílogo
    lw      s0, 0(sp)
    lw      ra, 4(sp)
    addi    sp, sp, 8
    ret

# =============================================================================
# chacha20_block - RFC 8439 Section 2.3.1
# =============================================================================
# Genera un bloque de 64 bytes de keystream
#
# Pseudocode:
#   chacha20_block(key, counter, nonce):
#       state = constants | key | counter | nonce
#       working_state = state
#       for i = 1 upto 10:
#           inner_block(working_state)
#       working_state += state
#       return serialize(working_state)
#
# Parámetros:
#   a0 = puntero a key (32 bytes)
#   a1 = counter (32 bits)
#   a2 = puntero a nonce (12 bytes)
#   a3 = puntero a buffer de salida (64 bytes)
#
# Layout en memoria (stack):
#   sp+0  a sp+63:  working_state (se modifica con inner_block)
#   sp+64 a sp+127: state (original, se preserva para sumar)
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
    # PASO 1A: state = constants | key | counter | nonce
    # Primero cargamos las constantes "expand 32-byte k" en little-endian
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
    # FIN PASO 1: state = constants | key | counter | nonce
    # El state está construido en sp+0..63 (temporalmente)
    # =========================================================================

    # =========================================================================
    # PASO 2: working_state = state
    # =========================================================================
    # Copiamos sp+0..63 → sp+64..127, luego intercambiamos roles:
    #   - sp+64..127 = state (preservamos el original)
    #   - sp+0..63   = working_state (se modificará con inner_block)
    #
    # Usamos un bucle para copiar las 16 palabras (64 bytes)
    # =========================================================================
    
    li      t1, 0               # t1 = offset en bytes (0, 4, 8, ... 60)
.Lcopy_state:
    add     t2, sp, t1          # t2 = &sp[offset]
    lw      t0, 0(t2)           # t0 = valor en sp+offset
    sw      t0, 64(t2)          # copiar a sp+64+offset (state)
    addi    t1, t1, 4           # offset += 4
    li      t3, 64              # límite: 64 bytes
    blt     t1, t3, .Lcopy_state

    # =========================================================================
    # FIN PASO 2: working_state = state
    # Ahora: sp+0..63 = working_state, sp+64..127 = state (original)
    # =========================================================================

    # =========================================================================
    # PASO 3: for i = 1 upto 10: inner_block(working_state)
    # =========================================================================
    # inner_block ejecuta 8 quarter rounds (RFC 8439):
    #   Column rounds:   QR(0,4,8,12) QR(1,5,9,13) QR(2,6,10,14) QR(3,7,11,15)
    #   Diagonal rounds: QR(0,5,10,15) QR(1,6,11,12) QR(2,7,8,13) QR(3,4,9,14)
    # =========================================================================
    
    li      s4, 10              # s4 = contador de iteraciones (10 veces)

.Linner_block_loop:
    mv      a0, sp              # a0 = puntero al working_state
    call    chacha20_inner_block

    addi    s4, s4, -1          # s4 -= 1
    bnez    s4, .Linner_block_loop  # si s4 != 0, repetir

    # =========================================================================
    # FIN PASO 3: inner_block ejecutado 10 veces sobre working_state
    # =========================================================================

    # TODO: Paso 4 - working_state += state
    # TODO: Paso 5 - return serialize(working_state)

    # Epílogo temporal
    lw      s4, 152(sp)
    lw      s3, 156(sp)
    lw      s2, 160(sp)
    lw      s1, 164(sp)
    lw      s0, 168(sp)
    lw      ra, 172(sp)
    addi    sp, sp, 176
    ret

