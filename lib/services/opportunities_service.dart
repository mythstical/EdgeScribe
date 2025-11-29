import 'package:cactus/cactus.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'cactus_model_service.dart';

class Opportunity {
  final String id;
  final String title;
  final String description;
  final String category;
  final double score;

  Opportunity({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.score,
  });
}

class OpportunitiesService {
  // Singleton pattern
  static final OpportunitiesService _instance =
      OpportunitiesService._internal();
  factory OpportunitiesService() => _instance;
  OpportunitiesService._internal();

  final CactusRAG _rag = CactusRAG();
  bool _isInitialized = false;

  // Dummy data to seed
  final List<Map<String, String>> _seedData = [
    {
      'id': 'opt_1',
      'title': 'Diabetes Care Rebate Program',
      'description':
          'Eligible patients with Type 2 Diabetes can receive up to \$500 annual rebate for glucose monitoring equipment.',
      'category': 'Rebate',
      'keywords': 'diabetes, glucose, type 2, sugar, insulin, monitoring',
    },
    {
      'id': 'opt_2',
      'title': 'Senior Medication Discount Card',
      'description':
          'Patients over 65 are eligible for 20% off prescription medications at participating pharmacies.',
      'category': 'Discount',
      'keywords':
          'senior, elderly, 65, prescription, medication, pharmacy, drug',
    },
    {
      'id': 'opt_3',
      'title': 'Heart Health Financial Assistance',
      'description':
          'Financial support available for low-income patients requiring hypertension or cardiac medication.',
      'category': 'Finance',
      'keywords':
          'heart, cardiac, hypertension, blood pressure, finance, assistance, low income',
    },
    {
      'id': 'opt_4',
      'title': 'Mental Health Support Grant',
      'description':
          'State-funded grant for 10 free therapy sessions for patients with anxiety or depression diagnoses.',
      'category': 'Program',
      'keywords':
          'mental health, anxiety, depression, therapy, counseling, stress',
    },
    {
      'id': 'opt_5',
      'title': 'Asthma Inhaler Coupon',
      'description':
          'Manufacturer coupon for \$20 co-pay on Albuterol inhalers.',
      'category': 'Discount',
      'keywords': 'asthma, inhaler, breathing, lungs, albuterol, copay',
    },
    {
      'id': 'opt_6',
      'title': 'Hypertension Meds Assistance',
      'description':
          'Financial aid for patients prescribed blood pressure medications like Lisinopril or Amlodipine.',
      'category': 'Finance',
      'keywords':
          'hypertension, blood pressure, heart, lisinopril, amlodipine, finance',
    },
    {
      'id': 'opt_7',
      'title': 'Medical Transport Voucher',
      'description':
          'Free ride vouchers for seniors or disabled patients traveling to medical appointments.',
      'category': 'Program',
      'keywords':
          'transport, ride, uber, lyft, appointment, clinic, hospital, travel',
    },
    {
      'id': 'opt_8',
      'title': 'Fresh Food Prescription',
      'description':
          '\$50 monthly produce credit for patients managing diabetes or heart disease.',
      'category': 'Program',
      'keywords': 'food, diet, nutrition, vegetables, diabetes, heart, healthy',
    },
    {
      'id': 'opt_9',
      'title': 'Metformin Co-pay Card',
      'description':
          'Zero dollar co-pay card for extended-release Metformin prescriptions.',
      'category': 'Discount',
      'keywords':
          'metformin, diabetes, sugar, glucose, prescription, copay, drug',
    },
    {
      'id': 'opt_10',
      'title': 'Remote BP Monitoring',
      'description':
          'Free cellular-connected blood pressure cuff for patients with uncontrolled hypertension.',
      'category': 'Device',
      'keywords':
          'blood pressure, monitoring, cuff, remote, hypertension, heart',
    },
  ];

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('[OpportunitiesService] Initializing RAG...');

      // Initialize the vector database
      // await _rag.initialize(); // API mismatch

      await _rag.initialize();

      // Set embedding generator (Simple hash-based for POC)
      _rag.setEmbeddingGenerator(_generateEmbeddings);

      // Configure chunking
      _rag.setChunking(chunkSize: 512, chunkOverlap: 64);

      debugPrint('[OpportunitiesService] Seeding database...');

      // Clear existing docs if possible or just add (POC)
      // For now, we'll just add. In real app, check if exists.

      for (final item in _seedData) {
        final content =
            "ID: ${item['id']}\nTitle: ${item['title']}\nDescription: ${item['description']}\nCategory: ${item['category']}\nKeywords: ${item['keywords']}";

        await _rag.storeDocument(
          fileName: item['id']!,
          filePath: 'memory', // Virtual path
          content: content,
        );
      }

