// =============================================================================
// ChaCha20 Test Program - RFC 8439 Implementation
// =============================================================================
// Programa para probar la implementación de ChaCha20 en ensamblador RISC-V
// =============================================================================

#include <stdint.h>

// =============================================================================
// Minimal libc shims (bare-metal)
// =============================================================================
// GCC may emit calls to memcpy for some optimizations even if the source code
// does not call it explicitly. Provide a small implementation to avoid linking
// against a full libc.
void *memcpy(void *dest, const void *src, unsigned long n) {
    uint8_t *d = (uint8_t *)dest;
    const uint8_t *s = (const uint8_t *)src;
    for (unsigned long i = 0; i < n; i++) {
        d[i] = s[i];
    }
    return dest;
}

// =============================================================================
// Declaraciones de funciones en ensamblador (chacha20.s)
// =============================================================================
extern void chacha20_quarter_round(uint32_t *state, int a, int b, int c, int d);
extern void chacha20_block(uint8_t *key, uint32_t counter, uint8_t *nonce, uint8_t *output);
extern void chacha20_encrypt(const uint32_t *key, uint32_t counter,
                             const uint32_t *nonce,
                             const uint8_t *plaintext, uint8_t *ciphertext,
                             uint32_t len);

// =============================================================================
// Funciones de salida UART (entorno bare-metal)
// =============================================================================
#define UART_BASE 0x10000000

void print_char(char c) {
    volatile char *uart = (volatile char*)UART_BASE;
    *uart = c;
}

void print_string(const char* str) {
    while (*str) {
        print_char(*str++);
    }
}

void print_hex_byte(uint8_t byte) {
    const char hex[] = "0123456789abcdef";
    print_char(hex[(byte >> 4) & 0xF]);
    print_char(hex[byte & 0xF]);
}

void print_hex_word(uint32_t word) {
    // Imprimir en big-endian para legibilidad (MSB primero)
    print_hex_byte((word >> 24) & 0xFF);
    print_hex_byte((word >> 16) & 0xFF);
    print_hex_byte((word >> 8) & 0xFF);
    print_hex_byte(word & 0xFF);
}

// =============================================================================
// TEST: Quarter Round (RFC 8439 Section 2.1.1)
// =============================================================================
// Vector de prueba del RFC:
//   Input:  a=0x11111111, b=0x01020304, c=0x9b8d6f43, d=0x01234567
//   Output: a=0xea2a92f4, b=0xcb1cf8ce, c=0x4581472e, d=0x5881c4bb
// =============================================================================
void test_quarter_round(void) {
    print_string("\n=== TEST: Quarter Round (RFC 8439 2.1.1) ===\n");
    
    // Usamos un array de 16 palabras (estado ChaCha20)
    // Inicialización manual para evitar memset/memcpy en bare-metal
    uint32_t state[16];
    state[0] = 0x11111111;   // a
    state[1] = 0x01020304;   // b
    state[2] = 0x9b8d6f43;   // c
    state[3] = 0x01234567;   // d
    state[4] = 0;
    state[5] = 0;
    state[6] = 0;
    state[7] = 0;
    state[8] = 0;
    state[9] = 0;
    state[10] = 0;
    state[11] = 0;
    state[12] = 0;
    state[13] = 0;
    state[14] = 0;
    state[15] = 0;
    
    print_string("Input:\n");
    print_string("  a = 0x"); print_hex_word(state[0]); print_char('\n');
    print_string("  b = 0x"); print_hex_word(state[1]); print_char('\n');
    print_string("  c = 0x"); print_hex_word(state[2]); print_char('\n');
    print_string("  d = 0x"); print_hex_word(state[3]); print_char('\n');
    
    // Llamar a la función quarter round
    chacha20_quarter_round(state, 0, 1, 2, 3);
    
    print_string("Output:\n");
    print_string("  a = 0x"); print_hex_word(state[0]); print_char('\n');
    print_string("  b = 0x"); print_hex_word(state[1]); print_char('\n');
    print_string("  c = 0x"); print_hex_word(state[2]); print_char('\n');
    print_string("  d = 0x"); print_hex_word(state[3]); print_char('\n');
    
    // Valores esperados según RFC
    print_string("Expected:\n");
    print_string("  a = 0xea2a92f4\n");
    print_string("  b = 0xcb1cf8ce\n");
    print_string("  c = 0x4581472e\n");
    print_string("  d = 0x5881c4bb\n");
    
    // Verificar resultados
    if (state[0] == 0xea2a92f4 && 
        state[1] == 0xcb1cf8ce &&
        state[2] == 0x4581472e && 
        state[3] == 0x5881c4bb) {
        print_string("Result: PASS\n");
    } else {
        print_string("Result: FAIL\n");
    }
}

