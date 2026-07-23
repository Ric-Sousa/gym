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

/// Gerador de relatório PDF do progresso do aluno.
class ReportGenerator {
  final WidgetRef ref;
  final UserModel aluno;

  ReportGenerator({required this.ref, required this.aluno});

  /// Gera e partilha o PDF.
  Future<void> generatePDF(BuildContext context) async {
    try {
      // Obter dados de progresso
      final progressList =
          await ref.read(progressRepositoryProvider).getHistory(aluno.uid);

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context pdfContext) {
            return [
              // Título
              pw.Center(
                child: pw.Text(
                  AppStrings.reportTitle,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  '${AppStrings.reportFor} ${aluno.nome}',
                  style: const pw.TextStyle(fontSize: 16),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  '${AppStrings.generatedOn} ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey,
                  ),
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Divider(),
              pw.SizedBox(height: 16),

              // Info do aluno
              pw.Header(text: 'Dados do Aluno'),
              pw.Text('Nome: ${aluno.nome}'),
              pw.Text('E-mail: ${aluno.email}'),
              if (aluno.pesoAtual != null)
                pw.Text('Peso atual: ${aluno.pesoAtual} kg'),
              if (aluno.altura != null)
                pw.Text('Altura: ${aluno.altura} cm'),
              if (aluno.imc != null)
                pw.Text(
                    'IMC: ${aluno.imc!.toStringAsFixed(1)} (${aluno.imcCategory})'),
              pw.SizedBox(height: 24),

              // Progresso
              pw.Header(text: 'Histórico de Progresso'),
              if (progressList.isEmpty)
                pw.Text('Nenhum registo de progresso disponível.')
              else
                ...progressList.map((p) {
                  final date =
                      DateFormat('dd/MM/yyyy').format(p.data);
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Row(
                      children: [
                        pw.Text(date, style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(width: 16),
                        if (p.peso != null)
                          pw.Text('Peso: ${p.peso} kg'),
                      ],
                    ),
                  );
                }),
              pw.SizedBox(height: 24),

              // Rodapé
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  'Gerado por PersonalFit - App de Personal Trainer',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              ),
            ];
          },
        ),
      );

      // Mostrar preview e opção de imprimir/partilhar
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'relatorio_${aluno.nome}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao gerar relatório PDF.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
