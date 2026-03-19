# Proyecto Arquitectura de computadores I (CE4301)

## Descripción breve del proyecto:

Proyecto individual para implementar el cifrador ChaCha20 en ensamblador RISC-V, integrándolo con un programa en C que lo use para cifrar y descifrar mensajes. En el entorno Docker + QEMU, permitiendo depuración con GDB.

---

## 1. Estructura del proyecto

```
.
├── Dockerfile                      # Imagen Docker con toolchain RISC-V y QEMU
├── run.sh                          # Script para construir imagen y ejecutar contenedor
├── README.md                       # Documentación principal del proyecto
│
└── ChaCha20/                       # Directorio del código fuente
    │
    ├── main.c                      # Programa principal en C con tests RFC 8439
    ├── chacha20.s                  # Implementación ChaCha20 en ensamblador RISC-V
    ├── startup.s                   # Código de inicio (configuración de pila y entrada)
    ├── linker.ld                   # Script de enlazado (mapeo de memoria)
    ├── build.sh                    # Script de compilación (genera chacha20.elf)
    ├── run-qemu.sh                 # Script para ejecutar QEMU con servidor GDB
    ├── debug_test.gdb              # Comandos GDB para depuración automatizada
    ├── DOCUMENTACION.md            # Documentación técnica detallada
    └── Evidencias/                 # Capturas de pruebas y depuración
        ├── EvidenciaEjecucion.png  # Tests pasando (PASS)
        ├── EvidenciaGDB.png        # Bug de cifrado detectado (FAIL)
        └── EvidenciaGDB1.png       # Sesión GDB mostrando contador incorrecto
```

### Descripción de Componentes

#### Infraestructura Docker
- **`Dockerfile`**: Define imagen Ubuntu 22.04 con:
  - Toolchain RISC-V: `gcc-riscv64-unknown-elf`
  - Emulador: `qemu-system-riscv32`
  - Depurador: `gdb-multiarch`
- **`run.sh`**: Automatiza construcción de imagen y montaje del workspace

#### Código Fuente (`ChaCha20/`)
- **`main.c`**: Capa de orquestación en C
  - Implementa 3 tests del RFC 8439 (Quarter Round, Block, Encrypt)
  - Proporciona funciones de I/O UART (`print_*`)
  - Define vectores de prueba estáticos

- **`chacha20.s`**: Implementación completa en ensamblador RISC-V
  - `chacha20_quarter_round`: operación primitiva (4 palabras)
  - `chacha20_inner_block`: coordina 8 QRs por double-round
  - `chacha20_block`: genera 64 bytes de keystream (10 double-rounds)
  - `chacha20_encrypt`: cifrado/descifrado de longitud arbitraria

- **`startup.s`**: Código de bootstrap
  - Inicializa stack pointer (`sp`) al top de RAM
  - Invoca función `main()` desde C
  - Define punto de entrada `_start`

- **`linker.ld`**: Script de enlazado
  - Mapea sección `.text` en `0x80000000` (RAM de QEMU virt)
  - Define regiones de memoria (ROM, RAM, heap, stack)
  - Exporta símbolos para startup (`__stack_top`, `__bss_start`, etc.)

#### Scripts de Construcción y Ejecución
- **`build.sh`**: Pipeline de compilación
  ```bash
  # 1. Compila startup.s → startup.o
  # 2. Compila main.c → main.o
  # 3. Ensambla chacha20.s → chacha20.o
  # 4. Enlaza todo → chacha20.elf
  ```

- **`run-qemu.sh`**: Lanza QEMU en modo servidor GDB
  ```bash
  # qemu-system-riscv32 -machine virt -nographic \
  #   -bios none -kernel chacha20.elf -s -S
  ```

- **`debug_test.gdb`**: Script de depuración con breakpoints configurados
  - Breakpoints en funciones clave (`main`, `chacha20_block`, etc.)
  - Comandos para inspeccionar estado y registros


## 2. Requisitos previos

- **Docker** instalado en el sistema
- Permisos para ejecutar contenedores
- Terminal con soporte bash

**Verificar instalación:**
```bash
docker --version
```

---

