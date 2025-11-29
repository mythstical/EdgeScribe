import 'package:flutter/material.dart';
import 'package:edgescribe/services/medical_redaction_service.dart';

/// Production Medical Redactor UI with:
/// - Loading Dictionaries state on launch
/// - Green RichText highlighting for redacted tags
/// - Debug toggle for LLM Layer 3
/// - Per-layer timing metrics
class RedactorPage extends StatefulWidget {
  const RedactorPage({super.key});

  @override
  State<RedactorPage> createState() => _RedactorPageState();
}

class _RedactorPageState extends State<RedactorPage> {
  final MedicalRedactionService _service = MedicalRedactionService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // State
  bool _loadingDictionaries = true;
  bool _initializingLLM = false;
  bool _processing = false;
  bool _llmEnabled = true;
  String _llmStatus = '';
  double? _llmProgress;
  RedactionResult? _result;

  static const String _exampleText =
      '''Patient John Smith (SSN: 123-45-6789) visited Dr. Emily Watson at Mayo Clinic on January 15th, 2024.

Contact: john.smith@email.com, Phone: (555) 123-4567

Chief Complaint: Patient reports persistent hypertension and diabetes symptoms.

Dr. Watson prescribed metformin 500mg twice daily. Follow-up scheduled with Nurse Rodriguez at Cleveland Medical Center in Boston.

Emergency contact: Alice Johnson at Mercy General Hospital.''';

  @override
  void initState() {
    super.initState();
    _inputController.text = _exampleText;
    _loadDictionaries();
  }

