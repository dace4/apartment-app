/// US 14: the topics the property FAQ is grouped by.
enum FaqCategory {
  searching('Searching'),
  visits('Visits'),
  applying('Applying'),
  costs('Rent & costs'),
  owners('Owners & managers'),
  account('Account');

  const FaqCategory(this.label);
  final String label;
}

/// US 14: one question of the property FAQ, with an optional link to the
/// page of the app where the user can act on the answer.
class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    this.linkLabel,
    this.linkLocation,
  });

  final String id;
  final FaqCategory category;
  final String question;
  final String answer;
  final String? linkLabel;
  final String? linkLocation;

  /// Whether the question or the answer contains [query], ignoring case.
  /// An empty query matches every entry.
  bool matches(String query) {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) return true;
    return question.toLowerCase().contains(text) ||
        answer.toLowerCase().contains(text);
  }
}
