from __future__ import annotations

import os
import random
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb_tools.runner import get_runner

IVERILOG_BUILD_ARGS = ["-g2005-sv", "-DPOR_HLD_DELAY=", "-DPOR_MEM_DELAY="]


async def apply_reset(dut, cycles: int = 2) -> None:
    dut.global_reset.value = 1
    dut.chip_select.value = 0
    dut.write_enable.value = 0
    dut.addr.value = 0
    dut.data_in.value = 0
    dut.write_mask.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk_inst)
    dut.global_reset.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk_inst)


async def sram_write(dut, addr: int, data_bit: int) -> None:
    dut.addr.value = addr
    dut.data_in.value = data_bit & 1
    dut.write_mask.value = 0
    dut.chip_select.value = 1
    dut.write_enable.value = 1
    await RisingEdge(dut.clk)
    dut.chip_select.value = 0
    dut.write_enable.value = 0
    await RisingEdge(dut.clk)


def memory_word(dut, addr: int) -> int:
    return int(dut.memory[addr].value)


@cocotb.test()
async def test_reset_deasserts_write_strobe(dut):
    clk = Clock(dut.clk, 10, unit="us")
    clk_inst = Clock(dut.clk_inst, 10, unit="us")
    clk.start(start_high=False)
    clk_inst.start(start_high=False)
    await apply_reset(dut)
    assert int(dut.wren_dly.value) == 0
    assert int(dut.rden_dly.value) == 0


@cocotb.test()
async def test_single_write(dut):
    clk = Clock(dut.clk, 10, unit="us")
    clk_inst = Clock(dut.clk_inst, 10, unit="us")
    clk.start(start_high=False)
    clk_inst.start(start_high=False)
    await apply_reset(dut)
    await sram_write(dut, addr=0, data_bit=1)
    assert memory_word(dut, 0) == 0x01


@cocotb.test()
async def test_write_zero(dut):
    clk = Clock(dut.clk, 10, unit="us")
    clk_inst = Clock(dut.clk_inst, 10, unit="us")
    clk.start(start_high=False)
    clk_inst.start(start_high=False)
    await apply_reset(dut)
    await sram_write(dut, addr=3, data_bit=0)
    assert memory_word(dut, 3) == 0x00


@cocotb.test()
async def test_random_writes(dut):
    clk = Clock(dut.clk, 10, unit="us")
    clk_inst = Clock(dut.clk_inst, 10, unit="us")
    clk.start(start_high=False)
    clk_inst.start(start_high=False)
    await apply_reset(dut)
    expected: dict[int, int] = {}
    for _ in range(8):
        addr = random.randint(0, 31)
        bit = random.randint(0, 1)
        await sram_write(dut, addr=addr, data_bit=bit)
        expected[addr] = bit
    for addr, bit in expected.items():
        assert memory_word(dut, addr) == bit, f"addr {addr}: expected {bit:#x}"


def test_sram_hidden_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sources = [
        proj_path / "sources/timescale.v",
        proj_path / "sources/sram.sv",
    ]
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="sram",
        always=True,
        build_args=IVERILOG_BUILD_ARGS,
    )
    runner.test(hdl_toplevel="sram", test_module="test_sram_hidden")
