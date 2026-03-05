# Ejemplo: C + Assembly

Este ejemplo demuestra cómo un programa en C puede llamar funciones escritas en ensamblador RISC-V.

## Archivos

- `example.c`: Programa principal en C
- `startup.s`: Código de inicio que configura la pila y llama a main(). Los programas C necesitan inicialización antes de ejecutar main()
- `math_asm.s`: Función matemática en ensamblador que calcula sumas siguiendo las convenciones de llamada RISC-V
- `linker.ld`: Script de enlazado que define la memoria y punto de entrada
- `build.sh`: Script de compilación
- `run-qemu.sh`: Script para ejecutar QEMU

## Funcionalidad

### Programa en C (`example.c`)
- Función principal que llama a la función en ensamblador
- Funciones básicas para imprimir texto y números
- Prueba la función `sum_to_n` con diferentes valores

### Código de inicio (`startup.s`)
- Establece el puntero de pila (sp) al inicio del área de pila definida en linker.ld
- Llama a la función main() del programa C
- Proporciona un bucle infinito si main() retorna, evitando que el programa termine inesperadamente

### Función en Assembly (`math_asm.s`)
- `sum_to_n(int n)`: Calcula la suma de números del 1 a n
- Sigue las convenciones de llamada RISC-V
- Maneja parámetros y valor de retorno correctamente

## Compilación y ejecución

```bash
# Compilar
./build.sh

# Ejecutar con QEMU (en una terminal)
./run-qemu.sh

# En otra terminal, conectar GDB
docker exec -it rvqemu /bin/bash
cd /home/rvqemu-dev/workspace/examples/c-asm
gdb-multiarch example.elf
```

## Depuración con GDB

### Script automatizado de depuración
Para facilitar la depuración, puede usar los comandos archivo `simple_debug.gdb`:

```bash
# En una terminal: iniciar QEMU
./run-qemu.sh

# En otra terminal: ejecutar script de GDB
docker exec -it rvqemu /bin/bash
cd /home/rvqemu-dev/workspace/examples/c-asm
gdb-multiarch example.elf 
```

Comandos de gdb en `simple_debug.gdb`:
```gdb
target remote :1234
break _start
break main
break sum_to_n
layout asm
layout regs
continue
step
step
info registers
continue
step
info registers
monitor quit
quit
```

## Convenciones de llamada RISC-V

- `a0`: Primer parámetro de entrada y valor de retorno
- `a1-a7`: Parámetros adicionales
- `s0-s11`: Registros salvados (preserved)
- `t0-t6`: Registros temporales
- `ra`: Dirección de retorno
- `sp`: Puntero de pila

La función assembly respeta estas convenciones:
1. Guarda registros que modifica en la pila
2. Recibe parámetro en `a0`
3. Devuelve resultado en `a0`
4. Restaura registros antes de retornar