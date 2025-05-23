import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_basic_functionality(dut):
    """Basic functionality smoke test"""
    clock = Clock(dut.clk, 40, units="ns")  # 25MHz
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.ena.value = 0
    await Timer(100, units="ns")
    
    # Release reset
    dut.rst_n.value = 1
    dut.ena.value = 1
    await Timer(5, units="us")
    
    # Verify basic operation
    test_passed = False
    
    # Random stimulus test
    for _ in range(3):
        # Send random UART command
        cmd = random.choice([0x54, 0x53, 0x51, 0x57])
        dut.ui_in.value = 0xFF  # Idle
        await Timer(1, units="us")
        
        # Simplified UART transmission
        dut.ui_in.value = 0  # Start bit
        await Timer(1, units="us")
        for _ in range(8):
            dut.ui_in.value = random.randint(0, 1)
            await Timer(1, units="us")
        dut.ui_in.value = 1  # Stop bit
        await Timer(2, units="us")

        # Verify I2S activity
        if dut.uo_out.value != 0:
            test_passed = True
            break
            
        await Timer(10, units="us")

    assert test_passed, "No I2S activity detected"

    # Final check
    await Timer(10, units="us")
    dut._log.info("Basic functionality verified")