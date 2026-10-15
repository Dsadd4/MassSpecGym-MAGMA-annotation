# 本次交接验证

日期：2026-10-14。验证在原 A800 计算容器的独立临时目录进行，没有修改原 UltraGo
代码和完整数据。该容器的 cgroup CPU quota 为 8 核，本次最多使用 2 个 worker，
并将 OpenMP/OpenBLAS/MKL 线程限制为 1。Python 为 3.13.2。

## 已通过

| 检查 | 结果 |
|---|---|
| 本地 Python 源码语法、启动脚本 Bash 语法 | 通过 |
| 模块入口 `python -m ... --help` | 通过 |
| 直接脚本入口 `python fragments/magma/op/Magma4MassSpecGYm.py --help` | 通过 |
| 2 条合成 CSV，1 worker，显式 `--no-canonicalize` | 2/2 成功 |
| 相同 CSV，2 workers，显式 `--no-canonicalize` | 2/2 成功 |
| 相同 CSV，默认规范化，1 worker | 2/2 成功 |
| 单进程和多进程解析后的标注输出一致 | 通过 |
| JSON 顶层计数、sample schema、峰数量、匹配数量 | 通过 |
| 候选图根存在、图边和峰引用的节点存在 | 通过 |
| 再用已有输出目录执行包装脚本 | 退出码 2，原输出保持原样 |
| 额外参数试图改写 CSV、worker 数和输出路径 | 包装脚本的受管值保持生效，原输出未改写 |
| 阻止可选 h5py/multiprocess/pathos 导入后加载生成入口 | 通过 |
| 原源码与来源 SHA-256 对比 | 仅生成入口的仓库根路径定位有变化 |
| 私有目录路径、访问密钥和登录凭据扫描 | 未发现这些内容 |

机器可读记录及示例输出校验值见 [validation_results.json](validation_results.json)。
初次语法检查发现保留的 `chem_utils.py` 有旧正则字符串的 SyntaxWarning，未阻止
运行；本次未改写这段非入口逻辑。

## 结果的适用范围

这些是安装接口、源码打包和输出结构检查。它们不构成正式 benchmark，也不验证
真实谱图的结构标注准确率、候选覆盖率或现有大型数据集的完整性。

使用的是源机器现有环境，而非新建空环境。requirements 固定的是本次实际运行
版本；未在所有操作系统或其他 Python 版本上验证。已知算法和标签问题仍见
[KNOWN_ISSUES.md](KNOWN_ISSUES.md)。

生成器没有实现断点续算，本次也没有对此作成功承诺。任何正式数据重跑应使用
独立输出目录、保存输入版本，并明确完成与失败样本。
