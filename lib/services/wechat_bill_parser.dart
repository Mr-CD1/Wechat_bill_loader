import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';

import '../models/bill_record.dart';

const _headerMarker = '交易时间';
const _columnCount = 11;

/// 解析微信支付导出的 xlsx 账单（与 Python 版逻辑一致）
class WechatBillParser {
  List<ParsedBillRow> parseBytes(Uint8List bytes) {
    final excel = Excel.decodeBytes(_prepareXlsxForParser(bytes));
    if (excel.tables.isEmpty) {
      throw FormatException('Excel 文件中没有工作表');
    }

    final sheet = excel.tables.values.first;
    if (sheet.rows.isEmpty) {
      throw FormatException('工作表为空');
    }

    final rows = sheet.rows;
    var headerIndex = -1;
    for (var i = 0; i < rows.length; i++) {
      if (_rowIsHeader(rows[i])) {
        headerIndex = i;
        break;
      }
    }

    if (headerIndex < 0) {
      throw FormatException('未找到「$_headerMarker」表头，请确认是微信支付账单');
    }

    final result = <ParsedBillRow>[];
    for (var i = headerIndex + 1; i < rows.length; i++) {
      final parsed = _parseRow(rows[i]);
      if (parsed != null) {
        result.add(parsed);
      }
    }
    return result;
  }

  bool _rowIsHeader(List<Data?> row) {
    if (row.isEmpty) return false;
    return _cellStr(row[0]?.value) == _headerMarker;
  }

  ParsedBillRow? _parseRow(List<Data?> row) {
    final cells = _normalizeRow(row);
    if (cells.every((c) => c?.value == null || _cellStr(c?.value).isEmpty)) {
      return null;
    }

    final dateStr = _excelDate(cells[0]?.value);
    final txType = _cellStr(cells[1]?.value);
    if (dateStr.isEmpty && txType.isEmpty) return null;
    if (_cellStr(cells[0]?.value) == _headerMarker) return null;

    final amount = _parseAmount(cells[5]?.value);
    if (amount == null) return null;

    final date = DateTime.tryParse(dateStr) ?? DateTime(1970);

    return ParsedBillRow(
      date: DateTime(date.year, date.month, date.day),
      transactionType: txType,
      counterparty: _cellStr(cells[2]?.value),
      flow: _cellStr(cells[4]?.value),
      amount: amount,
    );
  }

  List<Data?> _normalizeRow(List<Data?> row) {
    final list = List<Data?>.from(row);
    while (list.length < _columnCount) {
      list.add(null);
    }
    return list.take(_columnCount).toList();
  }

  String _cellStr(dynamic value) {
    if (value == null) return '';
    if (value is num && value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString().trim();
  }

  String _excelDate(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) {
      return _formatDate(value);
    }
    if (value is num) {
      final base = DateTime(1899, 12, 30);
      final dt = base.add(Duration(days: value.floor()));
      return _formatDate(dt);
    }
    final text = _cellStr(value);
    if (text.length >= 10 && text[4] == '-' && text[7] == '-') {
      return text.substring(0, 10);
    }
    return text;
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  double? _parseAmount(dynamic value) {
    if (value == null) return null;
    if (value is num) return double.parse(value.toStringAsFixed(2));
    final text = _cellStr(value).replaceAll(',', '');
    return double.tryParse(text);
  }
}

final _emptyInlineStrCell = RegExp(
  r'<c (\b[^>]*?) t="inlineStr"\s*/>',
  multiLine: true,
);

/// 兼容 openpyxl 等生成的 xlsx，避免 excel 包解析时空指针。
Uint8List _prepareXlsxForParser(Uint8List bytes) {
  const relsPath = 'xl/_rels/workbook.xml.rels';
  final archive = ZipDecoder().decodeBytes(bytes);
  var changed = false;
  final out = Archive();

  for (final file in archive.files) {
    final raw = file.content;
    if (raw == null) {
      out.addFile(file);
      continue;
    }

    var text = utf8.decode(raw as List<int>);
    final before = text;

    if (file.name == relsPath) {
      text = text
          .replaceAll('Target="/xl/', 'Target="')
          .replaceAll("Target='/xl/", "Target='");
    } else if (file.name.startsWith('xl/worksheets/') &&
        file.name.endsWith('.xml')) {
      text = text.replaceAllMapped(
        _emptyInlineStrCell,
        (m) => '<c ${m[1]} t="inlineStr"><is><t></t></is></c>',
      );
    }

    if (text != before) {
      changed = true;
      final content = utf8.encode(text);
      out.addFile(ArchiveFile(file.name, content.length, content));
    } else {
      out.addFile(file);
    }
  }

  if (!changed) return bytes;
  final encoded = ZipEncoder().encode(out);
  return encoded == null ? bytes : Uint8List.fromList(encoded);
}
