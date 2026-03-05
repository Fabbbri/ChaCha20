# Assembly function to calculate sum from 1 to n
# Function signature: int sum_to_n(int n)
# a0 = input parameter n
# a0 = return value

.section .text
.globl sum_to_n
sum_to_n:
    # Save return address
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    sw s1, 4(sp)
    sw s2, 0(sp)
    
    # Initialize variables
    mv s0, a0      # s0 = n (input parameter)
    li s1, 1       # s1 = counter (start from 1)
    li s2, 0       # s2 = sum accumulator
    
    # Check if n <= 0
    blez s0, end_sum
    
loop_sum:
    add s2, s2, s1    # sum += counter
    addi s1, s1, 1    # counter++
    ble s1, s0, loop_sum  # if counter <= n, continue loop
    
end_sum:
    # Return value in a0
    mv a0, s2
    
    # Restore registers and return
    lw s2, 0(sp)
    lw s1, 4(sp)
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret
