# Proyecto Arquitectura de computadores I (CE4301)

## Descripción breve del proyecto:

Proyecto individual para implementar el cifrador ChaCha20 en ensamblador RISC-V, integrándolo con un programa en C que lo use para cifrar y descifrar mensajes. En el entorno Docker + QEMU, permitiendo depuración con GDB.

---

## 1. Estructura del proyecto

```
.
├── Dockerfile              # Imagen Docker con toolchain RISC-V y QEMU
├── run.sh                  # Script para construir imagen y ejecutar contenedor
├── README.md               # Este archivo
└── ChaCha20/               # Código fuente del proyecto
    ├── main.c              # Programa principal en C con tests RFC 8439
    ├── chacha20.s          # Implementación ChaCha20 en ensamblador RISC-V
    ├── startup.s           # Código de inicio (configura pila y llama main)
    ├── linker.ld           # Script de enlazado (define memoria y entrada)
    ├── build.sh            # Script de compilación
    ├── run-qemu.sh         # Ejecuta QEMU con servidor GDB
    ├── debug_test.gdb      # Comandos de depuración para GDB
    └── README.md           # Documentación adicional
```

**Descripción de archivos:**
- `ChaCha20/` contiene la solución completa del proyecto
- `Dockerfile` define la imagen Ubuntu 22.04 con el emulador QEMU y el toolchain RISC-V (`gcc-riscv64-unknown-elf`, `gdb-multiarch`)
- `run.sh` automatiza la construcción de la imagen y la ejecución del contenedor

---

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