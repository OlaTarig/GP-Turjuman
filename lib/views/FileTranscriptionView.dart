import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import '../controllers/FileTranscriptionController.dart';
import '../controllers/CaptionController.dart';
import '../models/CaptionsAndTranscriptionModel.dart';

class FileTranscriptionView extends StatefulWidget {
  const FileTranscriptionView({super.key});

  @override
  State<FileTranscriptionView> createState() => _FileTranscriptionViewState();
}

class _FileTranscriptionViewState extends State<FileTranscriptionView> {
  static const Color primaryOrange = Color(0xFFFFB382);
  final FileTranscriptionController _controller =
      FileTranscriptionController.instance;

  final String? _currentUserId =
      FirebaseAuth.instance.currentUser?.uid;

  // ── Check if current user was host or participant in a meeting ─────
  Future<bool> _userWasInMeeting(String meetingId) async {
    if (_currentUserId == null) return false;
    try {
      final meetingDoc = await FirebaseFirestore.instance
          .collection('Meetings')
          .doc(meetingId)
          .get();

      if (!meetingDoc.exists) return false;

      final data = meetingDoc.data()!;
      final hostId = data['hostId'] as String? ?? '';
      final participants =
      List<String>.from(data['participants'] as List? ?? []);

      return hostId == _currentUserId ||
          participants.contains(_currentUserId);
    } catch (e) {
      debugPrint('❌ _userWasInMeeting error: $e');
      return false;
    }
  }

