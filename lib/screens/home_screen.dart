import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../api/youprice_api.dart';
import '../conso_widget.dart';
import '../models/invoice.dart';
import '../models/line_info.dart';
import '../storage/home_cache.dart';
import '../theme.dart';
import '../widgets/conso_card.dart';
import '../widgets/invoice_tile.dart';
import '../widgets/line_header.dart';
import '../widgets/status_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api});

  final YoupriceApi api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Awaits [future] swallowing its error, already shown on screen.
Future<void> _settle(Future<Object?> future) async {
  try {
    await future;
  } catch (_) {}
}

bool _sessionLost(Object error) => error is ApiException && error.sessionLost;

// Shows the cached data at once, then refreshes it. On session loss the root
// screen replaces this one; errors are ignored here.
class _HomeScreenState extends State<HomeScreen> {
  final _cache = HomeCache();
  String? _account;
  HomeSnapshot _data = HomeSnapshot();
  int _tab = 0;
  String? _openingInvoiceId;

  bool _loadingNumbers = true;
  Object? _numbersError;
  Object? _lineError;
  Object? _invoicesError;

  /// Refresh at launch or on retry, shown as a bar above cached content.
  bool _refreshingAll = false;

  /// Discards a conso response for a line no longer selected.
  int _lineRequest = 0;