  Future<void> _loadDictionaries() async {
    try {
      await _service.loadDictionaries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dictionaries: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingDictionaries = false);
      }
    }
  }

  Future<void> _initializeLLM() async {
    if (!mounted) return;
    setState(() {
      _initializingLLM = true;
      _llmStatus = 'Starting...';
      _llmProgress = null;
    });

    try {
      await _service.initializeLLM(
        onProgress: (progress, status, isError) {
          if (!mounted) return;
          setState(() {
            _llmProgress = progress;
            _llmStatus = status;
          });
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('LLM ready - Layer 3 enabled'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('LLM init failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _initializingLLM = false;
          _llmStatus = '';
          _llmProgress = null;
        });
      }
    }
  }

  Future<void> _runRedaction() async {
    if (_inputController.text.trim().isEmpty) return;

    if (!mounted) return;
    setState(() {
      _processing = true;
      _result = null;
    });

    try {
      final result = await _service.redact(
        _inputController.text,
        enableLLM: _llmEnabled,
      );

      if (mounted) {
        setState(() => _result = result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Loading dictionaries state
    if (_loadingDictionaries) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF00D9FF)),
              const SizedBox(height: 24),
              Text(
                'Loading Dictionaries...',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Preparing medical terms and city lists',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        title: const Text(
          'Medical Redactor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          // LLM Toggle
          Row(
            children: [
              Text(
                'LLM',
                style: TextStyle(
                  color: _llmEnabled ? const Color(0xFF00D9FF) : Colors.white54,
                  fontSize: 12,
                ),
              ),
              Switch(
                value: _llmEnabled,
                onChanged: (v) => setState(() => _llmEnabled = v),
                activeColor: const Color(0xFF00D9FF),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            _buildStatusCard(),
            const SizedBox(height: 16),

            // LLM Init Button (if not ready and enabled)
            if (!_service.llmReady && _llmEnabled) ...[
              _buildLLMInitSection(),
              const SizedBox(height: 16),
            ],

            // Input Section
            _buildInputSection(),
            const SizedBox(height: 16),

            // Action Button
            _buildActionButton(),
            const SizedBox(height: 24),

            // Results
            if (_result != null) ...[
              _buildMetricsCard(),
              const SizedBox(height: 16),
              _buildOutputCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final llmReady = _service.llmReady;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: llmReady ? const Color(0xFF00D9FF) : const Color(0xFFFFB800),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color:
                  (llmReady ? const Color(0xFF00D9FF) : const Color(0xFFFFB800))
                      .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              llmReady ? Icons.shield : Icons.shield_outlined,
              color: llmReady
                  ? const Color(0xFF00D9FF)
                  : const Color(0xFFFFB800),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  llmReady
                      ? 'Full Protection (3 Layers)'
                      : 'Basic Protection (2 Layers)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  llmReady
                      ? 'Regex + Dictionary + LLM'
                      : 'Regex + Dictionary only. Enable LLM for names/orgs.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLLMInitSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: _initializingLLM ? null : _initializeLLM,
            icon: _initializingLLM
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(
              _initializingLLM ? 'Initializing...' : 'Initialize LLM (Layer 3)',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          if (_initializingLLM && _llmStatus.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _llmStatus,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            if (_llmProgress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _llmProgress,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF00D9FF)),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Input Text',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _inputController,
          maxLines: 8,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText: 'Enter medical text to redact...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: const Color(0xFF16213E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return ElevatedButton(
      onPressed: _processing ? null : _runRedaction,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00FF88),
        foregroundColor: const Color(0xFF1A1A2E),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _processing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF1A1A2E),
              ),
            )
          : const Text(
              'REDACT PII',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
    );
  }

  Widget _buildMetricsCard() {
    final result = _result!;
    final metrics = result.metrics;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Metrics',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricChip(
                'L1 Regex',
                '${metrics.layer1RegexMs}ms',
                result.layer1Count,
                const Color(0xFFFF6B6B),
              ),
              const SizedBox(width: 8),
              _buildMetricChip(
                'L2 Dict',
                '${metrics.layer2DictMs}ms',
                result.layer2Count,
                const Color(0xFFFFB800),
              ),
              const SizedBox(width: 8),
              _buildMetricChip(
                'L3 LLM',
                result.llmEnabled ? '${metrics.layer3LlmMs}ms' : 'OFF',
                result.layer3Count,
                const Color(0xFF00D9FF),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ${metrics.totalMs}ms',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              if (result.hallucinationsBlocked > 0)
                Text(
                  'Hallucinations blocked: ${result.hallucinationsBlocked}',
                  style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String time, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
              ),
            ),
            Text(
              '$count found',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutputCard() {
    final result = _result!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Redacted Output',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                '${result.entities.length} entities',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildHighlightedText(result.redactedText),
          ),
          const SizedBox(height: 12),
          _buildLegend(),
        ],
      ),
    );
  }

  /// Build RichText with green-highlighted tags
  Widget _buildHighlightedText(String text) {
    final spans = <TextSpan>[];
    final tagPattern = RegExp(r'\[([A-Z]+)\]');
    var lastEnd = 0;

    for (final match in tagPattern.allMatches(text)) {
      // Add plain text before tag
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
        );
      }

      // Add highlighted tag
      final tag = match.group(0)!;
      final label = match.group(1)!;
      spans.add(
        TextSpan(
          text: tag,
          style: TextStyle(
            color: _getTagColor(label),
            backgroundColor: _getTagColor(label).withValues(alpha: 0.2),
            fontWeight: FontWeight.w600,
          ),
        ),
      );

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
        ),
      );
    }

    return SelectableText.rich(
      TextSpan(
        children: spans,
        style: const TextStyle(
          fontSize: 14,
          height: 1.6,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Color _getTagColor(String label) {
    switch (label) {
      case 'EMAIL':
        return const Color(0xFFFF6B6B);
      case 'PHONE':
        return const Color(0xFFFFB800);
      case 'DATE':
        return const Color(0xFF9B59B6);
      case 'ID':
        return const Color(0xFFE74C3C);
      case 'LOC':
        return const Color(0xFF00FF88); // Green for locations
      case 'PERSON':
        return const Color(0xFF00D9FF);
      case 'ORG':
        return const Color(0xFF3498DB);
      default:
        return const Color(0xFF00FF88); // Default green
    }
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildLegendItem('[EMAIL]', const Color(0xFFFF6B6B)),
        _buildLegendItem('[PHONE]', const Color(0xFFFFB800)),
        _buildLegendItem('[DATE]', const Color(0xFF9B59B6)),
        _buildLegendItem('[ID]', const Color(0xFFE74C3C)),
        _buildLegendItem('[LOC]', const Color(0xFF00FF88)),
        _buildLegendItem('[PERSON]', const Color(0xFF00D9FF)),
        _buildLegendItem('[ORG]', const Color(0xFF3498DB)),
      ],
    );
  }

  Widget _buildLegendItem(String tag, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        tag,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
