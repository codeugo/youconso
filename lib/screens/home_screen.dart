import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../api/youprice_api.dart';
import '../conso_widget.dart';
import '../models/conso.dart';
import '../models/invoice.dart';
import '../models/line_info.dart';
import '../theme.dart';
import '../widgets/conso_card.dart';
import '../widgets/invoice_tile.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api});

  final YoupriceApi api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _LineData {
  const _LineData(this.conso, this.info);

  final Conso conso;
  final LineInfo? info;
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _loading = true;
  ApiException? _initError;
  String? _customerName;
  List<String> _numbers = const [];
  String? _selectedNumber;
  Future<_LineData>? _lineFuture;
  Future<List<Invoice>>? _invoicesFuture;
  String? _openingInvoiceId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _initError = null;
    });
    try {
      final numbers = await widget.api.activeNumbers();
      String? name;
      try {
        name = await widget.api.customerName();
      } on ApiException catch (e) {
        if (e.sessionLost) rethrow;
      }
      if (!mounted) return;
      setState(() {
        _numbers = numbers;
        _customerName = name;
        _selectedNumber = numbers.isNotEmpty ? numbers.first : null;
        _loading = false;
      });
      _reloadLine();
      _reloadInvoices();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.sessionLost) {
        _goToLogin(e.message);
        return;
      }
      setState(() {
        _initError = e;
        _loading = false;
      });
    }
  }

  void _reloadLine() {
    final number = _selectedNumber;
    setState(() {
      _lineFuture = number == null ? null : _loadLine(number);
    });
  }

  Future<_LineData> _loadLine(String number) async {
    final conso = await widget.api.conso(number);
    LineInfo? info;
    try {
      info = await widget.api.lineInfo(number);
    } on ApiException catch (e) {
      if (e.sessionLost) rethrow;
    }
    unawaited(updateConsoWidget(conso, info));
    return _LineData(conso, info);
  }

  void _reloadInvoices() {
    setState(() {
      _invoicesFuture = widget.api.invoices();
    });
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openInvoice(Invoice invoice) async {
    final id = invoice.id;
    if (id == null) {
      _snack('Cette facture n\'a pas d\'identifiant.');
      return;
    }
    setState(() => _openingInvoiceId = id);
    try {
      final bytes = await widget.api.invoicePdf(id);
      final dir = await getTemporaryDirectory();
      final date = invoice.date;
      final suffix = date != null ? DateFormat('yyyy-MM').format(date) : id;
      final file = File('${dir.path}/facture-youprice-$suffix.pdf');
      await file.writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(file.path, type: 'application/pdf');
      if (result.type != ResultType.done) {
        _snack('Aucune application ne peut ouvrir ce PDF (${result.message}).');
      }
    } on ApiException catch (e) {
      if (e.sessionLost) {
        _goToLogin(e.message);
        return;
      }
      _snack(e.message);
    } catch (e) {
      _snack('Impossible d\'ouvrir la facture : $e');
    } finally {
      if (mounted) setState(() => _openingInvoiceId = null);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Vos identifiants seront effacés de cet appareil.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.api.logout();
    if (!mounted) return;
    _goToLogin(null);
  }

  void _goToLogin(String? message) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(api: widget.api, message: message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_customerName ?? 'YouConso'),
        actions: [
          IconButton(
            tooltip: 'Thème',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showThemeDialog(context),
          ),
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.speed_outlined),
            selectedIcon: Icon(Icons.speed),
            label: 'Conso',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Factures',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_initError != null) {
      return _ErrorView(error: _initError!, onRetry: _init);
    }
    return IndexedStack(index: _tab, children: [_consoTab(), _invoicesTab()]);
  }

  Widget _consoTab() {
    if (_numbers.isEmpty) {
      return const _EmptyView(
        icon: Icons.sim_card_alert_outlined,
        text:
            'Aucune ligne active sur ce compte.\n'
            'Si votre commande est en cours, la conso sera disponible '
            'une fois la ligne activée.',
      );
    }
    return Column(
      children: [
        if (_numbers.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedNumber,
              decoration: const InputDecoration(
                labelText: 'Ligne',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final n in _numbers)
                  DropdownMenuItem(value: n, child: Text(_formatPhone(n))),
              ],
              onChanged: (value) {
                if (value == null || value == _selectedNumber) return;
                _selectedNumber = value;
                _reloadLine();
              },
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _reloadLine();
              await _lineFuture;
            },
            child: FutureBuilder<_LineData>(
              future: _lineFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final error = snapshot.error!;
                  if (error is ApiException && error.sessionLost) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _goToLogin(error.message),
                    );
                  }
                  return _ErrorView(error: error, onRetry: _reloadLine);
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;
                final groups = data.conso.groups;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _LineHeader(number: _selectedNumber!, info: data.info),
                    const SizedBox(height: 16),
                    if (groups.isEmpty)
                      const _EmptyView(
                        icon: Icons.hourglass_empty,
                        text: 'Aucune donnée de consommation pour le moment.',
                      )
                    else
                      for (final group in groups) ConsoCard(group: group),
                    const SizedBox(height: 8),
                    Text(
                      'Le forfait se réinitialise le 1er de chaque mois. '
                      'Tirez vers le bas pour actualiser.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _invoicesTab() {
    return RefreshIndicator(
      onRefresh: () async {
        _reloadInvoices();
        await _invoicesFuture;
      },
      child: FutureBuilder<List<Invoice>>(
        future: _invoicesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error!;
            if (error is ApiException && error.sessionLost) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _goToLogin(error.message),
              );
            }
            return _ErrorView(error: error, onRetry: _reloadInvoices);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final invoices = snapshot.data!;
          if (invoices.isEmpty) {
            return const _EmptyView(
              icon: Icons.receipt_long_outlined,
              text: 'Aucune facture pour le moment.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: invoices.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final invoice = invoices[i];
              return InvoiceTile(
                invoice: invoice,
                busy:
                    _openingInvoiceId != null &&
                    _openingInvoiceId == invoice.id,
                onTap: () => _openInvoice(invoice),
              );
            },
          );
        },
      ),
    );
  }
}

