import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

async def send_uart_byte(dut, byte):
    # Start bit
    dut.rx.value = 0
    await Timer(104167, units="ns")
    # Data bits
    for i in range(8):
        dut.rx.value = (byte >> i) & 1
        await Timer(104167, units="ns")
    # Stop bit
    dut.rx.value = 1
    await Timer(104167, units="ns")

@cocotb.test()
async def test_uart_wave_selection(dut):
    # Clock generation
    clock = Clock(dut.clk, 40, units="ns")  # 25 MHz
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    await Timer(100, units="ns")
    dut.rst_n.value = 1

    # Test UART commands
    await send_uart_byte(dut, 0x54)  # 'T' - Triangle wave
    await Timer(100, units="ns")
    assert dut.wave_select.value == 0b000, "Triangle wave selection failed"

    await send_uart_byte(dut, 0x53)  # 'S' - Sawtooth wave
    await Timer(100, units="ns")
    assert dut.wave_select.value == 0b001, "Sawtooth wave selection failed"
