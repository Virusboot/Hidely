/// Utility for determining whether a user qualifies for the blue tick verified badge.
/// Rule: Qualified if they have found 50+ hidelys OR have 50k+ (50,000+) followers,
/// or is an official platform account (hidely_official / hidely).
bool isVerifiedCreator({
  required String username,
  int hidelysCount = 0,
  int followersCount = 0,
  bool? isVerifiedFlag,
}) {
  final clean = username.trim().toLowerCase().replaceAll(RegExp(r'^@'), '');
  if (clean == 'hidely_official' || clean == 'hidely') {
    return true;
  }
  if (hidelysCount >= 50 || followersCount >= 50000) {
    return true;
  }
  // When counts are not provided (e.g. from a compact list API), trust the backend calculated flag
  if (isVerifiedFlag == true && hidelysCount == 0 && followersCount == 0) {
    return true;
  }
  return false;
}
