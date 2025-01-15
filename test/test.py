import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_uart_receiver(dut):
    # Initialize clock
    clock = Clock(dut.clk, 10, units="ns")  # 100MHz clock
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    # Send 'T' (0x54) to select Triangle Wave
    await send_uart_byte(dut, 0x54)
    await ClockCycles(dut.clk, 100)

    # Verify wave_select = 0b000
    assert dut.wave_select.value == 0b000, f"wave_select mismatch: {dut.wave_select.value}"

    # Send 'S' (0x53) to select Sawtooth Wave
    await send_uart_byte(dut, 0x53)
    await ClockCycles(dut.clk, 100)

    # Verify wave_select = 0b001
    assert dut.wave_select.value == 0b001, f"wave_select mismatch: {dut.wave_select.value}"

async def send_uart_byte(dut, byte_value, baud_cycles=868):
    """Simulate UART byte transmission."""
    dut.rx.value = 0  # Start bit
    await ClockCycles(dut.clk, baud_cycles)

    for i in range(8):  # 8 data bits
        dut.rx.value = (byte_value >> i) & 1
        await ClockCycles(dut.clk, baud_cycles)

    dut.rx.value = 1  # Stop bit
    await ClockCycles(dut.clk, baud_cycles)