String _formatPhone(String number) {
  final digits = number.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 10) return number;
  return [for (var i = 0; i < 10; i += 2) digits.substring(i, i + 2)].join(' ');
}

Color? _operatorColor(String? operator) {
  final op = operator?.toLowerCase() ?? '';
  if (op.contains('sfr')) return const Color(0xFFD0021B);
  if (op.contains('orange')) return const Color(0xFFFF7900);
  if (op.contains('bouygues') || op == 'bt') return const Color(0xFF1FA2E0);
  return null;
}

class _LineHeader extends StatelessWidget {
  const _LineHeader({required this.number, this.info});

  final String number;
  final LineInfo? info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = this.info;
    final active = info?.isActive ?? true;
    const onBanner = Colors.white;
    final chips = <(String, Color?)>[
      if (info?.operator != null)
        ('Réseau ${info!.operator}', _operatorColor(info.operator)),
      if (info?.simType != null)
        (info!.simType!.toUpperCase() == 'ESIM' ? 'eSIM' : 'SIM', null),
      if (info?.has5G ?? false) ('5G', null),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [youpriceBlue, youpriceBlue.withValues(alpha: 0.78)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  info?.planLabel != null
                      ? 'Forfait ${info!.planLabel}'
                      : 'Ma ligne',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: onBanner,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (info?.status != null)
                Tooltip(
                  message: info!.status!,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? const Color(0xFF4CD964)
                          : const Color(0xFFFF3B30),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatPhone(number),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: onBanner,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final (label, color) in chips)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      border: color == null
                          ? Border.all(color: onBanner.withValues(alpha: 0.5))
                          : null,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: onBanner,
                        fontWeight: color != null ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        Icon(
          Icons.cloud_off,
          size: 56,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          error is ApiException ? error.message : '$error',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center),
      ],
    );
  }
}
