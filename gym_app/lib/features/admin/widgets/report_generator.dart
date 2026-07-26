import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/app_strings.dart';
import '../../../../data/models/user_model.dart';
import '../../../../shared/providers/global_providers.dart';

/// Gerador de relatório PDF — GYMBT Lime+Dark.
class ReportGenerator {
  final WidgetRef ref;
  final UserModel aluno;

  ReportGenerator({required this.ref, required this.aluno});

  Future<void> generatePDF(BuildContext context) async {
    try {
      final progressList = await ref.read(progressRepositoryProvider).getHistory(aluno.uid);
      final pdf = pw.Document();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context pdfContext) => [
          pw.Center(child: pw.Text(AppStrings.reportTitle, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text('${AppStrings.reportFor} ${aluno.nome}', style: const pw.TextStyle(fontSize: 16))),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text('${AppStrings.generatedOn} ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey))),
          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.SizedBox(height: 16),
          pw.Header(text: 'Dados do Aluno'),
          pw.Text('Nome: ${aluno.nome}'),
          pw.Text('E-mail: ${aluno.email}'),
          if (aluno.pesoAtual != null) pw.Text('Peso atual: ${aluno.pesoAtual} kg'),
          if (aluno.altura != null) pw.Text('Altura: ${aluno.altura} cm'),
          if (aluno.imc != null) pw.Text('IMC: ${aluno.imc!.toStringAsFixed(1)} (${aluno.imcCategory})'),
          pw.SizedBox(height: 24),
          pw.Header(text: 'Histórico de Progresso'),
          if (progressList.isEmpty)
            pw.Text('Nenhum registo de progresso disponível.')
          else
            ...progressList.map((p) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(children: [
                    pw.Text(DateFormat('dd/MM/yyyy').format(p.data), style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(width: 16),
                    if (p.peso != null) pw.Text('Peso: ${p.peso} kg'),
                  ]),
                )),
          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.Center(child: pw.Text('Gerado por GYMBT - Personal Trainer', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey))),
        ],
      ));

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'relatorio_${aluno.nome}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao gerar relatório PDF.'), backgroundColor: AppColors.adminDanger),
        );
      }
    }
  }
}
