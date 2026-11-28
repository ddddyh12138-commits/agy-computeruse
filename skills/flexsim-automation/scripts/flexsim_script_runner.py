# -*- coding: utf-8 -*-
"""FlexSim 2022 CLI FlexScript 自动化封装器（适用于完整授权版）。

通过 `flexsim.exe "<model.fsm>" /maintenance nogui_disablemsg_runscript /scriptpath "<script.txt>"`
执行无头建模检查、仿真运行与统计导出。若本机处于 Express 版（无头脚本被限制），
请使用 flexsim_env_probe.ps1 确认后切换至混合 GUI 通道。
"""

import argparse
import os
import subprocess
import sys
import tempfile

DEFAULT_FLEXSIM_EXE = r"C:\Program Files\FlexSim 2022 Update 2\program\flexsim.exe"


def build_inspect_script(out_json_path: str) -> str:
    out_esc = out_json_path.replace("\\", "/")
    return f"""
treenode m = Model.find("Model");
if (!objectexists(m)) m = node("MODEL:/");
fileopen("{out_esc}", "w");
filewrite("[\\n");
int n = content(m);
int first = 1;
for (int i = 1; i <= n; i++) {{
    Object obj = rank(m, i);
    if (!objectexists(obj)) continue;
    string nm = getname(obj);
    if (nm == "Tools" || nm == "Views") continue;
    if (!first) filewrite(",\\n");
    first = 0;
    double x = xloc(obj);
    double y = yloc(obj);
    int nin = nrin(obj);
    int nout = nrop(obj);
    int nctr = nrcenter(obj);
    filewrite("  {{\\"name\\": \\"" + nm + "\\", \\"x\\": " + string.fromNum(x, 2) + ", \\"y\\": " + string.fromNum(y, 2) + ", \\"in\\": " + string.fromNum(nin) + ", \\"out\\": " + string.fromNum(nout) + ", \\"center\\": " + string.fromNum(nctr) + "}}");
}}
filewrite("\\n]\\n");
fileclose();
cmdexit();
"""


def build_run_export_script(stop_time: float, out_csv_path: str) -> str:
    out_esc = out_csv_path.replace("\\", "/")
    return f"""
resetmodel();
stoptime({stop_time});
runspeed(100000);
go();
// 等待主线程推进至停止时间后导出各对象输入/输出/当前内容
treenode m = node("MODEL:/");
fileopen("{out_esc}", "w");
filewrite("name,input,output,content\\n");
int n = content(m);
for (int i = 1; i <= n; i++) {{
    Object obj = rank(m, i);
    if (!objectexists(obj)) continue;
    string nm = getname(obj);
    if (nm == "Tools" || nm == "Views") continue;
    double inp = getinput(obj);
    double outp = getoutput(obj);
    double cur = content(obj);
    filewrite(nm + "," + string.fromNum(inp, 0) + "," + string.fromNum(outp, 0) + "," + string.fromNum(cur, 0) + "\\n");
}}
fileclose();
cmdexit();
"""


def run_flexsim_script(flex_exe: str, model_path: str, script_content: str, timeout_sec: int) -> int:
    if not os.path.isfile(flex_exe):
        print(f"错误：未找到 FlexSim 可执行文件：{flex_exe}", file=sys.stderr)
        return 1
    if not os.path.isfile(model_path):
        print(f"错误：未找到模型文件：{model_path}", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory(prefix="flexsim_cli_") as tmpdir:
        script_path = os.path.join(tmpdir, "run.txt")
        with open(script_path, "w", encoding="ascii", errors="replace") as f:
            f.write(script_content.strip() + "\n")

        cmd = [
            flex_exe,
            os.path.abspath(model_path),
            "/maintenance",
            "nogui_disablemsg_runscript",
            "/scriptpath",
            script_path,
        ]
        try:
            proc = subprocess.run(cmd, timeout=timeout_sec, check=False)
            return proc.returncode
        except subprocess.TimeoutExpired:
            print(
                f"超时（>{timeout_sec}s）：FlexSim CLI 脚本未能在限定时间内退出。"
                "如果本机为 FlexSim Express 免费版，无头脚本受限属于正常现象，请切换为通道 3（agent-desktop GUI 闭环）。",
                file=sys.stderr,
            )
            return 2


def main() -> int:
    parser = argparse.ArgumentParser(description="FlexSim 2022 CLI FlexScript 自动化封装器（完整授权版）")
    parser.add_argument("--flexsim-exe", default=DEFAULT_FLEXSIM_EXE, help="flexsim.exe 路径")
    parser.add_argument("--timeout", type=int, default=60, help="命令执行超时时间（秒）")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_ins = sub.add_parser("inspect-model", help="导出模型对象坐标与端口数量到 JSON")
    p_ins.add_argument("model", help=".fsm/.fsx 模型路径")
    p_ins.add_argument("--out", required=True, help="输出 JSON 文件路径")

    p_run = sub.add_parser("run-and-export", help="重置并运行仿真至指定时间，导出对象统计 CSV")
    p_run.add_argument("model", help=".fsm/.fsx 模型路径")
    p_run.add_argument("--stop-time", type=float, required=True, help="仿真停止时间（模型时钟秒数）")
    p_run.add_argument("--out", required=True, help="输出 CSV 文件路径")

    p_exec = sub.add_parser("exec", help="执行自定义 FlexScript 文件")
    p_exec.add_argument("model", help=".fsm/.fsx 模型路径")
    p_exec.add_argument("--script", required=True, help="FlexScript 脚本文件路径")

    args = parser.parse_args()

    if args.cmd == "inspect-model":
        code = build_inspect_script(os.path.abspath(args.out))
    elif args.cmd == "run-and-export":
        code = build_run_export_script(args.stop_time, os.path.abspath(args.out))
    else:
        with open(args.script, "r", encoding="utf-8") as sf:
            code = sf.read()

    rc = run_flexsim_script(args.flexsim_exe, args.model, code, args.timeout)
    if rc == 0 and args.cmd in ("inspect-model", "run-and-export"):
        if os.path.isfile(args.out):
            print(f"已成功导出结果：{os.path.abspath(args.out)}")
        else:
            print("FlexSim 已退出，但未生成预期输出文件（请检查本机授权或脚本权限）。", file=sys.stderr)
            return 3
    return rc


if __name__ == "__main__":
    sys.exit(main())
