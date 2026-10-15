"""MAGMa 碎片化算法模块

提供三个运行脚本：
- run_magma.py: 原始脚本（需要 HDF5 输入）
- run_magma_original.py: 原始逻辑，适配 CSV/parquet 输入
- run_magma_speed_op.py: 简化版，速度优化，适配 CSV/parquet 输入
"""

from .fragmentation import FragmentEngine
from . import common

