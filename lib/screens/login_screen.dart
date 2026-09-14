import 'package:flutter/material.dart';

import '../api/youprice_api.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api, this.message});

  final YoupriceApi api;

  /// Motif affiché en tête (session expirée, par exemple).
  final String? message;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  bool _codeStep = false;
  bool _busy = false;
  bool _obscure = true;
  String? _info;

  @override
  void initState() {
    super.initState();
    _info = widget.message;
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// En cas de succès, l'API passe la session à « active » et la racine de
  /// l'app affiche l'accueil : rien à naviguer ici.
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      if (_codeStep) {
        await widget.api.loginWithCode(
          _username.text.trim(),
          _password.text,
          _code.text.trim(),
        );
        return;
      }
      final result = await widget.api.login(
        _username.text.trim(),
        _password.text,
      );
      if (!mounted || result == LoginResult.loggedIn) return;
      setState(() {
        _codeStep = true;
        _info =
            'Un code de vérification vous a été envoyé par e-mail. '
            'Pensez à vérifier vos spams.';
      });
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      await widget.api.resendCode(_username.text.trim(), _password.text);
      _snack('Nouveau code envoyé.');
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/icon/logo.png',
                            width: 88,
                            height: 88,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'YouConso',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Connexion à votre espace client Youprice',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      if (_info != null) ...[
                        Card(
                          color: theme.colorScheme.secondaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(_info!),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _username,
                        enabled: !_busy && !_codeStep,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Identifiant (e-mail)',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Saisissez votre identifiant'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        enabled: !_busy && !_codeStep,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: _codeStep
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onFieldSubmitted: (_) => _codeStep ? null : _submit(),
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Saisissez votre mot de passe'
                            : null,
                      ),
                      if (_codeStep) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _code,
                          enabled: !_busy,
                          autofocus: true,
                          keyboardType: TextInputType.visiblePassword,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Code de vérification',
                            prefixIcon: Icon(Icons.pin_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Saisissez le code reçu'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _codeStep
                                      ? 'Valider le code'
                                      : 'Se connecter',
                                ),
                        ),
                      ),
                      if (_codeStep) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : _resend,
                          child: const Text('Renvoyer le code'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _codeStep = false;
                                  _code.clear();
                                  _info = null;
                                }),
                          child: const Text('Modifier mes identifiants'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