// =============================================================================
// TEST: ChaCha20 Block (RFC 8439 Section 2.3.2)
// =============================================================================
// Vector de prueba del RFC:
//   Key:     00:01:02:...:1f (32 bytes)
//   Nonce:   00:00:00:09:00:00:00:4a:00:00:00:00 (12 bytes)
//   Counter: 1
//   Output:  10 f1 e7 e4 d1 3b 59 15 ... (64 bytes)
// =============================================================================
void test_chacha20_block(void) {
    print_string("\n=== TEST: ChaCha20 Block (RFC 8439 2.3.2) ===\n");
    
    // Key: 00 01 02 03 ... 1f (32 bytes)
    // Inicialización manual para evitar memcpy en bare-metal
    uint8_t key[32];
    for (int i = 0; i < 32; i++) {
        key[i] = i;  // 0x00, 0x01, 0x02, ... 0x1f
    }
    
    // Nonce: 00 00 00 09 00 00 00 4a 00 00 00 00 (12 bytes)
    uint8_t nonce[12];
    nonce[0] = 0x00; nonce[1] = 0x00; nonce[2] = 0x00; nonce[3] = 0x09;
    nonce[4] = 0x00; nonce[5] = 0x00; nonce[6] = 0x00; nonce[7] = 0x4a;
    nonce[8] = 0x00; nonce[9] = 0x00; nonce[10] = 0x00; nonce[11] = 0x00;
    
    // Counter
    uint32_t counter = 1;
    
    // Output buffer
    uint8_t output[64];
    
    // Expected output (RFC 8439 Section 2.3.2)
    uint8_t expected[64];
    expected[0] = 0x10; expected[1] = 0xf1; expected[2] = 0xe7; expected[3] = 0xe4;
    expected[4] = 0xd1; expected[5] = 0x3b; expected[6] = 0x59; expected[7] = 0x15;
    expected[8] = 0x50; expected[9] = 0x0f; expected[10] = 0xdd; expected[11] = 0x1f;
    expected[12] = 0xa3; expected[13] = 0x20; expected[14] = 0x71; expected[15] = 0xc4;
    expected[16] = 0xc7; expected[17] = 0xd1; expected[18] = 0xf4; expected[19] = 0xc7;
    expected[20] = 0x33; expected[21] = 0xc0; expected[22] = 0x68; expected[23] = 0x03;
    expected[24] = 0x04; expected[25] = 0x22; expected[26] = 0xaa; expected[27] = 0x9a;
    expected[28] = 0xc3; expected[29] = 0xd4; expected[30] = 0x6c; expected[31] = 0x4e;
    expected[32] = 0xd2; expected[33] = 0x82; expected[34] = 0x64; expected[35] = 0x46;
    expected[36] = 0x07; expected[37] = 0x9f; expected[38] = 0xaa; expected[39] = 0x09;
    expected[40] = 0x14; expected[41] = 0xc2; expected[42] = 0xd7; expected[43] = 0x05;
    expected[44] = 0xd9; expected[45] = 0x8b; expected[46] = 0x02; expected[47] = 0xa2;
    expected[48] = 0xb5; expected[49] = 0x12; expected[50] = 0x9c; expected[51] = 0xd1;
    expected[52] = 0xde; expected[53] = 0x16; expected[54] = 0x4e; expected[55] = 0xb9;
    expected[56] = 0xcb; expected[57] = 0xd0; expected[58] = 0x83; expected[59] = 0xe8;
    expected[60] = 0xa2; expected[61] = 0x50; expected[62] = 0x3c; expected[63] = 0x4e;
    
    // Llamar a chacha20_block
    chacha20_block(key, counter, nonce, output);
    
    // Mostrar output
    print_string("Output (primeros 16 bytes):\n  ");
    for (int i = 0; i < 16; i++) {
        print_hex_byte(output[i]);
        print_char(' ');
    }
    print_char('\n');
    
    print_string("Expected:\n  ");
    for (int i = 0; i < 16; i++) {
        print_hex_byte(expected[i]);
        print_char(' ');
    }
    print_char('\n');
    
    // Verificar todos los 64 bytes
    int pass = 1;
    for (int i = 0; i < 64; i++) {
        if (output[i] != expected[i]) {
            pass = 0;
            print_string("Mismatch at byte ");
            print_hex_byte(i);
            print_string(": got ");
            print_hex_byte(output[i]);
            print_string(" expected ");
            print_hex_byte(expected[i]);
            print_char('\n');
            break;
        }
    }
    
    if (pass) {
        print_string("Result: PASS\n");
    } else {
        print_string("Result: FAIL\n");
    }
}

