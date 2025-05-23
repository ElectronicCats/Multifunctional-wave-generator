import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, First
from cocotb.utils import get_sim_time

@cocotb.test()
async def test_waveform_generation(dut):
    """Test waveform generation through I2S output"""
    clock = Clock(dut.clk, 40, units="ns")  # 25MHz clock
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.ena.value = 0
    dut.ui_in.value = 0xFF  # UART idle
    await Timer(100, units="ns")
    
    # Release reset
    dut.rst_n.value = 1
    dut.ena.value = 1
    await Timer(5, units="us")  # Extended initialization
    dut._log.info("System initialized")

    # Verify I2S clock is running
    sck = dut.uo_out[0]
    ws = dut.uo_out[1]
    
    # Wait for I2S activity with timeout
    try:
        await First(RisingEdge(sck), Timer(10, units="us"))
    except cocotb.result.SimTimeoutError:
        raise cocotb.result.TestFailure("I2S clock not detected!")

    # Basic waveform test
    waveforms = {
        0x54: "Triangle",
        0x51: "Square"
    }
    
    for cmd, name in waveforms.items():
        await test_waveform(dut, cmd, name)

async def test_waveform(dut, cmd, name):
    """Test individual waveform"""
    dut._log.info(f"Testing {name} wave")
    await send_uart(dut, cmd)
    await Timer(20, units="us")  # Allow settling
    
    # Capture samples with timeout
    samples = []
    for _ in range(5):
        try:
            sample = await capture_i2s_sample(dut)
            samples.append(sample)
        except cocotb.result.SimTimeoutError:
            continue
    
    assert len(samples) > 2, f"No valid {name} samples captured"
    
    if name == "Square":
        valid = any(s in (0, 255) for s in samples)
        assert valid, "No valid square wave extremes detected"

async def capture_i2s_sample(dut, timeout=10_000):
    """Capture I2S sample with timeout"""
    ws = dut.uo_out[1]
    
    # Wait for WS edge with timeout
    try:
        await First(RisingEdge(ws), Timer(timeout, "ns"))
    except cocotb.result.SimTimeoutError:
        dut._log.warning("I2S WS timeout")
        raise
    
    # Capture 16 bits
    sample = 0
    sck = dut.uo_out[0]
    
    for _ in range(16):
        await FallingEdge(sck)
        sample = (sample << 1) | dut.uo_out[2].value
    
    return sample >> 8  # Use upper 8 bits

async def send_uart(dut, data):
    """Send UART command with reduced timing precision"""
    # Start bit
    dut.ui_in.value = 0
    await Timer(10, units="us")
    
    # Data bits
    for i in range(8):
        dut.ui_in.value = (data >> i) & 0x01
        await Timer(10, units="us")
    
    # Stop bit
    dut.ui_in.value = 1
    await Timer(10, units="us")