      _isInitialized = true;
      debugPrint('[OpportunitiesService] RAG initialized and seeded.');
    } catch (e) {
      debugPrint('[OpportunitiesService] Init failed: $e');
    }
  }

  /// Generate embeddings using the shared CactusLM model
  Future<List<double>> _generateEmbeddings(String text) async {
    try {
      // Ensure model is ready
      if (!CactusModelService.instance.isLoaded) {
        await CactusModelService.instance.initialize();
      }

      final result = await CactusModelService.instance.model.generateEmbedding(
        text: text,
      );
      if (!result.success) throw Exception("Embedding failed");
      final embedding = result.embeddings;

      // L2 Normalize the embedding to ensure Euclidean distance works as expected for similarity
      double sumSq = 0.0;
      for (var val in embedding) {
        sumSq += val * val;
      }

      if (sumSq == 0) return embedding;

      final magnitude = math.sqrt(sumSq);

      // If already close to 1, return as is (optimization)
      if ((magnitude - 1.0).abs() < 0.001) return embedding;

      for (int i = 0; i < embedding.length; i++) {
        embedding[i] /= magnitude;
      }

      return embedding;
    } catch (e) {
      debugPrint('[OpportunitiesService] Embedding generation failed: $e');
      // Fallback to zero vector or rethrow?
      // Rethrowing is better so RAG knows it failed.
      // But for robustness let's return a zero vector if it fails hard,
      // though that might mess up search.
      // Let's try to return a simple hash fallback if LLM fails?
      // No, user requested "use this approach".
      rethrow;
    }
  }

  Future<List<Opportunity>> findOpportunities(String text) async {
    if (!_isInitialized) await initialize();
    if (text.trim().isEmpty) return [];

    try {
      // 1. Vector Search (Semantic)
      // Chunk the input text to avoid vector dilution
      final chunks = _chunkText(text, 256);
      debugPrint('[OpportunitiesService] Searching ${chunks.length} chunks...');

      // Map of ID -> Best (Lowest) Distance
      final bestDistances = <String, double>{};

      for (final chunk in chunks) {
        if (chunk.trim().isEmpty) continue;

        final results = await _rag.search(text: chunk, limit: 5);

        for (final r in results) {
          final content = r.chunk.content;
          final idMatch = RegExp(r'ID: (opt_\d+)').firstMatch(content);
          final id = idMatch?.group(1) ?? 'unknown';

          if (!bestDistances.containsKey(id) ||
              r.distance < bestDistances[id]!) {
            bestDistances[id] = r.distance;
          }
        }
      }

      // 2. Keyword Search (Lexical)
      // Count keyword matches for each opportunity in the full text
      final keywordScores = <String, double>{};
      final lowerText = text.toLowerCase();

      for (final item in _seedData) {
        final id = item['id']!;
        final keywords = item['keywords']!.toLowerCase().split(', ');
        int matches = 0;

        for (final k in keywords) {
          if (lowerText.contains(k)) matches++;
        }

        // Score = matches / total_keywords (simple overlap ratio)
        keywordScores[id] = keywords.isEmpty
            ? 0.0
            : (matches / keywords.length);
      }

      // 3. Hybrid Scoring & Ranking
      final hybridScores = <String, double>{};

      debugPrint(
        '[OpportunitiesService] calculating hybrid scores for ${_seedData.length} items...',
      );

      for (final item in _seedData) {
        final id = item['id']!;

        // Vector Score: Convert distance to similarity (0.0 - 1.0)
        // If not in vector results, assume high distance (low similarity)
        double vectorScore = 0.0;
        if (bestDistances.containsKey(id)) {
          // Distance 0 -> Score 1.0
          // Distance 2 -> Score 0.0
          vectorScore = (1.0 - (bestDistances[id]! / 2.0)).clamp(0.0, 1.0);
        }

        final keywordScore = keywordScores[id] ?? 0.0;

        // Weighted Average: 60% Semantic, 40% Keyword
        // Adjust weights as needed
        final finalScore = (vectorScore * 0.6) + (keywordScore * 0.4);

        hybridScores[id] = finalScore;

        debugPrint(
          '[OpportunitiesService] $id: Vector=$vectorScore (Dist: ${bestDistances[id]}), Keyword=$keywordScore, Hybrid=$finalScore',
        );
      }

      // Sort by Hybrid Score (Descending)
      final sortedIds = hybridScores.keys.toList()
        ..sort((a, b) => hybridScores[b]!.compareTo(hybridScores[a]!));

      // Take top 5 and assign display ranks
      final topResults = <Opportunity>[];

      for (var i = 0; i < sortedIds.length && i < 5; i++) {
        final id = sortedIds[i];
        // Only include if there's some relevance
        // Lowered threshold for debugging
        if (hybridScores[id]! < 0.01) continue;

        final match = _seedData.firstWhere((item) => item['id'] == id);

        // Display Rank Score: 95%, 90%, etc.
        double displayScore = 0.95 - (i * 0.05);

        topResults.add(
          Opportunity(
            id: match['id']!,
            title: match['title']!,
            description: match['description']!,
            category: match['category']!,
            score: displayScore,
          ),
        );
      }

      debugPrint(
        '[OpportunitiesService] Found ${topResults.length} opportunities after filtering.',
      );

      return topResults;
    } catch (e) {
      debugPrint('[OpportunitiesService] Search failed: $e');
      return [];
    }
  }

  List<String> _chunkText(String text, int size) {
    final chunks = <String>[];
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));

    var currentChunk = StringBuffer();

    for (final sentence in sentences) {
      if (currentChunk.length + sentence.length > size &&
          currentChunk.isNotEmpty) {
        chunks.add(currentChunk.toString());
        currentChunk = StringBuffer();
      }
      currentChunk.write(sentence);
      currentChunk.write(' ');
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.toString());
    }

    return chunks;
  }

  void dispose() {
    // _rag.dispose(); // If available
  }
}
