// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

/// PDF-like HTML report export utility.
/// Generates a printable HTML report and opens in a new tab for PDF saving.
/// This approach avoids heavy PDF dependencies while producing professional output.
class PdfExportUtil {
  PdfExportUtil._();

  /// Export a report as a printable HTML page (user can save as PDF from browser)
  static void exportAsHtml({
    required String title,
    required String subtitle,
    required List<ReportSection> sections,
    String? footer,
  }) {
    final html_ = _buildHtmlReport(title, subtitle, sections, footer);
    final blob = html.Blob([html_], 'text/html;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.window.open(url, '_blank');

    // Clean up after a delay
    Future.delayed(const Duration(seconds: 2), () {
      html.Url.revokeObjectUrl(url);
    });
  }

  /// Export data as Excel-compatible CSV with proper Arabic encoding
  static void exportExcel({required String filename, required List<String> headers, required List<List<String>> rows}) {
    final csv = StringBuffer();
    // UTF-8 BOM for Excel Arabic support
    csv.write('\uFEFF');
    csv.writeln(headers.join(','));

    for (final row in rows) {
      csv.writeln(row.map(_escapeCsvValue).join(','));
    }

    final bytes = utf8.encode(csv.toString());
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute('download', '$filename.csv')
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  static String _escapeCsvValue(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _buildHtmlReport(String title, String subtitle, List<ReportSection> sections, String? footer) {
    final buffer = StringBuffer();
    buffer.writeln('''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
  <meta charset="UTF-8">
  <title>$title</title>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Tajawal:wght@300;400;500;700&display=swap');
    
    * { box-sizing: border-box; margin: 0; padding: 0; }
    
    body {
      font-family: 'Tajawal', sans-serif;
      direction: rtl;
      padding: 40px;
      color: #212529;
      line-height: 1.6;
      max-width: 900px;
      margin: 0 auto;
    }
    
    .header {
      text-align: center;
      margin-bottom: 32px;
      padding-bottom: 24px;
      border-bottom: 3px solid #00704A;
    }
    
    .header h1 {
      font-size: 28px;
      color: #00704A;
      margin-bottom: 8px;
    }
    
    .header p {
      color: #6B7280;
      font-size: 14px;
    }
    
    .section {
      margin-bottom: 32px;
    }
    
    .section h2 {
      font-size: 20px;
      color: #00704A;
      margin-bottom: 16px;
      padding-bottom: 8px;
      border-bottom: 1px solid #E5E7EB;
    }
    
    .kpi-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 16px;
      margin-bottom: 24px;
    }
    
    .kpi-card {
      background: #F8F9FA;
      border: 1px solid #E5E7EB;
      border-radius: 8px;
      padding: 16px;
      text-align: center;
    }
    
    .kpi-card .value {
      font-size: 28px;
      font-weight: 700;
      color: #00704A;
    }
    
    .kpi-card .label {
      font-size: 13px;
      color: #6B7280;
      margin-top: 4px;
    }
    
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 16px 0;
      font-size: 14px;
    }
    
    th, td {
      padding: 10px 12px;
      text-align: right;
      border-bottom: 1px solid #E5E7EB;
    }
    
    th {
      background: #F8F9FA;
      font-weight: 600;
      color: #374151;
    }
    
    tr:hover { background: #F9FAFB; }
    
    .footer {
      margin-top: 40px;
      padding-top: 16px;
      border-top: 1px solid #E5E7EB;
      text-align: center;
      color: #9CA3AF;
      font-size: 12px;
    }
    
    @media print {
      body { padding: 20px; }
      .no-print { display: none; }
    }
  </style>
</head>
<body>
  <div class="no-print" style="text-align:center;margin-bottom:20px;">
    <button onclick="window.print()" style="background:#00704A;color:white;border:none;padding:10px 24px;border-radius:6px;cursor:pointer;font-family:Tajawal;font-size:14px;">
      طباعة / حفظ كـ PDF
    </button>
  </div>
  
  <div class="header">
    <h1>$title</h1>
    <p>$subtitle</p>
    <p style="margin-top:8px;font-size:12px;">تاريخ التصدير: ${DateTime.now().toString().substring(0, 16)}</p>
  </div>
''');

    for (final section in sections) {
      buffer.writeln('<div class="section">');
      buffer.writeln('<h2>${section.title}</h2>');

      if (section.kpis != null && section.kpis!.isNotEmpty) {
        buffer.writeln('<div class="kpi-grid">');
        for (final kpi in section.kpis!) {
          buffer.writeln('''
          <div class="kpi-card">
            <div class="value">${kpi.value}</div>
            <div class="label">${kpi.label}</div>
          </div>
          ''');
        }
        buffer.writeln('</div>');
      }

      if (section.tableHeaders != null && section.tableRows != null) {
        buffer.writeln('<table>');
        buffer.writeln('<thead><tr>');
        for (final header in section.tableHeaders!) {
          buffer.writeln('<th>$header</th>');
        }
        buffer.writeln('</tr></thead>');
        buffer.writeln('<tbody>');
        for (final row in section.tableRows!) {
          buffer.writeln('<tr>');
          for (final cell in row) {
            buffer.writeln('<td>$cell</td>');
          }
          buffer.writeln('</tr>');
        }
        buffer.writeln('</tbody></table>');
      }

      if (section.notes != null) {
        buffer.writeln('<p style="color:#6B7280;font-size:13px;margin-top:12px;">${section.notes}</p>');
      }

      buffer.writeln('</div>');
    }

    buffer.writeln('''
  <div class="footer">
    ${footer ?? '© WawApp Admin - تقرير تلقائي'}
  </div>
</body>
</html>
''');

    return buffer.toString();
  }
}

/// Report section definition
class ReportSection {
  final String title;
  final List<ReportKpi>? kpis;
  final List<String>? tableHeaders;
  final List<List<String>>? tableRows;
  final String? notes;

  const ReportSection({required this.title, this.kpis, this.tableHeaders, this.tableRows, this.notes});
}

/// KPI card for report export
class ReportKpi {
  final String label;
  final String value;

  const ReportKpi({required this.label, required this.value});
}