  // ── Display full transcription in a bottom sheet ───────────────────
  void displayDownloadedTranscription(
      BuildContext context, CaptionsAndTranscriptionModel model) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBF5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Meeting Transcript',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                        Text(
                          'ID: ${model.meetingId.length > 8 ? model.meetingId.substring(0, 8) : model.meetingId}...',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Stats bar
              Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: primaryOrange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: primaryOrange.withOpacity(0.3), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statChip(
                      icon: Icons.chat_bubble_outline,
                      label: '${model.captionsBuffer.length} sentences',
                    ),
                    _statChip(
                      icon: Icons.people_outline,
                      label:
                      '${model.captionsBuffer.map((e) => e.userName).where((n) => n.isNotEmpty).toSet().length} speakers',
                    ),
                    _statChip(
                      icon: Icons.access_time,
                      label: model.createdAt.toString().substring(0, 16),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Caption entries
              Expanded(
                child: model.captionsBuffer.isEmpty
                    ? const Center(
                  child: Text(
                    'No transcript available',
                    style: TextStyle(
                        color: Colors.grey, fontSize: 16),
                  ),
                )
                    : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: model.captionsBuffer.length,
                  itemBuilder: (_, i) {
                    final entry = model.captionsBuffer[i];
                    final time =
                        '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
                        '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
                        '${entry.timestamp.second.toString().padLeft(2, '0')}';

                    final speakerName = entry.userName.isNotEmpty
                        ? entry.userName
                        : 'Unknown Speaker';

                    // Highlight current user's entries
                    final isMe = entry.userId == _currentUserId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isMe
                            ? primaryOrange.withOpacity(0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border(
                          left: BorderSide(
                              color: isMe
                                  ? primaryOrange
                                  : Colors.grey.shade300,
                              width: 3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: isMe
                                        ? primaryOrange
                                        .withOpacity(0.2)
                                        : Colors.grey.shade200,
                                    child: Text(
                                      speakerName[0].toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isMe
                                            ? primaryOrange
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isMe
                                        ? '$speakerName (You)'
                                        : speakerName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isMe
                                          ? primaryOrange
                                          : Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                time,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry.text,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF2D3142),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Download PDF button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (_, __) => SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: (_controller.isDownloading ||
                          model.captionsBuffer.isEmpty)
                          ? null
                          : () async {
                        final bytes = await _controller
                            .generateTranscriptionFile(
                          meetingId: model.meetingId,
                          entries: model.captionsBuffer,
                          meetingDate: model.createdAt,
                        );
                        if (bytes != null && mounted) {
                          await Printing.sharePdf(
                            bytes: bytes,
                            filename:
                            'transcript_${model.meetingId.substring(0, 8)}.pdf',
                          );
                        } else if (mounted &&
                            _controller.lastError != null) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content:
                              Text(_controller.lastError!),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                      icon: _controller.isDownloading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                          : const Icon(Icons.download),
                      label: Text(_controller.isDownloading
                          ? 'Generating...'
                          : 'Download PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Main screen ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(child: Text('Not logged in'));
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transcripts',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
                  ),
                ),
                Text(
                  'Your recorded meeting transcripts',
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Stream all captions docs, then filter by user's meetings ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(kCaptionsCollection)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          primaryOrange),
                    ),
                  );
                }

                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final docs = snap.data!.docs;

                // ── Filter: only show meetings user was part of ──
                return FutureBuilder<List<CaptionsAndTranscriptionModel>>(
                  future: _filterUserMeetings(docs),
                  builder: (context, filterSnap) {
                    if (filterSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              primaryOrange),
                        ),
                      );
                    }

                    final userMeetings = filterSnap.data ?? [];

                    if (userMeetings.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: userMeetings.length,
                      itemBuilder: (context, i) =>
                          _buildTranscriptionCard(
                              context, userMeetings[i]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter docs to only include meetings user was in ───────────────
  Future<List<CaptionsAndTranscriptionModel>> _filterUserMeetings(
      List<QueryDocumentSnapshot> docs) async {
    final results = <CaptionsAndTranscriptionModel>[];
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final meetingId = data['meetingId'] as String? ?? doc.id;
      final wasInMeeting = await _userWasInMeeting(meetingId);
      if (wasInMeeting) {
        results.add(CaptionsAndTranscriptionModel.fromMap(data));
      }
    }
    return results;
  }

  // ── Transcription card ─────────────────────────────────────────────
  Widget _buildTranscriptionCard(
      BuildContext context, CaptionsAndTranscriptionModel model) {
    final entryCount = model.captionsBuffer.length;
    final date = model.createdAt.toString().substring(0, 16);
    final speakers = model.captionsBuffer
        .map((e) => e.userName)
        .where((n) => n.isNotEmpty)
        .toSet();

    return GestureDetector(
      onTap: () => displayDownloadedTranscription(context, model),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.subtitles,
                  color: primaryOrange, size: 28),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meeting ${model.meetingId.length > 8 ? model.meetingId.substring(0, 8) : model.meetingId}...',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$date  •  $entryCount sentences  •  ${speakers.length} speakers',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 6),

                  // Speaker name chips
                  if (speakers.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      children: speakers
                          .take(3)
                          .map((name) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryOrange.withOpacity(0.1),
                          borderRadius:
                          BorderRadius.circular(20),
                        ),
                        child: Text(
                          name,
                          style: const TextStyle(
                              fontSize: 11,
                              color: primaryOrange),
                        ),
                      ))
                          .toList(),
                    ),

                  const SizedBox(height: 4),
                  _statusBadge(model.isCompleted),
                ],
              ),
            ),

            // Download button
            ListenableBuilder(
              listenable: _controller,
              builder: (_, __) => IconButton(
                icon: _controller.isDownloading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          primaryOrange)),
                )
                    : const Icon(Icons.download,
                    color: primaryOrange, size: 26),
                tooltip: 'Download PDF',
                onPressed:
                entryCount == 0 || _controller.isDownloading
                    ? null
                    : () async {
                  final bytes = await _controller
                      .generateTranscriptionFile(
                    meetingId: model.meetingId,
                    entries: model.captionsBuffer,
                    meetingDate: model.createdAt,
                  );
                  if (bytes != null && mounted) {
                    await Printing.sharePdf(
                      bytes: bytes,
                      filename:
                      'transcript_${model.meetingId.substring(0, 8)}.pdf',
                    );
                  } else if (mounted &&
                      _controller.lastError != null) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      SnackBar(
                        content:
                        Text(_controller.lastError!),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: primaryOrange.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.subtitles_off,
                  size: 48, color: primaryOrange),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Transcripts Yet',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142)),
            ),
            const SizedBox(height: 10),
            Text(
              'Enable the CC button during a meeting\nto record speech. Transcripts appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────
  Widget _statChip({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: primaryOrange),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF2D3142))),
      ],
    );
  }

  Widget _statusBadge(bool isCompleted) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isCompleted ? 'Completed' : 'In Progress',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isCompleted
              ? Colors.green.shade700
              : Colors.orange.shade700,
        ),
      ),
    );
  }
}