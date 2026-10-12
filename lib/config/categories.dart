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
    "Temples",
    "Forts",
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
    "Temples",
    "Forts",
    "Heritage",
    "Forests",
    "Desert",
    "Nature",
    "City",
    "Other",
  ];

  /// Circular Story Categories shown at the top of FeedScreen
  static const List<Map<String, String>> storyCategories = [
    {"title": "Waterfall", "image": "assets/images/explore_2.png"},
    {"title": "Mountains", "image": "assets/images/onboarding_1.jpg"},
    {"title": "Rivers", "image": "assets/images/onboarding_3.jpg"},
    {"title": "Trekking Spots", "image": "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=400"},
    {"title": "Camping Spots", "image": "https://images.unsplash.com/photo-1510312305653-8ed496efae75?w=400"},
    {"title": "Lakes", "image": "https://res.cloudinary.com/lxfbzehh/image/upload/v1791547096/hidely/posts/bqenz5vj8wlydhl3skxz.jpg"},
    {"title": "Beaches", "image": "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=400"},
    {"title": "Temples", "image": "assets/images/explore_5.png"},
    {"title": "Forts", "image": "assets/images/explore_7.png"},
    {"title": "Heritage", "image": "assets/images/explore_8.png"},
    {"title": "Forests", "image": "https://images.unsplash.com/photo-1511497584788-87676104235f?w=400"},
    {"title": "Desert", "image": "https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?w=400"},
  ];

  static String getEmoji(String category) {
    switch (category.toLowerCase().trim()) {
      case 'mountains':
      case 'mountain':
        return '🏔️';
      case 'waterfalls':
      case 'waterfall':
        return '🌊';
      case 'rivers':
      case 'river':
        return '🏞️';
      case 'trekking spots':
      case 'trekking':
      case 'trek':
        return '🥾';
      case 'camping spots':
      case 'camping':
      case 'camp':
        return '⛺';
      case 'lakes':
      case 'lake':
        return '🛶';
      case 'beaches':
      case 'beach':
        return '🏖️';
      case 'temples':
      case 'temple':
        return '🛕';
      case 'forts':
      case 'fort':
        return '🏰';
      case 'heritage':
        return '🏛️';
      case 'forests':
      case 'forest':
        return '🌲';
      case 'desert':
      case 'deserts':
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

    if (sel == 'mountains' || sel == 'mountain') {
      if (cat.contains('waterfall') || cat.contains('river') || cat.contains('beach') || cat.contains('temple')) return false;
      return cat.contains('mountain') ||
          caption.contains('mountain') ||
          caption.contains('peak') ||
          caption.contains('himalay') ||
          caption.contains('pass') ||
          location.contains('pass') ||
          location.contains('peak');
    }

    if (sel == 'waterfalls' || sel == 'waterfall') {
      return cat.contains('waterfall') ||
          caption.contains('waterfall') ||
          caption.contains('falls') ||
          caption.contains('cascade') ||
          location.contains('waterfall') ||
          location.contains('falls');
    }

    if (sel == 'rivers' || sel == 'river') {
      if (caption.contains('gateway of india') || location.contains('mumbai')) return false;
      return cat.contains('river') ||
          caption.contains('river') ||
          caption.contains('ghat') ||
          caption.contains('ganga') ||
          caption.contains('rafting') ||
          location.contains('river') ||
          location.contains('ghat');
    }

    if (sel == 'trekking spots' || sel == 'trekking' || sel == 'trek') {
      return cat.contains('trek') ||
          caption.contains('trek') ||
          caption.contains('hike') ||
          caption.contains('trail') ||
          location.contains('trek');
    }

    if (sel == 'camping spots' || sel == 'camping' || sel == 'camp') {
      return cat.contains('camp') ||
          caption.contains('camp') ||
          caption.contains('tent') ||
          caption.contains('stargazing') ||
          location.contains('camp');
    }

    if (sel == 'lakes' || sel == 'lake') {
      return cat.contains('lake') ||
          caption.contains('lake') ||
          location.contains('lake') ||
          caption.contains('tso') ||
          location.contains('tso');
    }

    if (sel == 'beaches' || sel == 'beach') {
      return cat.contains('beach') ||
          caption.contains('beach') ||
          caption.contains('coast') ||
          location.contains('beach') ||
          location.contains('coast');
    }

    if (sel == 'temples' || sel == 'temple') {
      return cat.contains('temple') ||
          caption.contains('temple') ||
          location.contains('temple') ||
          caption.contains('mandir') ||
          location.contains('mandir') ||
          caption.contains('aarti');
    }

    if (sel == 'forts' || sel == 'fort') {
      return cat.contains('fort') ||
          caption.contains('fort') ||
          location.contains('fort') ||
          caption.contains('qila') ||
          location.contains('qila') ||
          caption.contains('red fort') ||
          location.contains('red fort');
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

    if (sel == 'desert' || sel == 'deserts') {
      return cat.contains('desert') ||
          caption.contains('desert') ||
          caption.contains('dunes') ||
          location.contains('desert') ||
          location.contains('jaisalmer');
    }

    return cat == sel || cat.contains(sel);
  }
}