## 3. Instrucciones paso a paso para construir y ejecutar el proyecto dentro del entorno Docker

### Paso 1: Clonar o descargar el proyecto
```bash
cd ~/Escritorio/ChaCha20    # o la ubicación del proyecto
```

### Paso 2: Construir la imagen Docker y entrar al contenedor
```bash
chmod +x run.sh
./run.sh
```

Este script:
1. Construye la imagen `rvqemu` si no existe (incluye toolchain RISC-V)
2. Inicia el contenedor con el directorio de trabajo montado

### Paso 3: Compilar el proyecto (dentro del contenedor)
```bash
cd ChaCha20
./build.sh
```

Esto genera `chacha20.elf`, el ejecutable para RISC-V.

### Paso 4: Ejecutar con QEMU
```bash
./run-qemu.sh
```

El programa inicia QEMU en modo pausa esperando conexión GDB en el puerto 1234.

---

## 4. Instrucciones para ejecutar los casos de prueba y verificar los vectores del RFC

El programa `main.c` incluye pruebas automáticas basadas en los vectores de prueba del **RFC 8439**.

### Test implementado: Quarter Round (RFC 8439 Section 2.1.1)

**Vectores de entrada:**
- `a = 0x11111111`
- `b = 0x01020304`
- `c = 0x9b8d6f43`
- `d = 0x01234567`

**Valores esperados (salida):**
- `a = 0xea2a92f4`
- `b = 0xcb1cf8ce`
- `c = 0x4581472e`
- `d = 0x5881c4bb`

### Ejecutar las pruebas:

**Terminal 1:** Iniciar QEMU
```bash
./run-qemu.sh
```

**Terminal 2:** Conectar con GDB y ejecutar
```bash
# Entrar al contenedor (si no está dentro)
docker exec -it rvqemu /bin/bash

# Navegar al directorio del proyecto
cd /home/rvqemu-dev/workspace/ChaCha20

# Conectar GDB
gdb-multiarch chacha20.elf
```

Dentro de GDB:
```gdb
target remote :1234
continue
```

La salida en la terminal de QEMU mostrará:
- Los valores de entrada
- Los valores de salida calculados
- Los valores esperados según RFC
- Resultado: **PASS** o **FAIL**

---

## 5. Instrucciones para abrir una sesión de depuración con GDB

### Opción A: Depuración manual

**Terminal 1:** Iniciar QEMU con servidor GDB
```bash
cd ChaCha20
./run-qemu.sh
```

**Terminal 2:** Conectar GDB
```bash
docker exec -it rvqemu /bin/bash
cd /home/rvqemu-dev/workspace/ChaCha20
gdb-multiarch chacha20.elf
```

Comandos básicos en GDB:
```gdb
target remote :1234              # Conectar al servidor QEMU
break _start                     # Breakpoint en inicio
break main                       # Breakpoint en main()
break chacha20_quarter_round     # Breakpoint en función assembly
continue                         # Ejecutar hasta breakpoint
step                             # Avanzar una instrucción
info registers                   # Ver registros
x/16xw $a0                       # Ver estado (16 words en a0)
layout asm                       # Vista de desensamblado
layout regs                      # Vista de registros
quit                             # Salir de GDB
```

### Opción B: Usar script de depuración

```bash
gdb-multiarch chacha20.elf -x debug_test.gdb
```

### Comandos útiles adicionales

| Comando | Descripción |
|---------|-------------|
| `info breakpoints` | Lista breakpoints activos |
| `delete <n>` | Elimina breakpoint número n |
| `print $a0` | Imprime valor del registro a0 |
| `stepi` | Avanza una instrucción assembly |
| `nexti` | Avanza sin entrar en funciones |
| `bt` | Muestra backtrace de llamadas |
| `monitor quit` | Termina QEMU desde GDB |

---

## Convenciones de llamada RISC-V

| Registro | Uso |
|----------|-----|
| `a0-a7` | Argumentos de función y valor de retorno |
| `s0-s11` | Registros preservados (callee-saved) |
| `t0-t6` | Temporales (caller-saved) |
| `ra` | Dirección de retorno |
| `sp` | Puntero de pila |