  String? get _selectedNumber => _data.selectedNumber;
  CachedLine? get _line => _data.lines[_selectedNumber];

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final account = _account = await widget.api.account;
    final cached = account == null ? null : await _cache.load(account);
    if (!mounted) return;
    if (cached != null) setState(() => _data = cached);
    await _refreshAll();
  }

  /// All requests at once: if the token expired, they share one relogin.
  Future<void> _refreshAll() async {
    setState(() => _refreshingAll = true);
    await Future.wait([_refreshNumbers(), _refreshLine(), _refreshInvoices()]);
    if (mounted) setState(() => _refreshingAll = false);
  }

  void _save() {
    final account = _account;
    if (account != null) unawaited(_cache.save(account, _data));
  }

  Future<void> _refreshNumbers() async {
    setState(() {
      _loadingNumbers = true;
      _numbersError = null;
    });
    final name = _customerName();
    try {
      final numbers = await widget.api.activeNumbers();
      final customerName = await name;
      if (!mounted) return;
      final previous = _selectedNumber;
      setState(() {
        _data
          ..numbers = numbers
          ..customerName = customerName ?? _data.customerName
          ..selectedNumber = numbers.contains(previous)
              ? previous
              : numbers.firstOrNull;
        _data.lines.removeWhere((number, _) => !numbers.contains(number));
        _loadingNumbers = false;
      });
      _save();
      if (_selectedNumber != previous) await _refreshLine();
    } catch (e) {
      if (!mounted || _sessionLost(e)) return;
      setState(() {
        _loadingNumbers = false;
        _numbersError = e;
      });
      if (_data.numbers != null) _snackError(e);
    }
  }

  /// Optional: never throws, a lost session surfaces through other requests.
  Future<String?> _customerName() async {
    try {
      return await widget.api.customerName();
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshLine() async {
    final number = _selectedNumber;
    if (number == null) return;
    final request = ++_lineRequest;
    setState(() {
      _lineError = null;
    });
    final info = _lineInfo(number);
    try {
      final conso = await widget.api.conso(number);
      final lineInfo = await info;
      unawaited(updateConsoWidget(conso, number));
      if (!mounted || request != _lineRequest) return;
      setState(() {
        _data.lines[number] = CachedLine(
          conso: conso,
          info: lineInfo ?? _data.lines[number]?.info,
          updatedAt: DateTime.now(),
        );
      });
      _save();
    } catch (e) {
      if (!mounted || request != _lineRequest || _sessionLost(e)) return;
      setState(() {
        _lineError = e;
      });
      if (_line != null) _snackError(e);
    }
  }

  Future<LineInfo?> _lineInfo(String number) async {
    try {
      return await widget.api.lineInfo(number);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshInvoices() async {
    setState(() {
      _invoicesError = null;
    });
    try {
      final invoices = await widget.api.invoices();
      if (!mounted) return;
      setState(() {
        _data.invoices = invoices;
      });
      _save();
    } catch (e) {
      if (!mounted || _sessionLost(e)) return;
      setState(() {
        _invoicesError = e;
      });
      if (_data.invoices != null) _snackError(e);
    }
  }

  void _selectNumber(String number) {
    if (number == _selectedNumber) return;
    setState(() => _data.selectedNumber = number);
    _save();
    _refreshLine();
  }

  void _snackError(Object error) => _snack(
    'Actualisation impossible : '
    '${error is ApiException ? error.message : error}',
  );

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
      if (!e.sessionLost) _snack(e.message);
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
    try {
      await Future.wait([clearConsoWidget(), _cache.clear()]);
    } finally {
      await widget.api.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBar = _refreshingAll && _data.numbers != null;
    return Scaffold(
      appBar: AppBar(
        // Empty rather than a placeholder while the name loads.
        title: Text(_data.customerName ?? (_loadingNumbers ? '' : 'YouConso')),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: showBar
              ? const LinearProgressIndicator(minHeight: 2)
              : const SizedBox(height: 2),
        ),
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
    if (_data.numbers == null) {
      final error = _numbersError;
      if (error != null) {
        return StatusView.error(error: error, onRetry: _refreshAll);
      }
      return const Center(child: CircularProgressIndicator());
    }
    return IndexedStack(index: _tab, children: [_consoTab(), _invoicesTab()]);
  }

  Widget _consoTab() {
    final numbers = _data.numbers!;
    final number = _selectedNumber;
    if (numbers.isEmpty || number == null) {
      return const StatusView.empty(
        icon: Icons.sim_card_alert_outlined,
        text:
            'Aucune ligne active sur ce compte.\n'
            'Si votre commande est en cours, la conso sera disponible '
            'une fois la ligne activée.',
      );
    }
    return Column(
      children: [
        if (numbers.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<String>(
              initialValue: number,
              decoration: const InputDecoration(
                labelText: 'Ligne',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final n in numbers)
                  DropdownMenuItem(value: n, child: Text(formatPhone(n))),
              ],
              onChanged: (value) {
                if (value != null) _selectNumber(value);
              },
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _settle(_refreshLine()),
            child: _lineView(number),
          ),
        ),
      ],
    );
  }

  Widget _lineView(String number) {
    final line = _line;
    if (line == null) {
      final error = _lineError;
      if (error != null) {
        return StatusView.error(error: error, onRetry: _refreshLine);
      }
      return const Center(child: CircularProgressIndicator());
    }
    final groups = line.conso.groups;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        LineHeader(number: number, info: line.info),
        const SizedBox(height: 16),
        if (groups.isEmpty)
          const StatusView.empty(
            icon: Icons.hourglass_empty,
            text: 'Aucune donnée de consommation pour le moment.',
          )
        else
          for (final group in groups) ConsoCard(group: group),
        const SizedBox(height: 8),
        Text(
          '${_updatedLabel(line.updatedAt)}\n'
          'Le forfait se réinitialise le 1er de chaque mois.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static String _updatedLabel(DateTime at) {
    final now = DateTime.now();
    final time = DateFormat.Hm('fr_FR').format(at);
    if (DateUtils.isSameDay(at, now)) return 'Actualisé à $time';
    return 'Actualisé le ${DateFormat.MMMd('fr_FR').format(at)} à $time';
  }

  Widget _invoicesTab() {
    return RefreshIndicator(
      onRefresh: () => _settle(_refreshInvoices()),
      child: _invoicesView(),
    );
  }

  Widget _invoicesView() {
    final invoices = _data.invoices;
    if (invoices == null) {
      final error = _invoicesError;
      if (error != null) {
        return StatusView.error(error: error, onRetry: _refreshInvoices);
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (invoices.isEmpty) {
      return const StatusView.empty(
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
          busy: _openingInvoiceId != null && _openingInvoiceId == invoice.id,
          onTap: () => _openInvoice(invoice),
        );
      },
    );
  }
}
