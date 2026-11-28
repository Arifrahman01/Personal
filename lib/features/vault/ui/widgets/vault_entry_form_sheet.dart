import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_hub/core/errors/app_exceptions.dart';
import 'package:personal_hub/core/theme/app_tokens.dart';
import 'package:personal_hub/features/vault/models/vault_entry.dart';
import 'package:personal_hub/features/vault/providers/vault_providers.dart';
import 'package:personal_hub/features/vault/services/password_generator.dart';

/// Form bottom sheet for creating or updating a [VaultEntry].
class VaultEntryFormSheet extends ConsumerStatefulWidget {
  const VaultEntryFormSheet({super.key, this.existing});

  final VaultEntry? existing;

  @override
  ConsumerState<VaultEntryFormSheet> createState() =>
      _VaultEntryFormSheetState();
}

class _VaultEntryFormSheetState extends ConsumerState<VaultEntryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _urlController;
  late final TextEditingController _notesController;

  bool _obscurePassword = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _usernameController = TextEditingController(
      text: widget.existing?.username ?? '',
    );
    _passwordController = TextEditingController(
      text: widget.existing?.password ?? '',
    );
    _urlController = TextEditingController(text: widget.existing?.url ?? '');
    _notesController = TextEditingController(
      text: widget.existing?.notes ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _generatePassword() {
    final generated = PasswordGenerator.generate(
      length: 16,
      upper: true,
      lower: true,
      digits: true,
      symbols: true,
    );
    setState(() {
      _passwordController.text = generated;
      _obscurePassword = false;
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(vaultEntriesProvider.notifier);
      if (widget.existing != null) {
        await notifier.updateEntry(
          widget.existing!.copyWith(
            title: _titleController.text.trim(),
            username: _usernameController.text.trim(),
            password: _passwordController.text,
            url: _urlController.text.trim(),
            notes: _notesController.text.trim(),
          ),
        );
      } else {
        await notifier.createEntry(
          title: _titleController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          url: _urlController.text.trim(),
          notes: _notesController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ValidationException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal menyimpan entri brankas. Coba lagi.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final colorScheme = Theme.of(context).colorScheme;
    final primary = AppTokens.primary(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
          left: HubSpacing.xl,
          right: HubSpacing.xl,
          top: HubSpacing.xs,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      isEditing
                          ? Icons.edit_rounded
                          : Icons.add_circle_outline_rounded,
                      size: 22,
                      color: primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEditing ? 'Edit Akun' : 'Tambah Akun Baru',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Judul Akun *',
                    hintText: 'Misal: GitHub, Email Kantor, dsb.',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Judul akun tidak boleh kosong.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username / Email',
                    hintText: 'user@example.com',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Kata Sandi *',
                    hintText: 'Sandi rahasia',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Buat sandi acak kuat',
                          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                          onPressed: _generatePassword,
                        ),
                        IconButton(
                          tooltip: _obscurePassword
                              ? 'Tampilkan sandi'
                              : 'Sembunyikan sandi',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Kata sandi tidak boleh kosong.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Website / URL',
                    hintText: 'https://...',
                    prefixIcon: Icon(Icons.language_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (Opsional)',
                    hintText: 'Pertanyaan keamanan, nomor pemulihan, dsb.',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: AppTokens.error(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: HubRadius.rSm),
                  ),
                  onPressed: _isSaving ? null : _handleSave,
                  icon: _isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    isEditing ? 'Simpan Perubahan' : 'Simpan ke Brankas',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
