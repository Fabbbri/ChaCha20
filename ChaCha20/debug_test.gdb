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