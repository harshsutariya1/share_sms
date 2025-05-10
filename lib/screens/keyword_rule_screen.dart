import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_sms/models/keyword_rule_model.dart';
import 'package:share_sms/models/user_model.dart';
import 'package:share_sms/providers/auth_providers.dart';
import 'package:share_sms/providers/sharing_providers.dart';

class KeywordRuleScreen extends ConsumerWidget {
  const KeywordRuleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keywordRulesAsync = ref.watch(keywordRulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keyword Rules'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(keywordRulesProvider);
        },
        child: keywordRulesAsync.when(
          data: (rules) {
            if (rules.isEmpty) {
              return const Center(child: Text('No keyword rules set up yet'));
            }

            return ListView.builder(
              itemCount: rules.length,
              itemBuilder: (context, index) {
                final rule = rules[index];
                return _KeywordRuleItem(rule: rule);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, stack) =>
                  Center(child: Text('Error loading rules: $error')),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => const _CreateKeywordRuleSheet(),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Rule'),
      ),
    );
  }
}

class _KeywordRuleItem extends ConsumerWidget {
  final KeywordRuleModel rule;

  const _KeywordRuleItem({required this.rule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharingService = ref.watch(sharingServiceProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<UserModel?>(
                    future: ref
                        .read(databaseServiceProvider)
                        .getUserDetails(rule.receiverId),
                    builder: (context, snapshot) {
                      return Text(
                        'Share with: ${snapshot.data?.username ?? rule.receiverId}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      );
                    },
                  ),
                ),
                Switch(
                  value: rule.isActive,
                  onChanged: (value) {
                    if (sharingService != null) {
                      sharingService.updateKeywordRule(
                        KeywordRuleModel(
                          id: rule.id,
                          userId: rule.userId,
                          receiverId: rule.receiverId,
                          keywords: rule.keywords,
                          isActive: value,
                          createdAt: rule.createdAt,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Keywords:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children:
                  rule.keywords
                      .map(
                        (keyword) => Chip(
                          label: Text(keyword),
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                        ),
                      )
                      .toList(),
            ),
            ButtonBar(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Delete Rule'),
                            content: const Text(
                              'Are you sure you want to delete this rule?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  if (sharingService != null) {
                                    sharingService.deleteKeywordRule(rule.id);
                                  }
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateKeywordRuleSheet extends ConsumerStatefulWidget {
  const _CreateKeywordRuleSheet();

  @override
  ConsumerState<_CreateKeywordRuleSheet> createState() =>
      _CreateKeywordRuleSheetState();
}

class _CreateKeywordRuleSheetState
    extends ConsumerState<_CreateKeywordRuleSheet> {
  final _keywordController = TextEditingController();

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keywordRuleState = ref.watch(keywordRuleControllerProvider);
    final controller = ref.read(keywordRuleControllerProvider.notifier);
    final availableUsersAsync = ref.watch(availableUsersProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create New Keyword Rule',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // User selection dropdown
          availableUsersAsync.when(
            data: (users) {
              if (users.isEmpty) {
                return const Text('No users available to share with');
              }

              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Share with',
                  border: OutlineInputBorder(),
                ),
                value: keywordRuleState.selectedUserId,
                items:
                    users.map((user) {
                      return DropdownMenuItem(
                        value: user.uid,
                        child: Text(user.username ?? user.email),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    controller.setSelectedUser(value);
                  }
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Text('Error loading users: $error'),
          ),

          const SizedBox(height: 16),

          // Keywords input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: 'Add Keyword',
                    hintText: 'Enter a keyword to trigger sharing',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      controller.addKeyword(value);
                      _keywordController.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle),
                onPressed: () {
                  if (_keywordController.text.trim().isNotEmpty) {
                    controller.addKeyword(_keywordController.text);
                    _keywordController.clear();
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Keywords display
          const Text(
            'Keywords:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),

          if (keywordRuleState.keywords.isEmpty)
            const Text(
              'No keywords added yet',
              style: TextStyle(fontStyle: FontStyle.italic),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children:
                  keywordRuleState.keywords.map((keyword) {
                    return InputChip(
                      label: Text(keyword),
                      onDeleted: () {
                        controller.removeKeyword(keyword);
                      },
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                    );
                  }).toList(),
            ),

          const SizedBox(height: 16),

          if (keywordRuleState.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                keywordRuleState.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed:
                    keywordRuleState.isCreating
                        ? null
                        : () async {
                          final success = await controller.createRule();
                          if (success && mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                child:
                    keywordRuleState.isCreating
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Create Rule'),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
