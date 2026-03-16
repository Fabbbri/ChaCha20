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
// TEST 1: Quarter Round (RFC 8439 Section 2.1.1)
// =============================================================================
// Vector de prueba del RFC:
//   Input:  a=0x11111111, b=0x01020304, c=0x9b8d6f43, d=0x01234567
//   Output: a=0xea2a92f4, b=0xcb1cf8ce, c=0x4581472e, d=0x5881c4bb
// =============================================================================
void test_quarter_round(void) {
    print_string("\n=== TEST 1: Quarter Round (RFC 8439 Section 2.1.1) ===\n");

    uint32_t state[4];
    state[0] = 0x11111111;
    state[1] = 0x01020304;
    state[2] = 0x9b8d6f43;
    state[3] = 0x01234567;

    print_string("Input:\n");
    print_string("  a = 0x"); print_hex_word(state[0]); print_char('\n');
    print_string("  b = 0x"); print_hex_word(state[1]); print_char('\n');
    print_string("  c = 0x"); print_hex_word(state[2]); print_char('\n');
    print_string("  d = 0x"); print_hex_word(state[3]); print_char('\n');

    chacha20_quarter_round(state, 0, 1, 2, 3);

    print_string("Output:\n");
    print_string("  a = 0x"); print_hex_word(state[0]); print_char('\n');
    print_string("  b = 0x"); print_hex_word(state[1]); print_char('\n');
    print_string("  c = 0x"); print_hex_word(state[2]); print_char('\n');
    print_string("  d = 0x"); print_hex_word(state[3]); print_char('\n');

    print_string("Expected:\n");
    print_string("  a = 0xea2a92f4\n");
    print_string("  b = 0xcb1cf8ce\n");
    print_string("  c = 0x4581472e\n");
    print_string("  d = 0x5881c4bb\n");

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
// TEST 2: ChaCha20 Block (RFC 8439 Appendix A.1, Test Vector #1)
// =============================================================================
// Vector de prueba:
//   Key:     32 bytes de ceros
//   Nonce:   12 bytes de ceros
//   Counter: 0
//   Output:  76 b8 e0 ad ... (64 bytes)
// =============================================================================
void test_chacha20_block(void) {
    print_string("\n=== TEST 2: ChaCha20 Block (RFC 8439 Appendix A.1, TV #1) ===\n");

    // Key: 32 bytes de ceros
    uint8_t key[32];
    for (int i = 0; i < 32; i++) key[i] = 0x00;

    // Nonce: 12 bytes de ceros
    uint8_t nonce[12];
    for (int i = 0; i < 12; i++) nonce[i] = 0x00;

    uint32_t counter = 0;

    uint8_t output[64];

    // Expected output (RFC 8439 Appendix A.1, Test Vector #1)
    static const uint8_t expected[64] = {
        0x76, 0xb8, 0xe0, 0xad, 0xa0, 0xf1, 0x3d, 0x90,
        0x40, 0x5d, 0x6a, 0xe5, 0x53, 0x86, 0xbd, 0x28,
        0xbd, 0xd2, 0x19, 0xb8, 0xa0, 0x8d, 0xed, 0x1a,
        0xa8, 0x36, 0xef, 0xcc, 0x8b, 0x77, 0x0d, 0xc7,
        0xda, 0x41, 0x59, 0x7c, 0x51, 0x57, 0x48, 0x8d,
        0x77, 0x24, 0xe0, 0x3f, 0xb8, 0xd8, 0x4a, 0x37,
        0x6a, 0x43, 0xb8, 0xf4, 0x15, 0x18, 0xa1, 0x1c,
        0xc3, 0x87, 0xb6, 0x69, 0xb2, 0xee, 0x65, 0x86
    };

    chacha20_block(key, counter, nonce, output);

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

    int pass = 1;
    for (int i = 0; i < 64; i++) {
        if (output[i] != expected[i]) {
            pass = 0;
            print_string("Mismatch at byte ");
            print_hex_byte((uint8_t)i);
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
// TEST 3: ChaCha20 Encrypt + Decrypt, mensaje de 3+ bloques (RFC 8439 A.2 TV #2)
// =============================================================================
// Vector de prueba:
//   Key:     31 bytes de ceros seguidos de 0x01 (32 bytes total)
//   Nonce:   11 bytes de ceros seguidos de 0x02 (12 bytes total)
//   Counter: 1
//   Mensaje: 200 bytes (3 bloques completos + 8 bytes) del texto IETF boilerplate
//            del Appendix A.2, Test Vector #2 del RFC 8439
//
// Se verifican los primeros 200 bytes del cifrado contra el RFC y luego
// se descifra para comprobar que decrypt(encrypt(P)) == P.
// =============================================================================
void test_chacha20_encrypt_decrypt(void) {
    print_string("\n=== TEST 3: ChaCha20 Encrypt+Decrypt 3+ bloques (RFC 8439 A.2 TV #2) ===\n");

    // Key: 31 bytes 0x00 + 0x01, almacenado como palabras little-endian
    uint32_t key[8];
    key[0] = 0x00000000;
    key[1] = 0x00000000;
    key[2] = 0x00000000;
    key[3] = 0x00000000;
    key[4] = 0x00000000;
    key[5] = 0x00000000;
    key[6] = 0x00000000;
    key[7] = 0x01000000;

    // Nonce: 11 bytes 0x00 + 0x02, almacenado como palabras little-endian
    uint32_t nonce[3];
    nonce[0] = 0x00000000;
    nonce[1] = 0x00000000;
    nonce[2] = 0x02000000;

    uint32_t counter = 1;

    // Plaintext: primeros 200 bytes del texto IETF boilerplate (RFC 8439 A.2 TV #2)
    // "Any submission to the IETF intended by the Contributor for publication as
    //  all or part of an IETF Internet-Draft or RFC and any statement made within
    //  the context of an IETF activity is considered an \"IETF Contribution\"."
    static const uint8_t plaintext[200] = {
        0x41, 0x6e, 0x79, 0x20, 0x73, 0x75, 0x62, 0x6d, 0x69, 0x73, 0x73, 0x69, 0x6f, 0x6e, 0x20, 0x74,
        0x6f, 0x20, 0x74, 0x68, 0x65, 0x20, 0x49, 0x45, 0x54, 0x46, 0x20, 0x69, 0x6e, 0x74, 0x65, 0x6e,
        0x64, 0x65, 0x64, 0x20, 0x62, 0x79, 0x20, 0x74, 0x68, 0x65, 0x20, 0x43, 0x6f, 0x6e, 0x74, 0x72,
        0x69, 0x62, 0x75, 0x74, 0x6f, 0x72, 0x20, 0x66, 0x6f, 0x72, 0x20, 0x70, 0x75, 0x62, 0x6c, 0x69,
        0x63, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x20, 0x61, 0x73, 0x20, 0x61, 0x6c, 0x6c, 0x20, 0x6f, 0x72,
        0x20, 0x70, 0x61, 0x72, 0x74, 0x20, 0x6f, 0x66, 0x20, 0x61, 0x6e, 0x20, 0x49, 0x45, 0x54, 0x46,
        0x20, 0x49, 0x6e, 0x74, 0x65, 0x72, 0x6e, 0x65, 0x74, 0x2d, 0x44, 0x72, 0x61, 0x66, 0x74, 0x20,
        0x6f, 0x72, 0x20, 0x52, 0x46, 0x43, 0x20, 0x61, 0x6e, 0x64, 0x20, 0x61, 0x6e, 0x79, 0x20, 0x73,
        0x74, 0x61, 0x74, 0x65, 0x6d, 0x65, 0x6e, 0x74, 0x20, 0x6d, 0x61, 0x64, 0x65, 0x20, 0x77, 0x69,
        0x74, 0x68, 0x69, 0x6e, 0x20, 0x74, 0x68, 0x65, 0x20, 0x63, 0x6f, 0x6e, 0x74, 0x65, 0x78, 0x74,
        0x20, 0x6f, 0x66, 0x20, 0x61, 0x6e, 0x20, 0x49, 0x45, 0x54, 0x46, 0x20, 0x61, 0x63, 0x74, 0x69,
        0x76, 0x69, 0x74, 0x79, 0x20, 0x69, 0x73, 0x20, 0x63, 0x6f, 0x6e, 0x73, 0x69, 0x64, 0x65, 0x72,
        0x65, 0x64, 0x20, 0x61, 0x6e, 0x20, 0x22, 0x49
    };

    // Expected ciphertext (RFC 8439 Appendix A.2, Test Vector #2, primeros 200 bytes)
    static const uint8_t expected[200] = {
        0xa3, 0xfb, 0xf0, 0x7d, 0xf3, 0xfa, 0x2f, 0xde, 0x4f, 0x37, 0x6c, 0xa2, 0x3e, 0x82, 0x73, 0x70,
        0x41, 0x60, 0x5d, 0x9f, 0x4f, 0x4f, 0x57, 0xbd, 0x8c, 0xff, 0x2c, 0x1d, 0x4b, 0x79, 0x55, 0xec,
        0x2a, 0x97, 0x94, 0x8b, 0xd3, 0x72, 0x29, 0x15, 0xc8, 0xf3, 0xd3, 0x37, 0xf7, 0xd3, 0x70, 0x05,
        0x0e, 0x9e, 0x96, 0xd6, 0x47, 0xb7, 0xc3, 0x9f, 0x56, 0xe0, 0x31, 0xca, 0x5e, 0xb6, 0x25, 0x0d,
        0x40, 0x42, 0xe0, 0x27, 0x85, 0xec, 0xec, 0xfa, 0x4b, 0x4b, 0xb5, 0xe8, 0xea, 0xd0, 0x44, 0x0e,
        0x20, 0xb6, 0xe8, 0xdb, 0x09, 0xd8, 0x81, 0xa7, 0xc6, 0x13, 0x2f, 0x42, 0x0e, 0x52, 0x79, 0x50,
        0x42, 0xbd, 0xfa, 0x77, 0x73, 0xd8, 0xa9, 0x05, 0x14, 0x47, 0xb3, 0x29, 0x1c, 0xe1, 0x41, 0x1c,
        0x68, 0x04, 0x65, 0x55, 0x2a, 0xa6, 0xc4, 0x05, 0xb7, 0x76, 0x4d, 0x5e, 0x87, 0xbe, 0xa8, 0x5a,
        0xd0, 0x0f, 0x84, 0x49, 0xed, 0x8f, 0x72, 0xd0, 0xd6, 0x62, 0xab, 0x05, 0x26, 0x91, 0xca, 0x66,
        0x42, 0x4b, 0xc8, 0x6d, 0x2d, 0xf8, 0x0e, 0xa4, 0x1f, 0x43, 0xab, 0xf9, 0x37, 0xd3, 0x25, 0x9d,
        0xc4, 0xb2, 0xd0, 0xdf, 0xb4, 0x8a, 0x6c, 0x91, 0x39, 0xdd, 0xd7, 0xf7, 0x69, 0x66, 0xe9, 0x28,
        0xe6, 0x35, 0x55, 0x3b, 0xa7, 0x6c, 0x5c, 0x87, 0x9d, 0x7b, 0x35, 0xd4, 0x9e, 0xb2, 0xe6, 0x2b,
        0x08, 0x71, 0xcd, 0xac, 0x63, 0x89, 0x39, 0xe2
    };

    uint8_t ciphertext[200];
    uint8_t decrypted[200];

    // --- Cifrado ---
    chacha20_encrypt(key, counter, nonce, plaintext, ciphertext, 200);

    print_string("Ciphertext (primeros 16 bytes):\n  ");
    for (int i = 0; i < 16; i++) {
        print_hex_byte(ciphertext[i]);
        print_char(' ');
    }
    print_char('\n');

    print_string("Expected  (primeros 16 bytes):\n  ");
    for (int i = 0; i < 16; i++) {
        print_hex_byte(expected[i]);
        print_char(' ');
    }
    print_char('\n');

    int enc_pass = 1;
    for (int i = 0; i < 200; i++) {
        if (ciphertext[i] != expected[i]) {
            enc_pass = 0;
            print_string("Encrypt mismatch at byte ");
            print_hex_byte((uint8_t)i);
            print_string(": got ");
            print_hex_byte(ciphertext[i]);
            print_string(" expected ");
            print_hex_byte(expected[i]);
            print_char('\n');
            break;
        }
    }

    // --- Descifrado: aplicar chacha20_encrypt al ciphertext con los mismos params ---
    chacha20_encrypt(key, counter, nonce, ciphertext, decrypted, 200);

    int dec_pass = 1;
    for (int i = 0; i < 200; i++) {
        if (decrypted[i] != plaintext[i]) {
            dec_pass = 0;
            print_string("Decrypt mismatch at byte ");
            print_hex_byte((uint8_t)i);
            print_string(": got ");
            print_hex_byte(decrypted[i]);
            print_string(" expected ");
            print_hex_byte(plaintext[i]);
            print_char('\n');
            break;
        }
    }

    if (enc_pass && dec_pass) {
        print_string("Result: PASS (200 bytes = 3 bloques completos + 8 bytes)\n");
    } else {
        if (!enc_pass) print_string("Result: FAIL (cifrado incorrecto)\n");
        if (!dec_pass) print_string("Result: FAIL (descifrado incorrecto)\n");
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

    test_quarter_round();
    test_chacha20_block();
    test_chacha20_encrypt_decrypt();

    print_string("\n============================================\n");
    print_string("Tests completed.\n");

    while (1) {
        __asm__ volatile ("nop");
    }

    return 0;
}
