# -*- coding: utf-8 -*-
"""FlexSim .fsx XML 模型离线结构与连接拓扑审计工具。

仅使用 Python 标准库解析 FlexSim 保存的 .fsx XML 模型文件，提取：
1. 模型内主要 3D 对象名称、类型/超类与空间坐标；
2. 每个对象的输入端口（connectionsin）、输出端口（connectionsout）与居中端口（connectionscenter）；
3. 常见关键参数文本片段，以及指定对象的连接隔离检查（用于对比实验防串扰）。
"""

import argparse
import json
import os
import sys
import xml.etree.ElementTree as ET
from typing import Any, Dict, List, Optional


def _node_name(elem: ET.Element) -> str:
    return elem.attrib.get("name") or elem.attrib.get("n") or ""


def _child_by_name(elem: ET.Element, target: str) -> Optional[ET.Element]:
    for child in elem:
        if _node_name(child) == target:
            return child
    return None


def _read_text_value(elem: Optional[ET.Element]) -> str:
    if elem is None:
        return ""
    if "val" in elem.attrib:
        return elem.attrib["val"].strip()
    if elem.text and elem.text.strip():
        return elem.text.strip()
    return ""


def _find_model_root(root: ET.Element) -> Optional[ET.Element]:
    # 常见 .fsx 结构：flexsim-tree -> node(name="MAIN:") / node(name="MODEL:") 或直接包含 model 子树
    for elem in root.iter():
        name = _node_name(elem).lower()
        if name in ("model", "model:"):
            if any(_child_by_name(c, "connectionsin") is not None or _child_by_name(c, "spatialx") is not None for c in elem):
                return elem
    # 回退：找包含最多空间属性子节点的容器
    best_elem = None
    best_score = 0
    for elem in root.iter():
        score = sum(
            1
            for c in elem
            if _child_by_name(c, "spatialx") is not None
            or _child_by_name(c, "connectionsout") is not None
            or _child_by_name(c, "connectionscenter") is not None
        )
        if score > best_score:
            best_score = score
            best_elem = elem
    return best_elem


def _extract_connections(obj_elem: ET.Element, conn_tag: str) -> List[str]:
    conn_node = _child_by_name(obj_elem, conn_tag)
    if conn_node is None:
        return []
    targets: List[str] = []
    for sub in conn_node:
        # FlexSim XML 中连接子节点常以耦合路径或目标名存储在文本/属性中
        val = _read_text_value(sub)
        sub_name = _node_name(sub)
        candidate = val or sub_name
        if candidate:
            # 提取路径末尾对象名（如 /Tools/... 或 MODEL:/Processor1 -> Processor1）
            cleaned = candidate.split("/")[-1].strip()
            if cleaned and cleaned not in targets:
                targets.append(cleaned)
    return targets


def _extract_key_params(obj_elem: ET.Element) -> Dict[str, str]:
    interesting = (
        "cycletime",
        "maxcontent",
        "interarrivaltime",
        "useoperator",
        "transportreference",
        "dispatchertask",
        "speed",
        "setuptime",
    )
    params: Dict[str, str] = {}
    for elem in obj_elem.iter():
        name = _node_name(elem).lower()
        if name in interesting:
            val = _read_text_value(elem)
            if val:
                params[name] = val
    return params


