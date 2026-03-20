set pagination off
set confirm off
set disassemble-next-line on

target remote :1234


# Puntos de parada útiles
break _start
break main

# Encriptación (bucle principal)
break chacha20_encrypt

# 1) Ver el contador ya cargado dentro de chacha20_block (después de mv s1,a1)
#    (paramos en la siguiente instrucción para que s1 ya tenga el valor)
break chacha20.s:203
commands
	silent
	printf "\n[chacha20_block] counter(s1)=0x%08x (%u)  a1(arg)=0x%08x (%u)\n", $s1, $s1, $a1, $a1
	continue
end

# 2) Ver el valor de s1 justo antes/después de la actualización del contador
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

# Arrancar
continue