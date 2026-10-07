"""生成用于 App 导入测试的微信支付风格 xlsx 账单。"""

from __future__ import annotations

from datetime import datetime
from pathlib import Path

from openpyxl import Workbook

HEADERS = (
    "交易时间",
    "交易类型",
    "交易对方",
    "商品",
    "收/支",
    "金额(元)",
    "支付方式",
    "当前状态",
    "交易单号",
    "商户单号",
    "备注",
)

def _dt(dt: datetime) -> str:
    """与微信导出一致，用文本时间，避免 Dart excel 包解析空 inlineStr / 日期样式出错。"""
    return dt.strftime("%Y-%m-%d %H:%M:%S")


# (交易时间文本, 交易类型, 交易对方, 商品, 收/支, 金额)
OCT_2025_ROWS = [
    (_dt(datetime(2025, 10, 1, 12, 30, 0)), "商户消费", "美团外卖", "午餐", "支出", 28.50),
    (_dt(datetime(2025, 10, 3, 8, 15, 0)), "商户消费", "滴滴出行", "快车", "支出", 15.00),
    (_dt(datetime(2025, 10, 5, 19, 40, 0)), "商户消费", "盒马鲜生", "日用品", "支出", 86.20),
    (_dt(datetime(2025, 10, 8, 14, 0, 0)), "转账", "张三", "转账备注", "支出", 200.00),
    (_dt(datetime(2025, 10, 12, 9, 20, 0)), "商户消费", "星巴克", "拿铁", "支出", 32.00),
    (_dt(datetime(2025, 10, 15, 20, 0, 0)), "微信红包", "发出群红包", "/", "支出", 50.00),
    (_dt(datetime(2025, 10, 20, 11, 5, 0)), "商户消费", "京东商城", "数码配件", "支出", 199.00),
    (_dt(datetime(2025, 10, 22, 18, 30, 0)), "商户消费", "上海地铁", "交通", "支出", 4.00),
    (_dt(datetime(2025, 10, 25, 10, 0, 0)), "转账", "李四", "还餐费", "收入", 500.00),
    (_dt(datetime(2025, 10, 28, 16, 45, 0)), "商户消费", "肯德基", "晚餐", "支出", 35.80),
]


def build_workbook() -> Workbook:
    wb = Workbook()
    ws = wb.active
    ws.title = "Sheet1"
    ws.append(["微信支付账单明细"])
    ws.append(["起始时间：2025-10-01 00:00:00  终止时间：2025-10-31 23:59:59"])
    ws.append(list(HEADERS))
    for i, row in enumerate(OCT_2025_ROWS, start=1):
        dt, tx_type, party, goods, flow, amount = row
        ws.append(
            [
                dt,
                tx_type,
                party,
                goods,
                flow,
                amount,
                "零钱",
                "支付成功",
                f"4200002510{i:04d}",
                f"M202510{i:04d}",
                "/",
            ]
        )
    return wb


def _fix_workbook_rel_paths(xlsx: Path) -> None:
    """Dart excel 包需要相对 Target，openpyxl 默认写 /xl/...。"""
    import io
    import zipfile

    buf = io.BytesIO()
    with zipfile.ZipFile(xlsx, "r") as zin, zipfile.ZipFile(buf, "w") as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == "xl/_rels/workbook.xml.rels":
                text = data.decode("utf-8")
                text = text.replace('Target="/xl/', 'Target="').replace(
                    "Target='/xl/", "Target='"
                )
                data = text.encode("utf-8")
            zout.writestr(item, data)
    xlsx.write_bytes(buf.getvalue())


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    out = root / "sample_data" / "微信支付账单_2025年10月_测试.xlsx"
    out.parent.mkdir(parents=True, exist_ok=True)
    build_workbook().save(out)
    _fix_workbook_rel_paths(out)
    print(f"已生成: {out}")
    print(f"共 {len(OCT_2025_ROWS)} 笔（2025 年 10 月）")


if __name__ == "__main__":
    main()
