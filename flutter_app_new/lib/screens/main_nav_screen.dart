import 'package:flutter/material.dart';
import 'echeancier_screen.dart';
import 'produits_screen.dart';
import 'notifications_screen.dart';
import 'offres_screen.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Écran principal de l'app une fois l'inscription/paiement terminés.
/// 4 onglets : Paiement (échéancier, objectif principal), Produits,
/// Notifications (réponses admin aux intérêts + badge), Offres.
class MainNavScreen extends StatefulWidget {
  final String clientId;
  final double montantEcheance;
  const MainNavScreen({super.key, required this.clientId, required this.montantEcheance});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _index = 0;
  int _notifNonLues = 0;
  int _notifRefreshTrigger = 0;
  int _echeancierRefreshTrigger = 0;

  @override
  void initState() {
    super.initState();
    _chargerBadge();
  }

  Future<void> _chargerBadge() async {
    try {
      final data = await ApiService.getNotifications(widget.clientId);
      if (mounted) setState(() => _notifNonLues = data["non_lues"] ?? 0);
    } catch (_) {}
  }

  void allerNotifications() {
    setState(() {
      _index = 2;
      _notifRefreshTrigger++;
    });
    _chargerBadge();
  }

  /// Appelé quand le client crée un échéancier pour un produit (bouton
  /// "Intéressé" -> "Oui, créez-moi un paiement"). Bascule sur l'onglet
  /// Paiement et force le rechargement de l'échéancier, sans toucher au
  /// rôle habituel du bouton "Intéressé".
  void allerPaiementApresAchat() {
    setState(() {
      _index = 0;
      _echeancierRefreshTrigger++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      EcheancierScreen(
        clientId: widget.clientId,
        montantEcheance: widget.montantEcheance,
        refreshTrigger: _echeancierRefreshTrigger,
      ),
      ProduitsScreen(
        clientId: widget.clientId,
        onInteretEnvoye: allerNotifications,
        onAchatCree: allerPaiementApresAchat,
      ),
      NotificationsScreen(
        clientId: widget.clientId,
        onOuvert: _chargerBadge,
        refreshTrigger: _notifRefreshTrigger,
      ),
      OffresScreen(clientId: widget.clientId, onInteretEnvoye: allerNotifications),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            _index = i;
            if (i == 2) _notifRefreshTrigger++;
          });
          if (i == 2) _chargerBadge();
        },
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.skyLight,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments_rounded, color: AppColors.skyBlueDark),
            label: "Paiement",
          ),
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded, color: AppColors.skyBlueDark),
            label: "Produits",
          ),
          NavigationDestination(
            icon: Badge(
              label: Text("$_notifNonLues"),
              isLabelVisible: _notifNonLues > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              label: Text("$_notifNonLues"),
              isLabelVisible: _notifNonLues > 0,
              child: const Icon(Icons.notifications_rounded, color: AppColors.skyBlueDark),
            ),
            label: "Notifications",
          ),
          const NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer_rounded, color: AppColors.skyBlueDark),
            label: "Offres",
          ),
        ],
      ),
    );
  }
}
