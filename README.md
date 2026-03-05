# Proyecto Arquitectura de computadores I (CE4301)

## Descripción breve del proyecto:

Proyecto individual para implementar el cifrador ChaCha20 en ensamblador RISC-V, integrándolo con un programa en C que lo use para cifrar y descifrar mensajes. En el entorno Docker + QEMU, permitiendo depuración con GDB.

---

## 1. Estructura del proyecto

```
.
├── Dockerfile
├── run.sh
├── ChaCha20/           # Código
│   ├── asm-only/      # Ejemplo de ensamblador puro
└── README.md
```

- `ChaCha20/` contiene la solución al proyecto
- `Dockerfile` define la imagen que incluye el emulador QEMU y el toolchain RISC-V
- `run.sh` automatiza la construcción de la imagen y la ejecución del contenedor
---
## 2. Requisitos previos
## 3. Instrucciones paso a paso para construir y ejecutar el proyecto dentro del entorno Docker.

## 4. Instrucciones para ejecutar los casos de prueba y verificar los vectores del RFC

## 5. Instrucciones para abrir una sesión de depuración con GDB.