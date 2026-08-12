import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

import openpyxl


SCRIPT_PATH = Path(__file__).parents[1] / "scripts" / "tc_md_to_excel.py"
SPEC = importlib.util.spec_from_file_location("tc_md_to_excel", SCRIPT_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class MarkdownParserTest(unittest.TestCase):
    def parse(self, case_line: str):
        content = "\n".join([
            "# 入库模块",
            "## 收货",
            "### [TC-RK-001] 完成收货",
            case_line,
            "- **数据依赖**：无",
        ])
        cases = MODULE.MarkdownParser(content, "TC-入库.md").parse()
        self.assertEqual(1, len(cases))
        return cases[0]

    def test_parses_unchecked_obsidian_case(self):
        case = self.parse(
            "- [ ] 1️⃣  已登录;已有入库单 | 打开入库单;点击完成 | 状态变为已完成"
        )

        self.assertEqual("P0", case.priority)
        self.assertEqual("未执行", case.test_result)
        self.assertEqual("已登录\n已有入库单", case.precondition)
        self.assertEqual("打开入库单\n点击完成", case.steps)
        self.assertEqual("状态变为已完成", case.expected)

    def test_parses_checked_obsidian_case(self):
        case = self.parse("- [x] 4️⃣  已登录 | 打开帮助 | 显示帮助内容")

        self.assertEqual("P3", case.priority)
        self.assertEqual("已执行", case.test_result)

    def test_preserves_legacy_case_format(self):
        case = self.parse(
            "- [P1] 已登录 | 点击提交 | 提交成功 | - [x] 通过 - [ ] 未通过"
        )

        self.assertEqual("P1", case.priority)
        self.assertEqual("测试通过", case.test_result)

    def test_parses_legacy_obsidian_task_format(self):
        case = self.parse(
            "- [x] [P0][复测] 已登录 | 点击提交 | 提交成功"
        )

        self.assertEqual("P0", case.priority)
        self.assertEqual("已执行", case.test_result)
        self.assertEqual("已登录", case.precondition)

    def test_maps_all_obsidian_priorities(self):
        for icon, expected in MODULE.TASK_PRIORITY_MAP.items():
            with self.subTest(icon=icon):
                case = self.parse(f"- [ ] {icon}  条件 | 步骤 | 预期")
                self.assertEqual(expected, case.priority)


class ExcelGeneratorTest(unittest.TestCase):
    def test_generates_nine_column_workbook(self):
        content = "\n".join([
            "# 入库模块",
            "## 收货",
            "### [TC-RK-001] 完成收货",
            "- [x] 2️⃣  已登录 | 点击完成 | 状态变为已完成",
        ])
        cases = MODULE.MarkdownParser(content, "TC-入库.md").parse()
        MODULE.generate_case_numbers(cases)

        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "cases.xlsx"
            MODULE.ExcelGenerator(cases).generate(str(output))
            worksheet = openpyxl.load_workbook(output).active

            self.assertEqual(9, worksheet.max_column)
            self.assertEqual("P1", worksheet["D2"].value)
            self.assertEqual("已执行", worksheet["I2"].value)


if __name__ == "__main__":
    unittest.main()
