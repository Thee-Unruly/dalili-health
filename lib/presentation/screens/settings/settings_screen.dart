import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:denizen_ai/denizen_ai.dart';
import 'dart:io';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/offline_model_provider.dart';
import 'model_registry_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _availableRamMB = -1;

  @override
  void initState() {
    super.initState();
    _loadRamInfo();
  }

  Future<void> _loadRamInfo() async {
    try {
      if (Platform.isAndroid) {
        final memInfo = await File('/proc/meminfo').readAsString();
        final match = RegExp(r'MemAvailable:\s+(\d+)').firstMatch(memInfo);
        if (match != null && mounted) {
          setState(() => _availableRamMB = int.parse(match.group(1)!) ~/ 1024);
        }
      }
    } catch (_) {}
  }

  void _openModelRegistry(BuildContext context) async {
    final provider = Provider.of<OfflineModelProvider>(context, listen: false);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ModelRegistryScreen()),
    );
    // Refresh state upon return
    if (!mounted) return;
    _loadRamInfo();
    await provider.initialize();
  }

  Widget _buildRamBar(int availableMB) {
    final hasRamReading = availableMB > 0;
    final color = !hasRamReading
        ? AppColors.accent
        : availableMB >= 700
            ? AppColors.green
            : availableMB >= 400
                ? const Color(0xFFE6A817)
                : AppColors.pdfFg;
    final text = hasRamReading
        ? 'Free device memory: $availableMB MB (${availableMB >= 700 ? "Good" : availableMB >= 400 ? "Low" : "Critical"})'
        : 'Engine Memory: Auto-Managed by On-Device AI Runtime';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(TablerIcons.cpu, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.inter(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: _loadRamInfo,
            child: Icon(TablerIcons.refresh, size: 13, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final modelProvider = Provider.of<OfflineModelProvider>(context);
    final denizen = DenizenAI();
    final isRealModelActive = denizen.isModelLoaded;
    final activeModelName = modelProvider.activeModel?.name ?? denizen.engine.loadedModel?.name ?? 'No Model Loaded';
    final downloadedModels = modelProvider.models.where((m) => m.isDownloaded).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildSectionTitle('OFFLINE AI ENGINE'),
          const SizedBox(height: 10),
          _buildRamBar(_availableRamMB),
          const SizedBox(height: 10),

          // Engine Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isRealModelActive ? AppColors.greenBg : AppColors.surface,
              border: Border.all(
                color: isRealModelActive ? AppColors.greenBorder : AppColors.border,
                width: isRealModelActive ? 1.5 : 0.5,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isRealModelActive ? TablerIcons.brain : TablerIcons.cloud_download,
                      color: isRealModelActive ? AppColors.green : AppColors.accent,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isRealModelActive ? 'LIVE NEURAL ENGINE ACTIVE' : 'NO MODEL IN MEMORY',
                                style: AppTypography.spaceGrotesk(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isRealModelActive ? AppColors.green : AppColors.textPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isRealModelActive
                                ? 'Loaded Model: $activeModelName\n100% on-device AI inference is active for your Tutor & Library.'
                                : 'Select and load a compact GGUF model in the registry to activate offline AI.',
                            style: AppTypography.inter(
                              fontSize: 12,
                              color: isRealModelActive ? AppColors.textPrimary : AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openModelRegistry(context),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: isRealModelActive ? AppColors.green : AppColors.accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(TablerIcons.database, size: 16, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                isRealModelActive ? 'MANAGE MODELS' : 'OPEN MODEL REGISTRY',
                                style: AppTypography.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (isRealModelActive) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => modelProvider.clearActiveModel(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.pdfFg, width: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Unload',
                            style: AppTypography.inter(fontSize: 12, color: AppColors.pdfFg, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Downloaded models ready to load directly from settings
          if (downloadedModels.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildSectionTitle('DOWNLOADED MODELS READY TO LOAD'),
            const SizedBox(height: 10),
            ...downloadedModels.map((model) => _buildDownloadedModelCard(context, modelProvider, model)),
          ],

          const SizedBox(height: 24),
          _buildSectionTitle('PREFERENCES'),
          const SizedBox(height: 10),
          _buildPreferenceSwitches(context, settings),
          const SizedBox(height: 24),
          _buildSectionTitle('LOCAL SYSTEM INFO'),
          const SizedBox(height: 10),
          _buildSystemInfoCard(context, modelProvider, activeModelName),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDownloadedModelCard(BuildContext context, OfflineModelProvider modelProvider, OfflineModel model) {
    final isLoaded = (modelProvider.activeModel?.id == model.id) || (modelProvider.loadedModelId == model.id);
    final isLoadingThis = modelProvider.isContextLoading && modelProvider.downloadingModelId == model.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLoaded ? AppColors.green.withValues(alpha: 0.6) : AppColors.border,
          width: isLoaded ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLoaded ? TablerIcons.circle_check : TablerIcons.device_floppy,
            color: isLoaded ? AppColors.green : AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.name,
                  style: AppTypography.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${model.sizeMB.toStringAsFixed(0)} MB · Ready on disk · needs ~${(model.sizeMB * 2.5).ceil()} MB RAM',
                  style: AppTypography.inter(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (isLoaded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.greenBg,
                border: Border.all(color: AppColors.greenBorder, width: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'In Memory',
                style: AppTypography.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.green),
              ),
            )
          else
            GestureDetector(
              onTap: modelProvider.isContextLoading ? null : () => modelProvider.setActiveModel(model),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (isLoadingThis) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                      const SizedBox(width: 6),
                    ] else ...[
                      const Icon(TablerIcons.player_play, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      isLoadingThis ? 'Loading...' : 'Load Model',
                      style: AppTypography.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: AppTypography.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildPreferenceSwitches(BuildContext context, SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(
              'Socratic Coaching Mode',
              style: AppTypography.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            ),
            subtitle: Text(
              'Guides learning by asking step-by-step questions instead of solving directly.',
              style: AppTypography.inter(fontSize: 11, color: AppColors.textMuted),
            ),
            value: settings.socraticMode,
            activeThumbColor: AppColors.accent,
            activeTrackColor: AppColors.accent.withValues(alpha: 0.5),
            onChanged: (val) => settings.toggleSocraticMode(val),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: AppColors.border, height: 0.5),
          ),
          SwitchListTile(
            title: Text(
              'System Power Mode',
              style: AppTypography.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            ),
            subtitle: Text(
              'Optimizes CPU cores for local model inference speeds.',
              style: AppTypography.inter(fontSize: 11, color: AppColors.textMuted),
            ),
            value: settings.powerMode,
            activeThumbColor: AppColors.accent,
            activeTrackColor: AppColors.accent.withValues(alpha: 0.5),
            onChanged: (val) => settings.togglePowerMode(val),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemInfoCard(BuildContext context, OfflineModelProvider modelProvider, String activeModelName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          FutureBuilder<int>(
            future: modelProvider.getUsedStorageBytes(),
            builder: (context, snapshot) {
              final usedMB = ((snapshot.data ?? 0) / (1024 * 1024)).toStringAsFixed(1);
              return _buildInfoRow('Local Storage Used', '$usedMB MB');
            },
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            'Active Model',
            activeModelName,
          ),
          const SizedBox(height: 10),
          _buildInfoRow('Engine Status', DenizenAI().isModelLoaded ? 'Loaded in Native RAM' : 'Idle'),
          const SizedBox(height: 10),
          _buildInfoRow('App Version', '1.0.0 (Ubuntu-Edge Custom)'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.inter(fontSize: 12, color: AppColors.textMuted),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTypography.inter(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
