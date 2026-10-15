# MassSpecGym MAGMa annotation — RA 使用入口

从包含 **SMILES、加合物和实测 MS/MS 峰**的 CSV 生成 MAGMa 候选碎片与峰标注。
本仓库整理自 UltraGo 的 `Magma4MassSpecGYm.py` 和 v8 碎裂引擎，用于交接现有实现。

**当前是原实现的便携化版本，已知标签问题尚未修复。** 开始正式生成或训练之前，
请先读 [已知问题](docs/KNOWN_ISSUES.md)。其中原子编号映射问题已在现有数据的一条
真实记录中验证。输出的碎裂路径是算法候选解释，不是实验确认的碎裂机制。

## 1. 安装

需要 Python 3.13；源机器实际使用 Python 3.13.2。计算在 CPU 上运行，不需要 CUDA。

```bash
git clone https://github.com/Dsadd4/MassSpecGym-MAGMA-annotation.git
cd MassSpecGym-MAGMA-annotation
conda env create -f environment.yml
conda activate massspecgym-magma
```

或者在已安装的 Python 3.13 中：

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

直接依赖在 `requirements.txt` 中固定到源环境版本。`h5py`、`pathos` 和
`multiprocess` 仅用于保留的其他工具接口，本生成入口不要求安装。

## 2. 先运行两条合成示例

```bash
bash scripts/run_annotation.sh \
  examples/tiny_massspecgym.csv \
  outputs/example-original \
  1
```

脚本会创建一个全新的输出目录，保存：

```text
annotations.json   完整候选图和峰标注
summary.csv        每条输入的成功/失败、匹配数量和错误信息
run_config.json    参数、Python 和依赖版本
command.sh         实际执行命令
run.log            标准输出与错误输出
exit_code.txt      生成进程退出码
```

已有输出目录会被拒绝覆盖。示例仅验证安装、调用和输出结构，不是正式数据或
benchmark。进程退出码为 0 也不代表每条样本都成功，必须检查 `summary.csv`
的 `success` 与 `error` 字段。

**如果需要使碎片原子索引对应输入 SMILES 的 RDKit 图，显式加上：**

```bash
bash scripts/run_annotation.sh \
  examples/tiny_massspecgym.csv \
  outputs/example-input-order \
  1 \
  --no-canonicalize
```

这个选项跳过引擎的 InChI/互变异构体规范化，会改变相对默认模式的预处理行为；
它不等于修复所有已知问题。复现历史结果时必须核对历史生成参数，不能假定历史
任务已经使用此选项。

## 3. 准备输入 CSV

| 列名 | 要求 |
|---|---|
| `spec_id` | 建议必填、非空且唯一的谱图标识；原脚本不会强制校验唯一性 |
| `smiles` | RDKit 可以解析的分子 SMILES |
| `prec_type` | 引擎支持的加合物字符串，例如 `[M+H]+`；缺列时默认该值 |
| `peaks` | Python 元组列表的字符串，每对分别为 m/z 和强度 |

`peaks` 单元格示例：

```text
[('47.049141', '1.0'), ('31.017841', '0.4')]
```

CSV 中需要给整个单元格加双引号，见 `examples/tiny_massspecgym.csv`。
本入口不会自动下载 MassSpecGym，也不会自动清洗、归一化或划分训练/验证/测试集。
完整输入 CSV 由项目负责人单独提供，不能用合成示例代替正式数据。

## 4. 在计算节点上处理正式 CSV

先用少量原始记录核对字段和输出，再在已分配的 CPU/计算节点上运行完整数据。
`WORKERS` 必须符合节点实际 CPU 和内存配额；不要把开发机或登录节点当计算节点。

```bash
mkdir -p logs
nohup bash scripts/run_annotation.sh \
  data/MassSpecGym_train_full.csv \
  outputs/train-run-001 \
  4 \
  --no-canonicalize \
  > logs/train-run-001.launch.log 2>&1 < /dev/null &
echo $! > logs/train-run-001.pid
```

该命令展示保留输入原子顺序的显式模式；是否使用该模式应由本次生成目标决定。
**原生成器没有断点续算**，中断后不要对原输出文件直接重跑。大规模运行前应设计
独立 CSV 分片、每片独立输出和完成清单；本仓库尚未实现自动分片/接续。

完整候选图可能非常大。历史验证集的首条记录有 9 个谱峰、10,055 个图节点和
39,269 条边，单条 JSON 约 6.27 MB。生成前预留输出容量。

## 5. 原始命令行入口

```bash
python -m fragments.magma.op.Magma4MassSpecGYm --help

python -m fragments.magma.op.Magma4MassSpecGYm \
  --csv examples/tiny_massspecgym.csv \
  --workers 1 \
  --ppm 10 \
  --annotated-output outputs/direct/annotations.json \
  --output outputs/direct/summary.csv
```

直接入口保留原行为：会覆盖指定输出；`--output` 和 `--annotated-output`
请使用含目录部分的路径。推荐 RA 使用上面的包装脚本，以避免覆盖旧结果并保存日志。
也支持 `python fragments/magma/op/Magma4MassSpecGYm.py --help`。

默认候选扩展深度为 3。`max_broken_bonds=6` 是底层参数，不能简单解释为“最多
切断六根键”；其含义及当前限制见已知问题文档。

## 6. 输出含义

CSV 模式的 JSON 顶层包含 `stage`、`samples` 和最终的 `n_annotated`。
每个成功生成的 sample 包含：

| 字段 | 含义 |
|---|---|
| `peak_annotations` | 实测峰和所选匹配碎片；未匹配峰也会保留 |
| `fragment_graph` | 全部候选节点和父子边，包括未匹配候选 |
| `autoregressive_targets` | 每个匹配碎片选出的一条根到碎片路径 |
| `annotations` | 同时保留的旧格式，与新格式存在重复 |
| `n_peaks` / `n_matched` | 峰数量与匹配数量 |

匹配先最小化 PPM 误差，再对误差完全相同的候选比较分数。失败样本会进入摘要
CSV，但不会作为正常 sample 写入标注 JSON。峰记录可能按匹配状态重新排列，
应使用 `peak_id` 对齐，不要直接依赖数组位置。

## 7. 文件与验证记录

- [已知问题及真实样本检查](docs/KNOWN_ISSUES.md)
- [打包范围和改动记录](docs/PACKAGING.md)
- [本次运行验证](docs/VALIDATION.md)
- `source_manifest.json`：原始文件 SHA-256 和源环境版本
- `NOTICE.md`：来源和交接范围

仓库只包含代码、说明和两条合成示例。完整数据、模型和访问凭据由项目负责人
单独提供。本仓库已公开，可直接分享链接、浏览和克隆，无需单独邀请。