def parse_fsx(fsx_path: str) -> Dict[str, Any]:
    tree = ET.parse(fsx_path)
    root = tree.getroot()
    model_root = _find_model_root(root)
    if model_root is None:
        raise ValueError("未能在 .fsx 文件中找到有效的模型对象树（可能文件非标准 FlexSim XML 格式）。")

    objects: List[Dict[str, Any]] = []
    for child in model_root:
        name = _node_name(child)
        if not name or name.lower() in ("tools", "views", "statistics", "variables"):
            continue
        has_spatial = _child_by_name(child, "spatialx") is not None
        conn_in = _extract_connections(child, "connectionsin")
        conn_out = _extract_connections(child, "connectionsout")
        conn_center = _extract_connections(child, "connectionscenter")
        if not (has_spatial or conn_in or conn_out or conn_center):
            continue

        sx = _read_text_value(_child_by_name(child, "spatialx"))
        sy = _read_text_value(_child_by_name(child, "spatialy"))
        sz = _read_text_value(_child_by_name(child, "spatialz"))
        cls = _read_text_value(_child_by_name(child, "classes")) or child.attrib.get("class", "")

        objects.append(
            {
                "name": name,
                "class": cls,
                "coords": {"x": sx, "y": sy, "z": sz},
                "connections_in": conn_in,
                "connections_out": conn_out,
                "connections_center": conn_center,
                "params": _extract_key_params(child),
            }
        )

    return {"file": os.path.abspath(fsx_path), "object_count": len(objects), "objects": objects}


def render_markdown(report: Dict[str, Any], check_isolated: Optional[str] = None) -> str:
    lines: List[str] = []
    lines.append(f"# FlexSim 模型离线审计报告")
    lines.append(f"- 文件：`{report['file']}`")
    lines.append(f"- 识别到的 3D 对象数：**{report['object_count']}**")
    lines.append("")
    lines.append("| 对象名称 | 坐标 (X, Y, Z) | 输入端口 (A-In) | 输出端口 (A-Out) | 居中端口 (S-Center) |")
    lines.append("| :--- | :--- | :--- | :--- | :--- |")
    for obj in report["objects"]:
        c = obj["coords"]
        coord_str = f"({c['x'] or '-'}, {c['y'] or '-'}, {c['z'] or '-'})"
        in_str = ", ".join(obj["connections_in"]) or "—"
        out_str = ", ".join(obj["connections_out"]) or "—"
        ctr_str = ", ".join(obj["connections_center"]) or "—"
        lines.append(f"| `{obj['name']}` | {coord_str} | {in_str} | {out_str} | {ctr_str} |")

    if check_isolated:
        lines.append("")
        lines.append(f"## 隔离性专项检查：`{check_isolated}`")
        found = next((o for o in report["objects"] if o["name"] == check_isolated), None)
        if not found:
            lines.append(f"- 未在模型中找到名为 `{check_isolated}` 的对象。")
        else:
            leaks = found["connections_in"] + found["connections_out"] + found["connections_center"]
            refs = [
                o["name"]
                for o in report["objects"]
                if check_isolated in (o["connections_in"] + o["connections_out"] + o["connections_center"])
            ]
            if not leaks and not refs:
                lines.append(f"- 状态：**已完全隔离**（无输入/输出/居中端口连接，也未被其他对象端口引用）。")
            else:
                lines.append(f"- 状态：**存在残留连接（未完全隔离）**")
                if leaks:
                    lines.append(f"  - 自身端口连接：{', '.join(leaks)}")
                if refs:
                    lines.append(f"  - 被以下对象端口引用：{', '.join(refs)}")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="FlexSim .fsx XML 模型离线结构与拓扑审计器")
    parser.add_argument("fsx_path", help=".fsx 模型文件路径")
    parser.add_argument("--format", choices=("markdown", "json"), default="markdown", help="输出格式")
    parser.add_argument("--check-isolated", default="", help="检查指定对象（如多余操作员）是否已彻底断开端口")
    args = parser.parse_args()

    if not os.path.isfile(args.fsx_path):
        print(f"错误：找不到文件 {args.fsx_path}", file=sys.stderr)
        return 1

    try:
        report = parse_fsx(args.fsx_path)
    except Exception as exc:
        print(f"解析 .fsx 失败：{exc}", file=sys.stderr)
        return 1

    if args.format == "json":
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(render_markdown(report, check_isolated=args.check_isolated or None))
    return 0


if __name__ == "__main__":
    sys.exit(main())
