import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/store_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/mock_data_service.dart';
import '../../theme/app_theme.dart';
import '../store/store_detail_screen.dart';
import '../cart/cart_screen.dart';
import '../order/orders_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final screens = [
      _buildHomeTab(context, l10n),
      const OrdersListScreen(),
      const CartScreen(),
      _buildProfileTab(context, l10n),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: l10n.tr('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt_long_outlined),
            activeIcon: const Icon(Icons.receipt_long),
            label: l10n.tr('my_orders'),
          ),
          BottomNavigationBarItem(
            icon: Consumer<CartProvider>(
              builder: (context, cart, child) {
                return Badge(
                  isLabelVisible: cart.itemCount > 0,
                  label: Text('${cart.itemCount}'),
                  child: const Icon(Icons.shopping_cart_outlined),
                );
              },
            ),
            activeIcon: Consumer<CartProvider>(
              builder: (context, cart, child) {
                return Badge(
                  isLabelVisible: cart.itemCount > 0,
                  label: Text('${cart.itemCount}'),
                  child: const Icon(Icons.shopping_cart),
                );
              },
            ),
            label: l10n.tr('cart'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outlined),
            activeIcon: const Icon(Icons.person),
            label: l10n.tr('profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, AppLocalizations l10n) {
    final localeProvider = context.watch<LocaleProvider>();
    final stores = MockDataService.getMockStores();
    final categories = MockDataService.getCategories();

    final filteredStores = _searchQuery.isEmpty
        ? stores
        : stores.where((s) {
            final query = _searchQuery.toLowerCase();
            return s.nameAr.toLowerCase().contains(query) ||
                s.nameFr.toLowerCase().contains(query) ||
                s.name.toLowerCase().contains(query) ||
                s.addressAr.toLowerCase().contains(query) ||
                s.addressFr.toLowerCase().contains(query);
          }).toList();

    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          floating: true,
          expandedHeight: 130,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppTheme.primaryGreenDark, AppTheme.primaryGreen],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.tr('app_name'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                l10n.tr('welcome_subtitle'),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.language, color: Colors.white),
                            onPressed: () => localeProvider.toggleLocale(),
                            tooltip: localeProvider.isArabic ? 'Français' : 'العربية',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: l10n.tr('search_stores'),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),

        // Categories
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  l10n.tr('categories'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.black,
                  ),
                ),
              ),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return Container(
                      width: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                cat['icon'] ?? '',
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            localeProvider.isArabic
                                ? (cat['ar'] ?? '')
                                : (cat['fr'] ?? ''),
                            style: const TextStyle(fontSize: 11),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Stores Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.tr('nearby_stores'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.black,
                  ),
                ),
                Text(
                  '${filteredStores.length} ${l10n.tr('all_stores').toLowerCase()}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Stores List
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final store = filteredStores[index];
                return _buildStoreCard(context, store, l10n, localeProvider);
              },
              childCount: filteredStores.length,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _buildStoreCard(
    BuildContext context,
    StoreModel store,
    AppLocalizations l10n,
    LocaleProvider localeProvider,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoreDetailScreen(store: store),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store Image
            Container(
              height: 140,
              width: double.infinity,
              color: AppTheme.lightGrey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    store.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      child: const Icon(
                        Icons.storefront,
                        size: 60,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                  // Open/Closed Badge
                  Positioned(
                    top: 8,
                    left: localeProvider.isArabic ? null : 8,
                    right: localeProvider.isArabic ? 8 : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: store.isOpen ? AppTheme.success : AppTheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        store.isOpen
                            ? l10n.tr('open_now')
                            : l10n.tr('closed'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Store Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          store.getLocalizedName(localeProvider.languageCode),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            store.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          store.getLocalizedAddress(localeProvider.languageCode),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        store.phone,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab(BuildContext context, AppLocalizations l10n) {
    final authProvider = context.watch<AuthProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('profile')),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? '',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (user?.email.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      user!.email,
                      style: TextStyle(color: Colors.grey[600]),
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                  if (user?.phone.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      user!.phone,
                      style: TextStyle(color: Colors.grey[600]),
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Language
          Card(
            child: ListTile(
              leading: const Icon(Icons.language, color: AppTheme.primaryGreen),
              title: Text(l10n.tr('language')),
              trailing: Text(
                localeProvider.isArabic ? l10n.tr('arabic') : l10n.tr('french'),
                style: const TextStyle(color: AppTheme.primaryGreen),
              ),
              onTap: () => localeProvider.toggleLocale(),
            ),
          ),

          // Notifications
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined, color: AppTheme.primaryGreen),
              title: Text(l10n.tr('notifications')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),

          // About
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outlined, color: AppTheme.primaryGreen),
              title: Text(l10n.tr('about')),
              subtitle: Text('${l10n.tr('version')} 1.0.0'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),

          const SizedBox(height: 24),

          // Logout
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => authProvider.logout(),
              icon: const Icon(Icons.logout, color: AppTheme.error),
              label: Text(
                l10n.tr('logout'),
                style: const TextStyle(color: AppTheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
