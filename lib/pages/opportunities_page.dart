import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../services/opportunities_service.dart';

class OpportunitiesPage extends StatefulWidget {
  final Conversation conversation;

  const OpportunitiesPage({super.key, required this.conversation});

  @override
  State<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends State<OpportunitiesPage>
    with SingleTickerProviderStateMixin {
  final OpportunitiesService _service = OpportunitiesService();
  List<Opportunity> _opportunities = [];
  bool _isLoading = false;
  // Removed unused _hasSearched
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();

    // Auto-search if we have a transcript
    if (widget.conversation.transcription.isNotEmpty) {
      _findOpportunities();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _findOpportunities() async {
    setState(() {
      _isLoading = true;
    });
    _controller?.reset();

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
        _controller?.forward();
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

  // ... (imports remain the same)

  @override
  Widget build(BuildContext context) {
    // Safety init for hot reload
    _controller ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Header / Status
          _buildHeader(),

          // Content
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _opportunities.isEmpty
                ? _buildEmptyState()
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: Colors.white24, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoading
                      ? 'ANALYZING CONVERSATION...'
                      : 'ANALYSIS COMPLETE',
                  style: GoogleFonts.robotoMono(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isLoading
                      ? 'IDENTIFYING OPPORTUNITIES...'
                      : '${_opportunities.length} OPPORTUNITIES FOUND',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _findOpportunities,
              tooltip: 'REFRESH',
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: Color(0xFFD71921),
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ANALYZING CONTEXT',
            style: GoogleFonts.robotoMono(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'SEARCHING FOR RELEVANT PROGRAMS...',
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 0.5,
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(
              Icons.search_off,
              size: 40,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'NO OPPORTUNITIES FOUND',
            style: GoogleFonts.robotoMono(
              color: Colors.white54,
              fontSize: 14,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _opportunities.length,
      itemBuilder: (context, index) {
        final animation = CurvedAnimation(
          parent: _controller!,
          curve: Interval(
            (index / _opportunities.length) * 0.5,
            1.0,
            curve: Curves.easeOutCubic,
          ),
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(
            opacity: animation,
            child: _buildOpportunityCard(_opportunities[index]),
          ),
        );
      },
    );
  }

  Widget _buildOpportunityCard(Opportunity opportunity) {
    // Determine color based on score
    Color scoreColor;
    if (opportunity.score >= 0.9) {
      scoreColor = Colors.white;
    } else if (opportunity.score >= 0.8) {
      scoreColor = Colors.white70;
    } else {
      scoreColor = Colors.white54;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          opportunity.category.toUpperCase(),
                          style: GoogleFonts.robotoMono(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        opportunity.title.toUpperCase(),
                        style: GoogleFonts.robotoMono(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        opportunity.description,
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                _buildCircularScore(opportunity.score, scoreColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularScore(double score, Color color) {
    return Column(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            children: [
              Center(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    color: Colors.white10,
                    strokeWidth: 2,
                  ),
                ),
              ),
              Center(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    value: score,
                    color: const Color(0xFFD71921),
                    strokeWidth: 2,
                    strokeCap: StrokeCap.square,
                  ),
                ),
              ),
              Center(
                child: Text(
                  '${(score * 100).toInt()}',
                  style: GoogleFonts.robotoMono(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'MATCH',
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}
