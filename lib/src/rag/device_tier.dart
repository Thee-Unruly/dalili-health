/// Coarse hardware capability classification used to tune chunk size,
/// batch size, and ingestion timing across the low-end -> flagship spectrum.
enum DeviceTier { low, mid, high }

class DeviceTierConfig {
  final int chunkWords;
  final int maxChunks;
  final int batchSize;
  final int yieldMs;
  final bool deferIngestion; // true = only embed on first query, not on upload

  const DeviceTierConfig({
    required this.chunkWords,
    required this.maxChunks,
    required this.batchSize,
    required this.yieldMs,
    required this.deferIngestion,
  });

  static const low = DeviceTierConfig(
    chunkWords: 300,
    maxChunks: 40,
    batchSize: 2,
    yieldMs: 15,
    deferIngestion: true,
  );

  static const mid = DeviceTierConfig(
    chunkWords: 150,
    maxChunks: 100,
    batchSize: 5,
    yieldMs: 5,
    deferIngestion: false,
  );

  static const high = DeviceTierConfig(
    chunkWords: 150,
    maxChunks: 200,
    batchSize: 10,
    yieldMs: 0,
    deferIngestion: false,
  );

  static DeviceTierConfig forTier(DeviceTier tier) {
    switch (tier) {
      case DeviceTier.low:
        return low;
      case DeviceTier.mid:
        return mid;
      case DeviceTier.high:
        return high;
    }
  }
}
