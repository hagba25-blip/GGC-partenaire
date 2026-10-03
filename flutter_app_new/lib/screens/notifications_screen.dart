import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  final String clientId;
  final VoidCallback onOuvert;
  final int refreshTrigger;
  const NotificationsScreen({
    super.key,
    required this.clientId,
    required this.onOuvert,
    this.refreshTrigger = 0,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> notifications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recharge à chaque fois qu'on revient sur cet onglet (IndexedStack
    // garde l'écran en mémoire sans le reconstruire automatiquement).
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getNotifications(widget.clientId);
      setState(() { notifications = data["notifications"]; loading = false; });
      // Marque comme lues toutes celles qui ont une réponse admin non encore vue.
      for (final n in notifications) {
        if (n["repondu"] == true && n["lu_par_client"] == false) {
          ApiService.marquerNotificationLue(n["id"]);
        }
      }
      widget.onOuvert();
    } catch (_) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(child: Text("Aucune notification pour le moment."))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    itemBuilder: (_, i) {
                      final n = notifications[i];
                      final repondu = n["repondu"] == true;
                      final type = n["type"] == "produit" ? "Produit" : "Offre";
                      final date = DateTime.tryParse(n["created_at"] ?? "");

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    n["type"] == "produit" ? Icons.storefront_rounded : Icons.local_offer_rounded,
                                    color: AppColors.skyBlueDark, size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text("$type : ${n["item_nom"]}",
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (!repondu)
                                const Text(
                                  "On vous fait signe sur l'offre de ce produit.",
                                  style: TextStyle(color: AppColors.textDark, fontStyle: FontStyle.italic),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.skyLight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(n["message_admin"] ?? ""),
                                ),
                              if (date != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  DateFormat('dd/MM/yyyy HH:mm').format(date),
                                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
