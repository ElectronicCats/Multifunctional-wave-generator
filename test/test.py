import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.utils import get_sim_time

@cocotb.test()
async def test_waveform_generation(dut):
    """Test waveform generation and ADSR functionality through I2S output"""
    clock = Clock(dut.clk, 40, units="ns")  # 25MHz clock
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.ena.value = 0
    dut.ui_in.value = 0xFF  # UART idle state
    await Timer(100, units="ns")
    
    # Release reset
    dut.rst_n.value = 1
    dut.ena.value = 1
    await Timer(1, units="us")
    dut._log.info("System initialized")

    # Test basic waveforms
    waveforms = {
        0x54: "Triangle",
        0x53: "Sawtooth",
        0x51: "Square",
        0x57: "Sine"
    }
    
    for cmd, name in waveforms.items():
        await test_waveform(dut, cmd, name)
    
    # Test ADSR envelope
    await test_adsr_envelope(dut)

async def test_waveform(dut, cmd, name):
    """Test individual waveform"""
    dut._log.info(f"Testing {name} wave")
    await send_uart(dut, cmd)
    await Timer(20, units="us")  # Allow waveform change
    
    # Capture 10 samples
    samples = [await capture_i2s_sample(dut) for _ in range(10)]
    
    # Basic validation
    if name == "Square":
        assert all(s in (0, 255) for s in samples), "Invalid square wave values"
    else:
        assert min(samples) > 10 and max(samples) < 245, f"{name} out of range"

async def test_adsr_envelope(dut):
    """Test ADSR envelope stages"""
    dut._log.info("Testing ADSR Envelope")
    
    # Reset to initial state
    await send_uart(dut, 0x46)  # Noise OFF
    await send_uart(dut, 0x54)  # Triangle wave
    await send_uart(dut, 0x5B)  # A4 frequency
    
    # Test Attack phase
    await rotate_encoder(dut, 0, 5)  # Increase attack
    attack_samples = []
    for _ in range(20):
        attack_samples.append(await capture_i2s_sample(dut))
        await Timer(1, units="us")
    
    # Verify amplitude increases
    assert attack_samples[-1] > attack_samples[0], "Attack phase failed"

async def send_uart(dut, data):
    """Send UART command"""
    # Start bit
    dut.ui_in.value = 0x00
    await Timer(104, units="us")
    
    # Data bits (LSB first)
    for i in range(8):
        dut.ui_in.value = (data >> i) & 0x01
        await Timer(104, units="us")
    
    # Stop bit
    dut.ui_in.value = 0x01
    await Timer(104, units="us")
    dut._log.info(f"Sent UART command: 0x{data:02X}")

async def capture_i2s_sample(dut):
    """Capture one I2S sample (16-bit)"""
    await RisingEdge(dut.uo_out[1])  # Wait for WS edge
    sample = 0
    
    # Capture 16 bits
    for _ in range(16):
        await FallingEdge(dut.uo_out[0])  # SCK falling edge
        sample = (sample << 1) | dut.uo_out[2].value
    
    return sample >> 8  # Use upper 8 bits

async def rotate_encoder(dut, encoder_id, steps):
    """Simulate encoder rotation"""
    base_pin = encoder_id * 2
    for _ in range(steps):
        # CW rotation pattern
        dut.uio_in.value = (0b00 << base_pin)
        await Timer(400, units="ns")
        dut.uio_in.value = (0b01 << base_pin)
        await Timer(400, units="ns")
        dut.uio_in.value = (0b11 << base_pin)
        await Timer(400, units="ns")
        dut.uio_in.value = (0b10 << base_pin)
        await Timer(400, units="ns")