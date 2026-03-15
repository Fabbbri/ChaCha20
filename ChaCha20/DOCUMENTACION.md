# Documentación Técnica - ChaCha20 RISC-V

## Índice

1. [Arquitectura del Software](#1-arquitectura-del-software)
2. [Mapeo de Registros RISC-V](#2-mapeo-de-registros-risc-v)
3. [Evidencias de Ejecución](#3-evidencias-de-ejecución)
4. [Bitácora de Bug](#4-bitácora-de-bug)
5. [Análisis de Resultados](#5-análisis-de-resultados)

---

## 1. Arquitectura del Software

### 1.1 Separación entre Capas C y Ensamblador

El proyecto implementa una arquitectura de **dos capas** que separa las responsabilidades:

```
┌─────────────────────────────────────────────────────────────┐
│                    CAPA C (main.c)                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │    Tests    │  │   I/O UART  │  │  Vectores de Prueba │  │
│  │  RFC 8439   │  │ print_char  │  │  (RFC 8439 2.1.1)   │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                           │                                 │
│                           ▼                                 │
│              ┌────────────────────────┐                     │
│              │   Llamada a función    │                     │
│              │   chacha20_quarter_    │                     │
│              │   round(state,a,b,c,d) │                     │
│              └────────────────────────┘                     │
└─────────────────────────┬───────────────────────────────────┘
                          │ ABI RISC-V (a0-a4)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│               CAPA ENSAMBLADOR (chacha20.s)                 │
│  ┌─────────────────────────────────────────────────────┐    │
│  │           chacha20_quarter_round                    │    │
│  │  • Operaciones bitwise (XOR, rotaciones)            │    │
│  │  • Manipulación directa de registros                │    │
│  │  • Optimización a nivel de instrucción              │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              chacha20_block                         │    │
│  │  • Construcción del estado inicial                  │    │
│  │  • 20 rondas (10 iteraciones × 8 quarter rounds)    │    │
│  │  • Serialización del keystream                      │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│               INFRAESTRUCTURA (startup.s + linker.ld)       │
│  • Inicialización del stack pointer                         │
│  • Llamada a main()                                         │
│  • Mapeo de memoria (base 0x80000000)                       │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Interfaces Definidas

#### Interface C → Ensamblador

```c
// Declaración en C (main.c)
extern void chacha20_quarter_round(uint32_t *state, int a, int b, int c, int d);
```

**Convención de llamada RISC-V (ILP32):**

| Parámetro | Registro | Descripción |
|-----------|----------|-------------|
| `state`   | `a0`     | Puntero al array de 16 palabras (64 bytes) |
| `a`       | `a1`     | Índice de la primera palabra (0-15) |
| `b`       | `a2`     | Índice de la segunda palabra (0-15) |
| `c`       | `a3`     | Índice de la tercera palabra (0-15) |
| `d`       | `a4`     | Índice de la cuarta palabra (0-15) |

#### Interface UART (bare-metal)

```c
#define UART_BASE 0x10000000

void print_char(char c);      // Escribe un carácter a UART
void print_string(const char* str);
void print_hex_word(uint32_t word);
```

### 1.3 Justificación de Decisiones de Diseño

| Decisión | Justificación |
|----------|---------------|
| **Quarter Round en ensamblador** | Las operaciones de rotación (`<<<`) no existen nativamente en RISC-V base (RV32IM). Implementarlas en ensamblador permite control preciso sobre `slli`/`srli` con OR. |
| **Tests y I/O en C** | El código de verificación y salida UART es más legible y mantenible en C. No es crítico para el rendimiento. |
| **Estado en stack** | El estado de 64 bytes se almacena en el stack frame de `chacha20_block`, evitando fragmentación del heap y garantizando alineación. |
| **Registros callee-saved (s0-s4)** | Preservar valores entre llamadas a funciones. Crítico para el bucle de 10 iteraciones de `inner_block`. |
| **Índices como parámetros** | Permite reutilizar `chacha20_quarter_round` para columnas y diagonales sin duplicar código. |

---

## 2. Mapeo de Registros RISC-V

### 2.1 Estado ChaCha20 (16 palabras de 32 bits)

El estado de ChaCha20 se organiza como una matriz 4×4:

```
     Columna 0   Columna 1   Columna 2   Columna 3
    ┌──────────┬──────────┬──────────┬──────────┐
    │ state[0] │ state[1] │ state[2] │ state[3] │  ← Constantes "expand 32-byte k"
    ├──────────┼──────────┼──────────┼──────────┤
    │ state[4] │ state[5] │ state[6] │ state[7] │  ← Key[0..15]
    ├──────────┼──────────┼──────────┼──────────┤
    │ state[8] │ state[9] │ state[10]│ state[11]│  ← Key[16..31]
    ├──────────┼──────────┼──────────┼──────────┤
    │ state[12]│ state[13]│ state[14]│ state[15]│  ← Counter | Nonce
    └──────────┴──────────┴──────────┴──────────┘
```

### 2.2 Mapeo en `chacha20_quarter_round`

Durante la ejecución del quarter round, las 4 palabras se cargan en registros:

| Registro | Contenido | Razón |
|----------|-----------|-------|
| `s0` | Puntero base al estado | Preservado para escribir resultados de vuelta |
| `s1` | `state[a]` | Palabra "a" del quarter round |
| `s2` | `state[b]` | Palabra "b" del quarter round |
| `s3` | `state[c]` | Palabra "c" del quarter round |
| `s4` | `state[d]` | Palabra "d" del quarter round |
| `t0`, `t1` | Temporales para rotación | Cálculo de `(x << n) | (x >> (32-n))` |
| `a1`-`a4` | Offsets calculados | `índice × 4` para acceso a memoria |

**¿Por qué registros `s0-s4`?**

Los registros `s0-s11` son **callee-saved** en RISC-V, lo que significa que la función debe preservar su valor. Esto es necesario porque:

1. El estado debe mantenerse durante las 4 operaciones del quarter round
2. `chacha20_block` llama a `chacha20_quarter_round` 80 veces (10 iteraciones × 8 QR)
3. Los registros preservados evitan recargar valores de memoria

### 2.3 Mapeo en `chacha20_block`

```
Stack Frame (176 bytes):
┌─────────────────────────────────────────────┐ sp + 176
│ [padding para alineación]                   │
├─────────────────────────────────────────────┤ sp + 172
│ ra (return address)                         │
├─────────────────────────────────────────────┤ sp + 168
│ s0 (puntero a key)                          │
├─────────────────────────────────────────────┤ sp + 164
│ s1 (counter)                                │
├─────────────────────────────────────────────┤ sp + 160
│ s2 (puntero a nonce)                        │
├─────────────────────────────────────────────┤ sp + 156
│ s3 (puntero a buffer salida)                │
├─────────────────────────────────────────────┤ sp + 152
│ s4 (contador de iteraciones)                │
├─────────────────────────────────────────────┤ sp + 128
│                                             │
│ [espacio reservado]                         │
│                                             │
├─────────────────────────────────────────────┤ sp + 64
│                                             │
│ state[0..15] - Estado ORIGINAL              │
│ (64 bytes - preservado para suma final)     │
│                                             │
├─────────────────────────────────────────────┤ sp + 0
│                                             │
│ working_state[0..15] - Estado de TRABAJO    │
│ (64 bytes - modificado por quarter rounds)  │
│                                             │
└─────────────────────────────────────────────┘ sp
```

| Registro | Uso en `chacha20_block` |
|----------|-------------------------|
| `s0` | Puntero a key (32 bytes) |
| `s1` | Valor del counter |
| `s2` | Puntero a nonce (12 bytes) |
| `s3` | Puntero a buffer de salida |
| `s4` | Contador de iteraciones (10 → 0) |
| `sp` | Puntero al working_state |
| `sp+64` | Puntero al state original |

### 2.4 Operación de Rotación (sin instrucción nativa)

RISC-V RV32IM no tiene instrucción de rotación. Se implementa con:

```asm
# Rotación izquierda de 16 bits: d <<<= 16
slli    t0, s4, 16      # t0 = d << 16
srli    t1, s4, 16      # t1 = d >> 16
or      s4, t0, t1      # d = (d << 16) | (d >> 16)
```

**Patrón general para `x <<<= n`:**
```asm
slli    t0, x, n        # t0 = x << n
srli    t1, x, (32-n)   # t1 = x >> (32-n)
or      x, t0, t1       # x = t0 | t1
```

---

## 3. Evidencias de Ejecución


---

## 4. Bitácora de Bug: Incremento Incorrecto del Contador en `chacha20_encrypt`

### Descripción del error

Durante el desarrollo de `chacha20_encrypt`, se introdujo un error en la lógica de actualización del contador de bloque. Al finalizar el procesamiento de cada chunk de 64 bytes, el contador debía incrementarse en **1**, pero por error se escribió el valor inmediato `10` en lugar de `1`:
```riscv
# Código incorrecto
add s1, s1, 10        # ← debía ser 1, no 10

# Código correcto
add s1, s1, 1
` `` 

El efecto fue que, a partir del segundo bloque, el contador tomaba valores completamente erróneos (1 → 11 → 21 → ...), lo que producía un keystream incorrecto y hacía fallar la prueba `ChaCha20 Encrypt (RFC 8439 2.4.2)` desde el byte 40 en adelante, como se observa en la siguiente captura:

![Resultado de pruebas con FAIL en Encrypt](./images/EvidenciaGDB.png)
```
Mismatch at byte 40: got d4 expected 07
Result: FAIL
` ``

Los primeros 40 bytes coincidían porque pertenecen al **primer bloque**, cuyo contador inicial es correcto. El error solo se manifestaba a partir del segundo bloque.

---

### Detección

El error fue identificado inicialmente mediante **revisión directa del código fuente**: al releer la lógica de avance de punteros y actualización del contador, la constante `10` resultó obviamente incorrecta en ese contexto.

Sin embargo, para confirmar el comportamiento en ejecución y familiarizarse con el uso de GDB sobre RISC-V/QEMU, se instrumentó una sesión de depuración con breakpoints condicionales que imprimían el valor del registro `s1` (contador) antes y después de cada actualización, así como al entrar a `chacha20_block`:
```gdb
break chacha20.s:203
commands
    silent
    printf "\n[chacha20_block] counter(s1)=0x%08x (%u)  a1(arg)=0x%08x (%u)\n", $s1, $s1, $a1, $a1
    continue
end

break chacha20.s:373
commands
    silent
    printf "\n[chacha20_encrypt] BEFORE update s1=0x%08x (%u)\n", $s1, $s1
    continue
end

break chacha20.s:374
commands
    silent
    printf "[chacha20_encrypt] AFTER  update s1=0x%08x (%u)\n", $s1, $s1
    continue
end
` ``

La salida de GDB confirmó el comportamiento incorrecto: el contador saltaba de `1` a `11` en la primera actualización, y de `11` a `21` en la segunda, en lugar de incrementarse de uno en uno:
```
[chacha20_block] counter(s1)=0x00000001 (1)   a1(arg)=0x00000001 (1)

[chacha20_encrypt] BEFORE update s1=0x00000001 (1)
[chacha20_encrypt] AFTER  update s1=0x0000000b (11)

[chacha20_block] counter(s1)=0x0000000b (11)  a1(arg)=0x0000000b (11)

[chacha20_encrypt] BEFORE update s1=0x0000000b (11)
[chacha20_encrypt] AFTER  update s1=0x00000015 (21)
` ``

![Sesión GDB mostrando salto incorrecto del contador](./images/EvidenciaGDB1.png)

---

### Corrección

Se reemplazó el inmediato incorrecto:
```riscv
# Antes (incorrecto)
add s1, s1, 10

# Después (correcto)
add s1, s1, 1
` ``

Tras la corrección, la prueba de cifrado pasó satisfactoriamente, y los tres tests del RFC (Quarter Round, Block y Encrypt) produjeron `Result: PASS`.

---

### Lección aprendida

Un error tipográfico en una constante inmediata puede ser invisible a simple vista durante la escritura, pero se manifiesta de forma reproducible y trazable con GDB. Instrumentar los puntos de actualización de estado con `printf` desde los `commands` de un breakpoint permite verificar la evolución de registros clave sin interrumpir manualmente la ejecución, lo que resulta especialmente útil en bucles de múltiples iteraciones.
```

> **Nota:** ajustá las rutas de las imágenes (`./images/EvidenciaGDB.png`) según donde las tengas en tu repositorio. Los triple backtick internos los escribí con un espacio para no romper el bloque exterior — quitá ese espacio al pegarlo.
---

## 5. Análisis de Resultados


---

