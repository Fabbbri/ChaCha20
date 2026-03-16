# Documentación Técnica

## Índice

1. [Arquitectura del Software](#1-arquitectura-del-software)
2. [Mapeo de Registros RISC-V](#2-mapeo-de-registros-risc-v)
3. [Evidencias de Ejecución](#3-evidencias-de-ejecución)
4. [Bitácora de Bug](#4-bitácora-de-bug)
5. [Análisis de Resultados](#5-análisis-de-resultados)

---

## 1. Arquitectura del Software

### 1.1 Separación entre Capas C y Ensamblador

El proyecto implementa una arquitectura de **tres capas** con responsabilidades claramente delimitadas:

```
┌──────────────────────────────────────────────────────────────────┐
│                      CAPA C  (main.c)                            │
│                                                                  │
│  ┌──────────────────┐  ┌────────────────┐  ┌──────────────────┐  │
│  │  Tests RFC 8439  │  │ I/O UART       │  │ Vectores de      │  │
│  │  · QR 2.1.1      │  │ print_char()   │  │ prueba (A.1/A.2) │  │
│  │  · Block A.1     │  │ print_string() │  │ arrays estáticos │  │
│  │  · Encrypt A.2   │  │ print_hex_*()  │  │ const uint8_t[]  │  │
│  └──────────────────┘  └────────────────┘  └──────────────────┘  │
│                                                                  │
│       Responsabilidad: orquestación, verificación, I/O           │
└──────────────────────────────────┬───────────────────────────────┘
                                   │  ABI RISC-V ILP32
                                   │  (argumentos en a0–a5,
                                   │   resultado en a0)
                                   ▼
┌──────────────────────────────────────────────────────────────────┐
│                 CAPA ENSAMBLADOR  (chacha20.s)                    │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  chacha20_quarter_round  (.globl, llamable desde C)      │    │
│  │  · Recibe: state_ptr (a0), 4 índices (a1–a4)             │    │
│  │  · Opera sobre 4 palabras de estado en registros t2–t5   │    │
│  │  · Sin prologue/epilogue propio (sin llamadas internas)   │    │
│  └──────────────────────────────────────────────────────────┘    │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  chacha20_inner_block  (helper interno, .globl)          │    │
│  │  · Ejecuta las 8 QRs de un double-round (columnas +      │    │
│  │    diagonales) llamando a chacha20_quarter_round         │    │
│  │  · Preserva state_ptr en s0 entre cada una de las 8      │    │
│  │    llamadas (a0 se destruye en cada call)                │    │
│  └──────────────────────────────────────────────────────────┘    │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  chacha20_block  (.globl, llamable desde C)              │    │
│  │  · Recibe: key (a0), counter (a1), nonce (a2), out (a3)  │    │
│  │  · Construye estado inicial en stack (sp+0..63)          │    │
│  │  · Copia a estado original (sp+64..127) para suma final  │    │
│  │  · Llama chacha20_inner_block 10 veces (s4 = contador)   │    │
│  │  · Suma estado original al working_state y serializa     │    │
│  └──────────────────────────────────────────────────────────┘    │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  chacha20_encrypt  (.globl, llamable desde C)            │    │
│  │  · Recibe: key (a0), counter (a1), nonce (a2),           │    │
│  │            plaintext (a3), ciphertext (a4), len (a5)     │    │
│  │  · Loop: genera bloque de 64 bytes en stack local,       │    │
│  │    hace XOR byte a byte con el mensaje                   │    │
│  │  · Incrementa contador (s1) en 1 por bloque              │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                  │
│       Responsabilidad: toda la criptografía y velocidad          │
└──────────────────────────────────┬───────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────┐
│              INFRAESTRUCTURA  (startup.s + linker.ld)            │
│  · startup.s: inicializa sp a top-of-RAM, invoca main()          │
│  · linker.ld: sitúa .text en 0x80000000 (RAM de QEMU virt),      │
│               define heap/stack y símbolo _start                 │
└──────────────────────────────────────────────────────────────────┘
```

La separación entre la capa C y la capa ensamblador es una **frontera semántica**: todo lo que requiere control a nivel de instrucción o que opera sobre el estado interno del cifrado está en `chacha20.s`; todo lo que es verificación, presentación de resultados o configuración de parámetros está en `main.c`. Las dos capas solo se comunican a través de las tres funciones públicas documentadas a continuación.

### 1.2 Interfaces Definidas

Las tres funciones exportadas desde `chacha20.s` constituyen la única superficie de contacto entre ambas capas. Su firma en C y la convención de llamada RISC-V ILP32 son las siguientes:

#### `chacha20_quarter_round` — primitiva criptográfica

```c
extern void chacha20_quarter_round(uint32_t *state, int a, int b, int c, int d);
```

| Parámetro | Registro | Contenido |
|-----------|----------|-----------|
| `state`   | `a0`     | Puntero al array de estado (16 × 4 bytes = 64 bytes) |
| `a`       | `a1`     | Índice (0–15) de la palabra que actúa como `a` en el QR |
| `b`       | `a2`     | Índice de la palabra `b` |
| `c`       | `a3`     | Índice de la palabra `c` |
| `d`       | `a4`     | Índice de la palabra `d` |

La función modifica `state[a]`, `state[b]`, `state[c]` y `state[d]` en memoria; no tiene valor de retorno.

#### `chacha20_block` — generación de un bloque de keystream

```c
extern void chacha20_block(uint8_t *key, uint32_t counter, uint8_t *nonce, uint8_t *output);
```

| Parámetro | Registro | Contenido |
|-----------|----------|-----------|
| `key`     | `a0`     | Puntero a la clave de 32 bytes |
| `counter` | `a1`     | Valor del contador de bloque (32 bits) |
| `nonce`   | `a2`     | Puntero al nonce de 12 bytes |
| `output`  | `a3`     | Destino del keystream de 64 bytes generado |

#### `chacha20_encrypt` — cifrado/descifrado de longitud arbitraria

```c
extern void chacha20_encrypt(const uint32_t *key, uint32_t counter,
                             const uint32_t *nonce,
                             const uint8_t *plaintext, uint8_t *ciphertext,
                             uint32_t len);
```

| Parámetro    | Registro | Contenido |
|--------------|----------|-----------|
| `key`        | `a0`     | Puntero a la clave (8 palabras de 32 bits) |
| `counter`    | `a1`     | Contador inicial de bloque |
| `nonce`      | `a2`     | Puntero al nonce (3 palabras de 32 bits) |
| `plaintext`  | `a3`     | Puntero al mensaje de entrada |
| `ciphertext` | `a4`     | Puntero al buffer de salida |
| `len`        | `a5`     | Longitud en bytes del mensaje |

Como ChaCha20 es un cifrado de flujo simétrico, aplicar `chacha20_encrypt` dos veces con los mismos parámetros recupera el mensaje original: `decrypt = encrypt`.

### 1.3 Justificación de Decisiones de Diseño

| Decisión | Justificación |
|----------|---------------|
| **`chacha20_quarter_round` como función separada** | Permite reutilizarla sin duplicar código para las 4 rondas de columna y las 4 rondas diagonal de cada double-round. Es invocada 80 veces por bloque (10 iteraciones × 8 QRs), por lo que su corrección es crítica. |
| **`chacha20_inner_block` como auxiliar interno** | Agrupa las 8 llamadas a `chacha20_quarter_round` de un double-round en una sola función. El bucle en `chacha20_block` queda reducido a `li s4, 10` + `call chacha20_inner_block` + decrement + branch, mejorando la legibilidad. |
| **Rotaciones mediante `slli`/`srli` + `or`** | RV32IM no dispone de instrucción `rol`/`ror`. La secuencia de 3 instrucciones es la forma estándar de implementar rotaciones en este ISA y es directamente legible en el código. |
| **Estado de 64 bytes en el stack, no en registros** | RV32IM tiene 32 registros de 32 bits; el estado ocupa 16 de ellos solo para datos, más los necesarios para punteros, contadores y temporales. Almacenarlo en el stack (con acceso por `lw`/`sw`) es la única opción viable y también permite mantener dos copias simultáneas (working y original) para la suma final. |
| **Registros callee-saved (`s0`–`s5`) para parámetros vivos** | Las llamadas a funciones internas destruyen `a0`–`a5` y `t0`–`t6`. Los valores que deben sobrevivir múltiples llamadas (key, nonce, punteros de salida, contador de iteraciones) se mueven a registros `s` antes del primer `call`. |
| **Registros caller-saved (`t2`–`t5`) en `chacha20_quarter_round`** | Esta función no llama a nadie más, por lo que no necesita preservar registros. Usar `t`-registers evita el overhead de salvado/restauración en prologue/epilogue, relevante porque se ejecuta 80 veces por bloque. |
| **Tests y todos los vectores RFC en C** | El código de verificación, la E/S UART y los arrays de bytes esperados son más legibles y mantenibles en C. No son rutas críticas de rendimiento. |

---

## 2. Mapeo de Registros RISC-V

### 2.1 Organización del Estado ChaCha20 (16 palabras de 32 bits)

El estado es una matriz 4×4 de palabras de 32 bits, con la siguiente asignación semántica definida en el RFC 8439:

```
     Columna 0    Columna 1    Columna 2    Columna 3
    ┌───────────┬───────────┬───────────┬───────────┐
    │ state[ 0] │ state[ 1] │ state[ 2] │ state[ 3] │  ← "expa", "nd 3", "2-by", "te k"
    │ 0x61707865│ 0x3320646e│ 0x79622d32│ 0x6b206574│     (constantes ASCII fijas)
    ├───────────┼───────────┼───────────┼───────────┤
    │ state[ 4] │ state[ 5] │ state[ 6] │ state[ 7] │  ← key[0..3], key[4..7],
    │           │           │           │           │     key[8..11], key[12..15]
    ├───────────┼───────────┼───────────┼───────────┤
    │ state[ 8] │ state[ 9] │ state[10] │ state[11] │  ← key[16..19], key[20..23],
    │           │           │           │           │     key[24..27], key[28..31]
    ├───────────┼───────────┼───────────┼───────────┤
    │ state[12] │ state[13] │ state[14] │ state[15] │  ← counter, nonce[0..3],
    │           │           │           │           │     nonce[4..7], nonce[8..11]
    └───────────┴───────────┴───────────┴───────────┘
```

Este estado de 64 bytes **vive en el stack** durante toda la ejecución; nunca cabe entero en registros (RV32I tiene 32 registros de 32 bits, y buena parte están reservados para punteros, índices y valores temporales).

### 2.2 Mapeo en `chacha20_quarter_round`

El quarter round recibe cuatro **índices** (no punteros directos a las palabras) y opera sobre las palabras seleccionadas en registros temporales:

```
Llamada:  chacha20_quarter_round(state_ptr, idx_a, idx_b, idx_c, idx_d)

  a0 ──► puntero base al estado (no se modifica durante la función)
  a1 ──► idx_a  →  slli a1,a1,2  →  offset_a = idx_a × 4
  a2 ──► idx_b  →  slli a2,a2,2  →  offset_b = idx_b × 4
  a3 ──► idx_c  →  slli a3,a3,2  →  offset_c = idx_c × 4
  a4 ──► idx_d  →  slli a4,a4,2  →  offset_d = idx_d × 4

  Carga de las palabras en registros de trabajo:
  t2  ◄──  lw t2, 0(a0+a1)   ←  state[idx_a]  ("palabra a")
  t3  ◄──  lw t3, 0(a0+a2)   ←  state[idx_b]  ("palabra b")
  t4  ◄──  lw t4, 0(a0+a3)   ←  state[idx_c]  ("palabra c")
  t5  ◄──  lw t5, 0(a0+a4)   ←  state[idx_d]  ("palabra d")

  Temporales de rotación:
  t0, t1  ←  mitades de la rotación (descartados tras cada `or`)

  Escritura de resultados de vuelta a memoria:
  sw t2, 0(a0+a1)   →  state[idx_a]
  sw t3, 0(a0+a2)   →  state[idx_b]
  sw t4, 0(a0+a3)   →  state[idx_c]
  sw t5, 0(a0+a4)   →  state[idx_d]
```

**¿Por qué `t2`–`t5` y no `s`-registers?**
`chacha20_quarter_round` no llama a ninguna otra función, por lo que nunca hay riesgo de que un `call` destruya sus registros. Los registros `t` (caller-saved) no requieren salvado explícito en prologue/epilogue, eliminando ese coste en cada una de las **80 invocaciones** que ocurren por bloque. Los registros `s` quedarían "desperdiciados" porque obligarían a generar código de salvar/restaurar innecesariamente.

### 2.3 Mapeo en `chacha20_inner_block`

`chacha20_inner_block` coordina las 8 llamadas a `chacha20_quarter_round` que forman un double-round. Su único reto es conservar el puntero al estado entre esas llamadas, ya que `a0` es destruido al entrar en `chacha20_quarter_round`:

```
  Stack frame (8 bytes): [s0] [ra]

  s0  ←  mv s0, a0        ←  state_ptr (callee-saved: sobrevive los 8 call)

  Por cada una de las 8 QRs:
    mv  a0, s0             ←  restaurar state_ptr antes del call
    li  a1, idx_a
    li  a2, idx_b
    li  a3, idx_c
    li  a4, idx_d
    call chacha20_quarter_round
```

Los registros `a1`–`a4` se recargan con `li` antes de cada llamada porque son caller-saved y `chacha20_quarter_round` los convierte en offsets (multiplica por 4) en su interior.

### 2.4 Mapeo en `chacha20_block`

`chacha20_block` es la función más compleja: construye el estado, ejecuta 10 double-rounds y serializa el keystream. Necesita mantener vivos 5 valores a través de múltiples `call`s:

```
  Stack frame (176 bytes):
  ┌──────────────────────────────┐  sp + 176
  │  padding (alineación 16B)    │
  ├──────────────────────────────┤  sp + 172
  │  ra  (return address)        │
  ├──────────────────────────────┤  sp + 168
  │  s0  (guardado)              │
  ├──────────────────────────────┤  sp + 164
  │  s1  (guardado)              │
  ├──────────────────────────────┤  sp + 160
  │  s2  (guardado)              │
  ├──────────────────────────────┤  sp + 156
  │  s3  (guardado)              │
  ├──────────────────────────────┤  sp + 152
  │  s4  (guardado)              │
  ├──────────────────────────────┤  sp + 128
  │  [espacio sin usar]          │
  ├──────────────────────────────┤  sp +  64
  │  original_state[0..15]       │  ← 64 bytes, copia inmutable del estado
  │  (preservado para suma final)│    escrito en PASO 2, leído en PASO 4
  ├──────────────────────────────┤  sp +   0
  │  working_state[0..15]        │  ← 64 bytes, modificado por los QRs
  │  (operado por inner_block)   │    puntero pasado como a0 en cada call
  └──────────────────────────────┘  sp
```

Asignación de registros callee-saved durante la vida de la función:

| Registro | Palabra(s) del estado que representa | Razón de ser callee-saved |
|----------|--------------------------------------|---------------------------|
| `s0`     | Puntero a `key` (entrada, 32 bytes)  | Necesario para construir `state[4..11]`; si no se guarda, `call chacha20_inner_block` lo destruye. |
| `s1`     | `state[12]` = valor del **counter**  | El counter se escribe una vez en `sp+48` pero se necesita su valor para el log/debug; más importante: es el parámetro original que se debe preservar. |
| `s2`     | Puntero al `nonce` (entrada, 12 bytes) | Necesario para construir `state[13..15]`; sobrevive los 10 `call chacha20_inner_block`. |
| `s3`     | Puntero al **buffer de salida** (`output`) | Usado solo en PASO 5 (serialización), pero debe sobrevivir los 10 double-rounds anteriores. |
| `s4`     | Contador de iteraciones (10 → 0)     | Decrementado en el loop `.Linner_block_loop`; un `call` lo destruiría si fuera `t`-register. |

Correspondencia directa entre registro y palabra del estado inicial:

```
  PASO 1 — Construcción del estado en sp+0..sp+60:

  sp +  0  ←  0x61707865  ("expa")   ← state[0]   li + sw  (constante literal)
  sp +  4  ←  0x3320646e  ("nd 3")   ← state[1]   li + sw
  sp +  8  ←  0x79622d32  ("2-by")   ← state[2]   li + sw
  sp + 12  ←  0x6b206574  ("te k")   ← state[3]   li + sw

  sp + 16  ←  key[0..3]              ← state[4]   lw(s0+0)  + sw
  sp + 20  ←  key[4..7]              ← state[5]   lw(s0+4)  + sw
  sp + 24  ←  key[8..11]             ← state[6]   lw(s0+8)  + sw
  sp + 28  ←  key[12..15]            ← state[7]   lw(s0+12) + sw
  sp + 32  ←  key[16..19]            ← state[8]   lw(s0+16) + sw
  sp + 36  ←  key[20..23]            ← state[9]   lw(s0+20) + sw
  sp + 40  ←  key[24..27]            ← state[10]  lw(s0+24) + sw
  sp + 44  ←  key[28..31]            ← state[11]  lw(s0+28) + sw

  sp + 48  ←  counter (s1)           ← state[12]  sw s1
  sp + 52  ←  nonce[0..3]            ← state[13]  lw(s2+0)  + sw
  sp + 56  ←  nonce[4..7]            ← state[14]  lw(s2+4)  + sw
  sp + 60  ←  nonce[8..11]           ← state[15]  lw(s2+8)  + sw
```

### 2.5 Mapeo en `chacha20_encrypt`

`chacha20_encrypt` mantiene el contexto de cifrado completo entre bloques. Necesita 6 valores vivos a través de cada `call chacha20_block`:

| Registro | Valor mantenido | Motivo |
|----------|-----------------|--------|
| `s0` | Puntero a `key` | No cambia entre bloques; debe sobrevivir cada `call chacha20_block`. |
| `s1` | **Contador actual** (se incrementa en `+1` por bloque) | Es el parámetro `a1` de cada `call chacha20_block`; se reconstruye en `a1` antes de cada llamada. |
| `s2` | Puntero a `nonce` | No cambia entre bloques. |
| `s3` | Puntero de lectura en el **plaintext** (avanza +64 por bloque) | Se usa para cargar bytes en `.Lbyte_mix_loop`. |
| `s4` | Puntero de escritura en el **ciphertext** (avanza +64 por bloque) | Se usa para almacenar bytes cifrados. |
| `s5` | Bytes **restantes** por cifrar (decrece por los bytes procesados) | Controla la condición de salida del loop y cuántos bytes del bloque usar. |

El stack frame de `chacha20_encrypt` reserva 64 bytes (`sp+0..sp+63`) como destino temporal del keystream generado por `chacha20_block`. Estos bytes se sobreescriben en cada iteración y no necesitan preservarse entre bloques.

### 2.6 Operación de Rotación (sin instrucción nativa)

RISC-V RV32IM no tiene instrucción de rotación. Se implementa con:

```asm
# Rotación izquierda de 16 bits: d <<<= 16
slli    t0, t5, 16      # t0 = d << 16
srli    t1, t5, 16      # t1 = d >> 16
or      t5, t0, t1      # d = (d << 16) | (d >> 16)
```

**Patrón general para `x <<<= n`:**
```asm
slli    t0, x, n        # t0 = x << n
srli    t1, x, (32-n)   # t1 = x >> (32-n)
or      x, t0, t1       # x = t0 | t1
```

Los cuatro desplazamientos del quarter round (`<<<16`, `<<<12`, `<<<8`, `<<<7`) se implementan todos con este patrón, usando `t0` y `t1` como registros temporales que se reutilizan en cada paso.

---

## 3. Evidencias de Ejecución


---

## 4. Bitácora de Bug: Incremento Incorrecto del Contador en `chacha20_encrypt`

### Descripción del error

Durante el desarrollo de `chacha20_encrypt`, se introdujo un error en la lógica de actualización del contador de bloque. Al finalizar el procesamiento de cada chunk de 64 bytes, el contador debía incrementarse en **1**, pero por error se escribió el valor `10` en lugar de `1`:
```riscv
# Código incorrecto
addi s1, s1, 10        # ← debía ser 1, no 10

# Código correcto
addi s1, s1, 1
``` 

El efecto fue que, a partir del segundo bloque, el contador tomaba valores completamente erróneos (1 → 11 → 21 → ...), lo que producía un keystream incorrecto y hacía fallar la prueba `ChaCha20 Encrypt (RFC 8439 2.4.2)` desde el byte 40 en adelante, como se observa en la siguiente captura:


![Resultado de pruebas con FAIL en Encrypt](./EvidenciaGDB.png)



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

![Sesión GDB mostrando salto incorrecto del contador](./EvidenciaGDB1.png)

---

### Corrección

Se reemplazó el valor incorrecto:
```riscv
# Antes (incorrecto)
addi s1, s1, 10

# Después (correcto)
addi s1, s1, 1
```
Tras la corrección, la prueba de cifrado pasó satisfactoriamente, y los tres tests del RFC (Quarter Round, Block y Encrypt) produjeron `Result: PASS`.





## 5. Análisis de Resultados


---

