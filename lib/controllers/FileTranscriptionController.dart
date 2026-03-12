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

  // ── Generate PDF bytes ─────────────────────────────────────────────
  Future<Uint8List?> generateTranscriptionFile({
    required String meetingId,
    required List<CaptionEntry> entries,
    required DateTime meetingDate,
  }) async {
    if (entries.isEmpty) {
      lastError = 'No transcript to export';
      notifyListeners();
      return null;
    }

    isGenerating = true;
    lastError = null;
    notifyListeners();

    try {
      final pdf = pw.Document();


      final speakerCount =
          entries.map((e) => e.userName).where((n) => n.isNotEmpty).toSet().length;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),

          // ── Header ─────────────────────────────────────────────────
          header: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Meeting Transcript',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#FFB382'),
                    ),
                  ),
                  pw.Text(
                    meetingDate.toString().substring(0, 16),
                    style: pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey600),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Meeting ID: $meetingId',
                style: pw.TextStyle(
                    fontSize: 10, color: PdfColors.grey500),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(
                  color: PdfColor.fromHex('#FFB382'), thickness: 1.5),
              pw.SizedBox(height: 12),
            ],
          ),

          // ── Footer ─────────────────────────────────────────────────
          footer: (ctx) => pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Turjuman',
                      style: pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey400)),
                  pw.Text(
                    'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey400),
                  ),
                ],
              ),
            ],
          ),

          // ── Content ────────────────────────────────────────────────
          build: (_) {
            final widgets = <pw.Widget>[];

            // Summary box
            widgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                margin: const pw.EdgeInsets.only(bottom: 20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FFF9E3'),
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(
                      color: PdfColor.fromHex('#FFB382'), width: 1),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text('${entries.length}',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#FFB382'),
                            )),
                        pw.Text('Sentences',
                            style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey600)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('$speakerCount',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#FFB382'),
                            )),
                        pw.Text('Speakers',
                            style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey600)),
                      ],
                    ),
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

              final speakerName = entry.userName.isNotEmpty
                  ? entry.userName
                  : 'Unknown Speaker';

              widgets.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    border: pw.Border(
                      left: pw.BorderSide(
                          color: PdfColor.fromHex('#FFB382'),
                          width: 3),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Speaker + time row
                      pw.Row(
                        mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            speakerName,
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#FFB382'),
                            ),
                          ),
                          pw.Text(
                            time,
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey500),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      // Text
                      pw.Text(
                        entry.text,
                        style: const pw.TextStyle(fontSize: 13),
                      ),
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

      // Update Firestore
      try {
        await FirebaseFirestore.instance
            .collection(kCaptionsCollection)
            .doc(meetingId)
            .update({
          'transcriptionFilePath': 'transcript_$meetingId.pdf',
          'isCompleted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Firestore update error (non-fatal): $e');
      }

      isGenerating = false;
      notifyListeners();
      return bytes;
    } catch (e) {
      lastError = 'Failed to generate PDF: $e';
      isGenerating = false;
      debugPrint('❌ generateTranscriptionFile error: $e');
      notifyListeners();
      return null;
    }
  }

  // ── Share/download PDF via system share sheet ──────────────────────
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
        // ✅ sharePdf opens the Android share sheet directly
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'transcript_${meetingId.substring(0, 8)}.pdf',
        );
      } catch (e) {
        lastError = 'Failed to share PDF: $e';
        debugPrint('❌ downloadTranscription error: $e');
      }
    }

    isDownloading = false;
    notifyListeners();
  }
}