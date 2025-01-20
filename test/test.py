# SPDX-License-Identifier: MIT
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

@cocotb.test()
async def test_wave_selection(dut):
    """
    Test the wave selection functionality by setting the wave_select
    signal and checking the uo_out output.
    """
    # Start the clock
    clock = Clock(dut.clk, 10, units="us")  # 10us clock period
    cocotb.start_soon(clock.start())

    # Reset the design
    dut._log.info("Resetting the design")
    dut.ena.value = 1  # Enable the design
    dut.ui_in.value = 0  # Clear inputs
    dut.uio_in.value = 0
    dut.rst_n.value = 0  # Active low reset
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1  # Release reset
    await ClockCycles(dut.clk, 5)

    # Select the first wave (e.g., sine wave)
    dut._log.info("Testing wave selection for sine wave")
    dut.ui_in.value = 0b000  # wave_select = 3'b000 (Sine wave)
    await ClockCycles(dut.clk, 10)
    # Validate the output (you may need to adjust the expected value)
    assert dut.uo_out.value.integer == 42, "Sine wave output not as expected"

    # Select the second wave (e.g., square wave)
    dut._log.info("Testing wave selection for square wave")
    dut.ui_in.value = 0b001  # wave_select = 3'b001 (Square wave)
    await ClockCycles(dut.clk, 10)
    # Validate the output (you may need to adjust the expected value)
    assert dut.uo_out.value.integer == 84, "Square wave output not as expected"

    # Select the third wave (e.g., triangle wave)
    dut._log.info("Testing wave selection for triangle wave")
    dut.ui_in.value = 0b010  # wave_select = 3'b010 (Triangle wave)
    await ClockCycles(dut.clk, 10)
    # Validate the output (you may need to adjust the expected value)
    assert dut.uo_out.value.integer == 126, "Triangle wave output not as expected"

    # Additional tests for other waveforms can be added here
    dut._log.info("All tests completed successfully")
