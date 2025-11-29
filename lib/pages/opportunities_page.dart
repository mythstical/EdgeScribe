import 'dart:ui';
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

  @override
  Widget build(BuildContext context) {
    // Safety init for hot reload
    _controller ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A), // Slate 900
              Color(0xFF1E293B), // Slate 800
              Color(0xFF0F172A), // Slate 900
            ],
          ),
        ),
        child: Column(
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
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.7),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB800).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFFFB800),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLoading
                          ? 'Analyzing conversation...'
                          : 'Analysis Complete',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _isLoading
                          ? 'Identifying opportunities...'
                          : '${_opportunities.length} opportunities found',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
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
              color: Color(0xFFFFB800),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Analyzing Context',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Searching for relevant programs...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
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
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 48,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No opportunities found',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _opportunities.length,
      itemBuilder: (context, index) {
        // Staggered animation
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
      scoreColor = const Color(0xFF10B981); // Emerald
    } else if (opportunity.score >= 0.8) {
      scoreColor = const Color(0xFFFFB800); // Amber
    } else {
      scoreColor = const Color(0xFFF59E0B); // Orange
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scoreColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: scoreColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              opportunity.category.toUpperCase(),
                              style: TextStyle(
                                color: scoreColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            opportunity.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
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
                    const SizedBox(width: 16),
                    _buildCircularScore(opportunity.score, scoreColor),
                  ],
                ),
              ),
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
          width: 50,
          height: 50,
          child: Stack(
            children: [
              Center(
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    color: Colors.white.withValues(alpha: 0.1),
                    strokeWidth: 4,
                  ),
                ),
              ),
              Center(
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    value: score,
                    color: color,
                    strokeWidth: 4,
                    strokeCap: StrokeCap.round,
                  ),
                ),
              ),
              Center(
                child: Text(
                  '${(score * 100).toInt()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'MATCH',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
