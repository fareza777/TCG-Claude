import 'package:flutter/material.dart';

class DeleteAccountTile extends StatelessWidget {
  const DeleteAccountTile({super.key, required this.onDelete});

  final Future<bool> Function() onDelete;

  Future<void> _confirm(BuildContext context) async {
    var busy = false;
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Delete Shardfall account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This permanently deletes your cloud save, PvP history, and '
                'purchase entitlements linked to this account. Local guest '
                'progress on this device is not uploaded again.',
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade800,
              ),
              onPressed: busy
                  ? null
                  : () async {
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      final deleted = await onDelete();
                      if (!dialogContext.mounted) return;
                      if (!deleted) {
                        setState(() {
                          busy = false;
                          error = 'Could not delete the account. Try again.';
                        });
                        return;
                      }
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Account deleted')),
                      );
                    },
              child: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('DELETE ACCOUNT'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(
        Icons.delete_forever_outlined,
        color: Colors.redAccent,
      ),
      title: const Text('Delete account'),
      subtitle: const Text('Permanently remove your cloud account and data'),
      onTap: () => _confirm(context),
    );
  }
}