// =============================================================================
// TEST: ChaCha20 Encrypt (RFC 8439 Section 2.4.2)
// =============================================================================
// Test vector "Sunscreen":
//   Key     = 00 01 02 ... 1f
//   Nonce   = 00 00 00 00 00 00 00 4a 00 00 00 00
//   Counter = 1
//   Plaintext/Ciphertext as specified in RFC 8439 §2.4.2
// =============================================================================
void test_chacha20_encrypt(void) {
    print_string("\n=== TEST: ChaCha20 Encrypt (RFC 8439 2.4.2) ===\n");

    // Key bytes 00..1f, stored as little-endian 32-bit words (aligned)
    uint32_t key[8];
    key[0] = 0x03020100;
    key[1] = 0x07060504;
    key[2] = 0x0b0a0908;
    key[3] = 0x0f0e0d0c;
    key[4] = 0x13121110;
    key[5] = 0x17161514;
    key[6] = 0x1b1a1918;
    key[7] = 0x1f1e1d1c;

    // Nonce: 00 00 00 00 00 00 00 4a 00 00 00 00
    uint32_t nonce[3];
    nonce[0] = 0x00000000;
    nonce[1] = 0x4a000000;
    nonce[2] = 0x00000000;

    uint32_t counter = 1;

    static const uint8_t plaintext[114] = {
        0x4c, 0x61, 0x64, 0x69, 0x65, 0x73, 0x20, 0x61, 0x6e, 0x64, 0x20, 0x47, 0x65, 0x6e, 0x74, 0x6c,
        0x65, 0x6d, 0x65, 0x6e, 0x20, 0x6f, 0x66, 0x20, 0x74, 0x68, 0x65, 0x20, 0x63, 0x6c, 0x61, 0x73,
        0x73, 0x20, 0x6f, 0x66, 0x20, 0x27, 0x39, 0x39, 0x3a, 0x20, 0x49, 0x66, 0x20, 0x49, 0x20, 0x63,
        0x6f, 0x75, 0x6c, 0x64, 0x20, 0x6f, 0x66, 0x66, 0x65, 0x72, 0x20, 0x79, 0x6f, 0x75, 0x20, 0x6f,
        0x6e, 0x6c, 0x79, 0x20, 0x6f, 0x6e, 0x65, 0x20, 0x74, 0x69, 0x70, 0x20, 0x66, 0x6f, 0x72, 0x20,
        0x74, 0x68, 0x65, 0x20, 0x66, 0x75, 0x74, 0x75, 0x72, 0x65, 0x2c, 0x20, 0x73, 0x75, 0x6e, 0x73,
        0x63, 0x72, 0x65, 0x65, 0x6e, 0x20, 0x77, 0x6f, 0x75, 0x6c, 0x64, 0x20, 0x62, 0x65, 0x20, 0x69,
        0x74, 0x2e
    };

    static const uint8_t expected[114] = {
        0x6e, 0x2e, 0x35, 0x9a, 0x25, 0x68, 0xf9, 0x80, 0x41, 0xba, 0x07, 0x28, 0xdd, 0x0d, 0x69, 0x81,
        0xe9, 0x7e, 0x7a, 0xec, 0x1d, 0x43, 0x60, 0xc2, 0x0a, 0x27, 0xaf, 0xcc, 0xfd, 0x9f, 0xae, 0x0b,
        0xf9, 0x1b, 0x65, 0xc5, 0x52, 0x47, 0x33, 0xab, 0x8f, 0x59, 0x3d, 0xab, 0xcd, 0x62, 0xb3, 0x57,
        0x16, 0x39, 0xd6, 0x24, 0xe6, 0x51, 0x52, 0xab, 0x8f, 0x53, 0x0c, 0x35, 0x9f, 0x08, 0x61, 0xd8,
        0x07, 0xca, 0x0d, 0xbf, 0x50, 0x0d, 0x6a, 0x61, 0x56, 0xa3, 0x8e, 0x08, 0x8a, 0x22, 0xb6, 0x5e,
        0x52, 0xbc, 0x51, 0x4d, 0x16, 0xcc, 0xf8, 0x06, 0x81, 0x8c, 0xe9, 0x1a, 0xb7, 0x79, 0x37, 0x36,
        0x5a, 0xf9, 0x0b, 0xbf, 0x74, 0xa3, 0x5b, 0xe6, 0xb4, 0x0b, 0x8e, 0xed, 0xf2, 0x78, 0x5e, 0x42,
        0x87, 0x4d
    };

    uint8_t ciphertext[114];
    chacha20_encrypt(key, counter, nonce, plaintext, ciphertext, (uint32_t)sizeof(plaintext));

    print_string("Ciphertext (primeros 16 bytes):\n  ");
    for (int i = 0; i < 16; i++) {
        print_hex_byte(ciphertext[i]);
        print_char(' ');
    }
    print_char('\n');

    print_string("Expected (primeros 16 bytes):\n  ");
    for (int i = 0; i < 16; i++) {
        print_hex_byte(expected[i]);
        print_char(' ');
    }
    print_char('\n');

    int pass = 1;
    for (int i = 0; i < (int)sizeof(expected); i++) {
        if (ciphertext[i] != expected[i]) {
            pass = 0;
            print_string("Mismatch at byte ");
            print_hex_byte((uint8_t)i);
            print_string(": got ");
            print_hex_byte(ciphertext[i]);
            print_string(" expected ");
            print_hex_byte(expected[i]);
            print_char('\n');
            break;
        }
    }

    if (pass) {
        print_string("Result: PASS\n");
    } else {
        print_string("Result: FAIL\n");
    }
}

// =============================================================================
// Main
// =============================================================================
int main(void) {
    print_string("\n");
    print_string("============================================\n");
    print_string("   ChaCha20 RISC-V Implementation Tests    \n");
    print_string("============================================\n");
    
    // Ejecutar prueba de quarter round
    test_quarter_round();
    
    // Ejecutar prueba de chacha20_block
    test_chacha20_block();

    // Ejecutar prueba de chacha20_encrypt
    test_chacha20_encrypt();
    
    print_string("\n============================================\n");
    print_string("Tests completed.\n");
    
    // Loop infinito
    while (1) {
        __asm__ volatile ("nop");
    }
    
    return 0;
}