import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../services/health_sync_service.dart';

/// Settings → Health: connect Apple Health / Health Connect, choose what
/// syncs, sync now, grant access added since connecting, disconnect. The
/// connection is this device's only.
class HealthSettingsCard extends StatefulWidget {
  const HealthSettingsCard({super.key});

  @override
  State<HealthSettingsCard> createState() => _HealthSettingsCardState();
}

class _HealthSettingsCardState extends State<HealthSettingsCard> {
  final _health = HealthSyncService.instance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _health.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _snack(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _connect() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    final result = await _health.connect();
    if (!mounted) return;
    setState(() => _busy = false);
    final name = _health.platformName;
    switch (result) {
      case HealthConnectResult.connected:
        break;
      case HealthConnectResult.denied:
        _snack(l10n.nativeHealthDenied(name));
      case HealthConnectResult.notInstalled:
        _snack(
          l10n.nativeHealthNotInstalled,
          action: SnackBarAction(label: l10n.nativeHealthInstall, onPressed: _health.installHealthConnect),
        );
      case HealthConnectResult.unsupported:
      case HealthConnectResult.failed:
        _snack(l10n.nativeHealthFailed(l10n.commonSomethingWentWrong));
    }
  }

  Future<void> _syncNow() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    final added = await _health.importWeights(force: true);
    await _health.refreshToday(force: true);
    if (!mounted) return;
    setState(() => _busy = false);
    if (added != null) _snack(l10n.nativeHealthImported(added));
  }

  Future<void> _disconnect() async {
    final l10n = context.l10n;
    final name = _health.platformName;
    await _health.disconnect();
    if (!mounted) return;
    _snack(Platform.isIOS ? l10n.nativeHealthDisconnectedIos : l10n.nativeHealthDisconnected(name));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final name = _health.platformName;
    return ValueListenableBuilder<HealthSyncSettings>(
      valueListenable: _health.settings,
      builder: (context, s, _) {
        final spinner = SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: l10n.commonLoading),
        );
        if (!_health.isConnected) {
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.favorite_outline, color: cs.primary),
              title: Text(l10n.nativeHealthConnect(name)),
              subtitle: Text('${l10n.nativeHealthConnectSubtitle} ${l10n.nativeHealthOnThisDevice}.'),
              trailing: _busy ? spinner : const Icon(Icons.chevron_right),
              onTap: _busy ? null : _connect,
            ),
          );
        }
        final last = s.lastWeightImport;
        final locale = Localizations.localeOf(context).toString();
        final checked = last == null
            ? l10n.nativeHealthNeverChecked
            : l10n.nativeHealthLastChecked(DateFormat.MMMd(locale).add_Hm().format(last));
        return Card(
          margin: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.favorite, color: cs.primary),
                title: Text(l10n.nativeHealthConnectedTo(name)),
                subtitle: Text(s.importWeight ? checked : l10n.nativeHealthOnThisDevice),
                trailing: _busy
                    ? spinner
                    : TextButton(onPressed: _syncNow, child: Text(l10n.nativeHealthSyncNow)),
              ),
              if (_health.needsNewAccess)
                ListTile(
                  leading: Icon(Icons.monitor_heart_outlined, color: cs.primary),
                  title: Text(l10n.nativeHealthNewAccess),
                  subtitle: Text(l10n.nativeHealthNewAccessSubtitle(name)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : _connect,
                ),
              const Divider(indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: const Icon(Icons.monitor_weight_outlined),
                title: Text(l10n.nativeHealthImportWeight),
                subtitle: Text(l10n.nativeHealthImportWeightSubtitle),
                value: s.importWeight,
                onChanged: (v) => _health.update(importWeight: v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.directions_walk_rounded),
                title: Text(l10n.nativeHealthShowActivity),
                subtitle: Text(l10n.nativeHealthShowActivitySubtitle),
                value: s.showActivity,
                onChanged: (v) => _health.update(showActivity: v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.favorite_border),
                title: Text(l10n.nativeHealthShowWorkoutStats),
                subtitle: Text(l10n.nativeHealthShowWorkoutStatsSubtitle),
                value: s.showWorkoutStats,
                onChanged: (v) => _health.update(showWorkoutStats: v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.fitness_center),
                title: Text(l10n.nativeHealthWriteWorkouts),
                subtitle: Text(l10n.nativeHealthWriteWorkoutsSubtitle),
                value: s.writeWorkouts,
                onChanged: (v) => _health.update(writeWorkouts: v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.water_drop_outlined),
                title: Text(l10n.nativeHealthWriteWater),
                subtitle: Text(l10n.nativeHealthWriteWaterSubtitle),
                value: s.writeWater,
                onChanged: (v) => _health.update(writeWater: v),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.link_off, color: cs.error),
                title: Text(l10n.nativeHealthDisconnect, style: TextStyle(color: cs.error)),
                onTap: _busy ? null : _disconnect,
              ),
            ],
          ),
        );
      },
    );
  }
}
