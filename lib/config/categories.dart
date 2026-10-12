class AppCategories {
  static const List<String> exploreCategories = [
    "All",
    "Mountains",
    "Waterfalls",
    "Rivers",
    "Trekking Spots",
    "Camping Spots",
    "Lakes",
    "Beaches",
    "Heritage",
    "Forests",
    "Desert",
  ];

  static const List<String> creationCategories = [
    "Mountains",
    "Waterfalls",
    "Rivers",
    "Trekking Spots",
    "Camping Spots",
    "Lakes",
    "Beaches",
    "Heritage",
    "Forests",
    "Desert",
    "Nature",
    "City",
    "Other",
  ];

  static String getEmoji(String category) {
    switch (category.toLowerCase().trim()) {
      case 'mountains':
        return '🏔️';
      case 'waterfalls':
        return '🌊';
      case 'rivers':
        return '🏞️';
      case 'trekking spots':
      case 'trekking':
        return '🥾';
      case 'camping spots':
      case 'camping':
        return '⛺';
      case 'lakes':
        return '🛶';
      case 'beaches':
        return '🏖️';
      case 'heritage':
        return '🏰';
      case 'forests':
      case 'forest':
        return '🌲';
      case 'desert':
        return '🏜️';
      case 'nature':
        return '🌿';
      case 'all':
        return '✨';
      default:
        return '📍';
    }
  }

  /// Accurate, content-aware category matching for filtered views
  static bool matches(dynamic post, String selectedCategory) {
    if (selectedCategory == "All") return true;

    final cat = (post is Map ? post['category'] : null)?.toString().toLowerCase().trim() ?? '';
    final caption = (post is Map ? post['caption'] : null)?.toString().toLowerCase().trim() ?? '';
    final location = (post is Map ? post['location'] : null)?.toString().toLowerCase().trim() ?? '';
    final sel = selectedCategory.toLowerCase().trim();

    if (sel == 'mountains') {
      if (cat.contains('waterfall') || cat.contains('river') || cat.contains('beach')) return false;
      return cat.contains('mountain') ||
          caption.contains('mountain') ||
          caption.contains('peak') ||
          caption.contains('himalay') ||
          caption.contains('pass') ||
          location.contains('pass') ||
          location.contains('peak');
    }

    if (sel == 'waterfalls') {
      return cat.contains('waterfall') ||
          caption.contains('waterfall') ||
          caption.contains('falls') ||
          caption.contains('cascade') ||
          location.contains('waterfall') ||
          location.contains('falls');
    }

    if (sel == 'rivers') {
      if (caption.contains('gateway of india') || location.contains('mumbai')) return false;
      return cat.contains('river') ||
          caption.contains('river') ||
          caption.contains('ghat') ||
          caption.contains('ganga') ||
          caption.contains('rafting') ||
          location.contains('river') ||
          location.contains('ghat');
    }

    if (sel == 'trekking spots' || sel == 'trekking') {
      return cat.contains('trek') ||
          caption.contains('trek') ||
          caption.contains('hike') ||
          caption.contains('trail') ||
          location.contains('trek');
    }

    if (sel == 'camping spots' || sel == 'camping') {
      return cat.contains('camp') ||
          caption.contains('camp') ||
          caption.contains('tent') ||
          caption.contains('stargazing') ||
          location.contains('camp');
    }

    if (sel == 'lakes') {
      return cat.contains('lake') ||
          caption.contains('lake') ||
          location.contains('lake') ||
          caption.contains('tso') ||
          location.contains('tso');
    }

    if (sel == 'beaches') {
      return cat.contains('beach') ||
          caption.contains('beach') ||
          caption.contains('coast') ||
          location.contains('beach') ||
          location.contains('coast');
    }

    if (sel == 'forests' || sel == 'forest') {
      return cat.contains('forest') ||
          cat.contains('jungle') ||
          caption.contains('forest') ||
          caption.contains('jungle') ||
          caption.contains('rainforest');
    }

    if (sel == 'heritage') {
      return cat.contains('heritage') ||
          cat.contains('historic') ||
          caption.contains('fort') ||
          caption.contains('palace') ||
          caption.contains('mahal') ||
          caption.contains('gateway of india') ||
          location.contains('fort') ||
          location.contains('palace') ||
          location.contains('mahal');
    }

    if (sel == 'desert') {
      return cat.contains('desert') ||
          caption.contains('desert') ||
          caption.contains('dunes') ||
          location.contains('desert') ||
          location.contains('jaisalmer');
    }

    return cat == sel || cat.contains(sel);
  }
}
