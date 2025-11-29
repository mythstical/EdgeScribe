import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../services/opportunities_service.dart';

class OpportunitiesPage extends StatefulWidget {
  final Conversation conversation;

  const OpportunitiesPage({super.key, required this.conversation});

  @override
  State<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends State<OpportunitiesPage> {
  final OpportunitiesService _service = OpportunitiesService();
  List<Opportunity> _opportunities = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    // Auto-search if we have a transcript
    if (widget.conversation.transcription.isNotEmpty) {
      _findOpportunities();
    }
  }

  Future<void> _findOpportunities() async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      // Use transcript or context if transcript is empty
      final query = widget.conversation.transcription.isNotEmpty
          ? widget.conversation.transcription
          : widget.conversation.context;

      final results = await _service.findOpportunities(query);

      if (mounted) {
        setState(() {
          _opportunities = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to find opportunities: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.conversation.transcription.isEmpty &&
        widget.conversation.context.isEmpty) {
      return Center(
        child: Text(
          'No content to analyze.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Column(
        children: [
          // Header / Status
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF16213E),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: const Color(0xFFFFB800),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isLoading
                        ? 'Analyzing conversation...'
                        : '${_opportunities.length} opportunities found',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!_isLoading)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white54),
                    onPressed: _findOpportunities,
                    tooltip: 'Refresh',
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFB800)),
                  )
                : _opportunities.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _opportunities.length,
                    itemBuilder: (context, index) {
                      return _buildOpportunityCard(_opportunities[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No matching opportunities found',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunityCard(Opportunity opportunity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFB800).withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Placeholder for detail view
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB800).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        opportunity.category.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFFFB800),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${(opportunity.score * 100).toInt()}% Match',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  opportunity.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  opportunity.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
