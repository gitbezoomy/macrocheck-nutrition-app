import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../services/user_food_storage.dart';
import '../models/food_model.dart';
import '../l10n/app_localizations.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final UserFoodStorage _storage = UserFoodStorage();
  final ImagePicker _picker = ImagePicker();
  List<FoodModel> _userFoods = [];

  @override
  void initState() {
    super.initState();
    _loadUserFoods();
  }

  Future<void> _loadUserFoods() async {
    final foods = await _storage.getFoods();
    setState(() {
      _userFoods = foods..sort((a, b) => (b.usageCount ?? 0).compareTo(a.usageCount ?? 0));
    });
  }

  Future<void> _handleManualRegistration() async {
    _showReviewForm(data: null, imagePath: null);
  }

  void _showReviewForm({Map<String, dynamic>? data, String? imagePath}) {
    final nameController = TextEditingController(text: data?['name'] ?? '');
    final calController = TextEditingController(text: (data?['calories'] ?? '').toString());
    final protController = TextEditingController(text: (data?['protein'] ?? '').toString());
    final carbController = TextEditingController(text: (data?['carbs'] ?? '').toString());
    final fatController = TextEditingController(text: (data?['fat'] ?? '').toString());
    final brandController = TextEditingController(text: data?['brand'] ?? '');
    String? currentImagePath = imagePath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: Color(0xFF87A96B)),
                const SizedBox(width: 8),
                Text(
                  'Novo Registro Manual',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Verifique as informações. Você também pode adicionar uma foto do produto.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 24),
            Expanded(
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  return ListView(
                    children: [
                       GestureDetector(
                         onTap: () async {
                           final picker = ImagePicker();
                           final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 60);
                           if (img != null) {
                             setModalState(() => currentImagePath = img.path);
                           }
                         },
                         child: Container(
                           height: 120,
                           width: double.infinity,
                           margin: const EdgeInsets.only(bottom: 24),
                           decoration: BoxDecoration(
                             color: Colors.grey.shade100,
                             borderRadius: BorderRadius.circular(16),
                             border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                             image: currentImagePath != null 
                              ? DecorationImage(image: FileImage(File(currentImagePath!)), fit: BoxFit.cover)
                              : null,
                           ),
                           child: currentImagePath == null 
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade400, size: 32),
                                  const SizedBox(height: 8),
                                  const Text('Adicionar foto da embalagem', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              )
                            : Container(
                                alignment: Alignment.bottomRight,
                                padding: const EdgeInsets.all(8),
                                child: const CircleAvatar(
                                  backgroundColor: Colors.black54,
                                  radius: 14,
                                  child: Icon(Icons.edit, color: Colors.white, size: 14),
                                ),
                              ),
                         ),
                       ),
                       _buildField('Nome do Alimento', nameController, Icons.restaurant),
                       _buildField('Marca (Opcional)', brandController, Icons.branding_watermark),
                       Row(
                         children: [
                           Expanded(child: _buildField('Calorias', calController, Icons.local_fire_department, isNum: true)),
                           const SizedBox(width: 16),
                           Expanded(child: _buildField('Proteínas (g)', protController, Icons.fitness_center, isNum: true)),
                         ],
                       ),
                       Row(
                         children: [
                           Expanded(child: _buildField('Carbos (g)', carbController, Icons.grain, isNum: true)),
                           const SizedBox(width: 16),
                           Expanded(child: _buildField('Gorduras (g)', fatController, Icons.opacity, isNum: true)),
                         ],
                       ),
                    ],
                  );
                }
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () async {
                  final newFood = FoodModel(
                    id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameController.text,
                    brand: brandController.text,
                    description: 'Cals: ${calController.text}kcal | Fat: ${fatController.text}g | Carbs: ${carbController.text}g | Prot: ${protController.text}g',
                    imageUrl: currentImagePath,
                    usageCount: 0,
                  );
                  await _storage.saveFood(newFood);
                  if (context.mounted) Navigator.pop(context);
                  _loadUserFoods();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF87A96B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Salvar em Meus Registros', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {bool isNum = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF87A96B)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.grey.shade50,
          labelStyle: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).translate('my_records'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverToBoxAdapter(
              child: _buildHeaderActions(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Meus Alimentos Salvos',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
            sliver: _userFoods.isEmpty 
              ? SliverToBoxAdapter(child: _buildEmptyState())
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final food = _userFoods[index];
                      return _buildFoodItem(food);
                    },
                    childCount: _userFoods.length,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Column(
      children: [
        _buildActionCard(
          title: 'Registro Manual',
          subtitle: 'Cadastre alimentos personalizados do zero.',
          icon: Icons.edit_note_rounded,
          onTap: _handleManualRegistration,
          colors: [const Color(0xFF87A96B), const Color(0xFF9EAFC1)],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required List<Color> colors,
    bool isSmall = false,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: EdgeInsets.all(isSmall ? 16 : 24),
            child: Row(
              children: [
                Icon(icon, size: isSmall ? 32 : 48, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmall ? 18 : 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFoodItem(FoodModel food) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5F1),
            borderRadius: BorderRadius.circular(12),
            image: food.imageUrl != null 
              ? DecorationImage(image: FileImage(File(food.imageUrl!)), fit: BoxFit.cover)
              : null,
          ),
          child: food.imageUrl == null ? const Icon(Icons.restaurant_rounded, color: Color(0xFF87A96B)) : null,
        ),
        title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${food.brand} • ${food.usageCount ?? 0} usos', style: const TextStyle(fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () async {
             await _storage.deleteFood(food.id);
             _loadUserFoods();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFFEEEEEE)),
          SizedBox(height: 16),
          Text('Nenhum alimento registrado ainda.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
