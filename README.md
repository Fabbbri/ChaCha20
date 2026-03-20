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
    ├── main.c                      # Programa principal en C con tests RFC 8439
    ├── chacha20.s                  # Implementación ChaCha20 en ensamblador RISC-V
    ├── startup.s                   # Código de inicio (configuración de pila y entrada)
    ├── linker.ld                   # Script de enlazado (mapeo de memoria)
    ├── build.sh                    # Script de compilación (genera chacha20.elf)
    ├── run-qemu.sh                 # Script para ejecutar QEMU con servidor GDB
    ├── debug_test.gdb              # Comandos GDB para depuración automatizada
    ├── contador.gdb                # Comandos GDB para depuración automatizada
    ├── evidencias.gdb              # Comandos GDB para depuración automatizada
    ├── DOCUMENTACION.md            # Documentación técnica detallada
    └── Evidencias/                 # Capturas de pruebas y depuración
```




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



### Ejecutar las pruebas:



**Terminal 2:** Conectar con GDB y ejecutar
```bash
# Entrar al contenedor (si no está dentro)
docker exec -it rvqemu /bin/bash

# Navegar al directorio del proyecto
cd ChaCha20

# Conectar GDB
gdb-multiarch chacha20.elf
```

Dentro de GDB:
```gdb
target remote :1234
continue
```

La salida en la terminal de QEMU mostrará:
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
cd  ChaCha20
gdb-multiarch chacha20.elf
target remote :1234              
```

Comandos básicos en GDB:
```gdb
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

### Opción B: Usando scripts de depuración

```bash
gdb-multiarch chacha20.elf -x debug_test.gdb
```
```bash
gdb-multiarch chacha20.elf -x contador.gdb
```
```bash
gdb-multiarch chacha20.elf -x evidencias.gdb
```