import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/CaptionsAndTranscriptionModel.dart';
import 'CaptionController.dart';

class FileTranscriptionController extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────
  static final FileTranscriptionController instance =
  FileTranscriptionController._internal();
  FileTranscriptionController._internal();

  // ── State ──────────────────────────────────────────────────────────
  bool isGenerating = false;
  bool isDownloading = false;
  String? lastError;

  // ── Generate PDF bytes from caption entries ────────────────────────
  Future<Uint8List?> generateTranscriptionFile({
    required String meetingId,
    required List<CaptionEntry> entries,
    required DateTime meetingDate,
  }) async {
    if (entries.isEmpty) {
      lastError = 'لا يوجد نص لتصديره';
      notifyListeners();
      return null;
    }

    isGenerating = true;
    lastError = null;
    notifyListeners();

    try {
      final arabicFont = await PdfGoogleFonts.cairoRegular();
      final arabicFontBold = await PdfGoogleFonts.cairoBold();

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(
            base: arabicFont,
            bold: arabicFontBold,
          ),

          // Header
          header: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    meetingDate.toString().substring(0, 16),
                    style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 10,
                        color: PdfColors.grey600),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'نسخة الاجتماع',
                        style: pw.TextStyle(
                          font: arabicFontBold,
                          fontSize: 20,
                          color: PdfColor.fromHex('#FFB382'),
                        ),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.Text(
                        'رقم: $meetingId',
                        style: pw.TextStyle(
                            font: arabicFont,
                            fontSize: 10,
                            color: PdfColors.grey600),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(
                  color: PdfColor.fromHex('#FFB382'), thickness: 1.5),
              pw.SizedBox(height: 10),
            ],
          ),

          // Footer
          footer: (ctx) => pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Turjuman',
                      style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 9,
                          color: PdfColors.grey400)),
                  pw.Text(
                    'صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
                    style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 9,
                        color: PdfColors.grey400),
                    textDirection: pw.TextDirection.rtl,
                  ),
                ],
              ),
            ],
          ),

          // Content
          build: (_) {
            final widgets = <pw.Widget>[];

            // Summary box
            final speakerCount =
                entries.map((e) => e.userName).toSet().length;
            widgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                margin: const pw.EdgeInsets.only(bottom: 16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FFF9E3'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(
                      color: PdfColor.fromHex('#FFB382'), width: 1),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(children: [
                      pw.Text('${entries.length}',
                          style: pw.TextStyle(
                              font: arabicFontBold,
                              fontSize: 18,
                              color: PdfColor.fromHex('#FFB382'))),
                      pw.Text('جملة',
                          style: pw.TextStyle(
                              font: arabicFont,
                              fontSize: 10,
                              color: PdfColors.grey600),
                          textDirection: pw.TextDirection.rtl),
                    ]),
                    pw.Column(children: [
                      pw.Text('$speakerCount',
                          style: pw.TextStyle(
                              font: arabicFontBold,
                              fontSize: 18,
                              color: PdfColor.fromHex('#FFB382'))),
                      pw.Text('متحدث',
                          style: pw.TextStyle(
                              font: arabicFont,
                              fontSize: 10,
                              color: PdfColors.grey600),
                          textDirection: pw.TextDirection.rtl),
                    ]),
                  ],
                ),
              ),
            );

            // Each caption entry
            for (final entry in entries) {
              final time =
                  '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
                  '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
                  '${entry.timestamp.second.toString().padLeft(2, '0')}';

              widgets.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    border: pw.Border(
                      left: pw.BorderSide(
                          color: PdfColor.fromHex('#FFB382'), width: 3),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(time,
                              style: pw.TextStyle(
                                  font: arabicFont,
                                  fontSize: 9,
                                  color: PdfColors.grey500)),
                          pw.Text(entry.userName,
                              style: pw.TextStyle(
                                font: arabicFontBold,
                                fontSize: 11,
                                color: PdfColor.fromHex('#FFB382'),
                              ),
                              textDirection: pw.TextDirection.rtl),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(entry.text,
                          style:
                          pw.TextStyle(font: arabicFont, fontSize: 13),
                          textDirection: pw.TextDirection.rtl),
                    ],
                  ),
                ),
              );
            }

            return widgets;
          },
        ),
      );

      final bytes = await pdf.save();

      // Save path back to Firestore
      await FirebaseFirestore.instance
          .collection(kCaptionsCollection)
          .doc(meetingId)
          .update({
        'transcriptionFilePath': 'transcription_$meetingId.pdf',
        'isCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      isGenerating = false;
      notifyListeners();
      return bytes;
    } catch (e) {
      lastError = 'فشل إنشاء الملف: $e';
      isGenerating = false;
      notifyListeners();
      debugPrint('❌ generateTranscriptionFile error: $e');
      return null;
    }
  }

  // ── Download: generate PDF then open system share sheet ───────────
  Future<void> downloadTranscription({
    required String meetingId,
    required List<CaptionEntry> entries,
    required DateTime meetingDate,
  }) async {
    isDownloading = true;
    lastError = null;
    notifyListeners();

    final bytes = await generateTranscriptionFile(
      meetingId: meetingId,
      entries: entries,
      meetingDate: meetingDate,
    );

    if (bytes != null) {
      try {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: 'transcription_$meetingId.pdf',
        );
      } catch (e) {
        lastError = 'فشل التنزيل: $e';
        debugPrint('❌ downloadTranscription error: $e');
      }
    }

    isDownloading = false;
    notifyListeners();
  }
}