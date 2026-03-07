// =============================================================================
// ChaCha20 Test Program - RFC 8439 Implementation
// =============================================================================
// Programa para probar la implementación de ChaCha20 en ensamblador RISC-V
// =============================================================================

#include <stdint.h>

// =============================================================================
// Declaraciones de funciones en ensamblador (chacha20.s)
// =============================================================================
extern void chacha20_quarter_round(uint32_t *state, int a, int b, int c, int d);

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
    // Colocamos los valores de prueba en posiciones 0, 1, 2, 3
    uint32_t state[16] = {0};
    
    state[0] = 0x11111111;  // a
    state[1] = 0x01020304;  // b
    state[2] = 0x9b8d6f43;  // c
    state[3] = 0x01234567;  // d
    
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
// Main
// =============================================================================
void main(void) {
    print_string("\n");
    print_string("============================================\n");
    print_string("   ChaCha20 RISC-V Implementation Tests    \n");
    print_string("============================================\n");
    
    // Ejecutar prueba de quarter round
    test_quarter_round();
    
    print_string("\n============================================\n");
    print_string("Tests completed.\n");
    
    // Loop infinito
    while (1) {
        __asm__ volatile ("nop");
    }
}
