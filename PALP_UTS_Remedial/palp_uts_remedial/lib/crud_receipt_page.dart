import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CrudReceiptPage extends StatefulWidget {
  const CrudReceiptPage({super.key});

  @override
  State<CrudReceiptPage> createState() => _CrudReceiptPageState();
}

class _CrudReceiptPageState extends State<CrudReceiptPage> {
  DocumentReference? _storeRef;
  List<DocumentSnapshot> _receipts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    final prefs = await SharedPreferences.getInstance();
    final storeRefPath = prefs.getString('store_ref');

    if (storeRefPath == null || storeRefPath.isEmpty) {
      setState(() {
        _loading = false;
        _storeRef = null;
      });
      return;
    }

    final storeRef = FirebaseFirestore.instance.doc(storeRefPath);
    final snapshot = await FirebaseFirestore.instance
        .collection('purchaseGoodsReceipts')
        .where('store_ref', isEqualTo: storeRef)
        .get();

    setState(() {
      _storeRef = storeRef;
      _receipts = snapshot.docs;
      _loading = false;
    });
  }

  void _selectStore() async {
    final stores = await FirebaseFirestore.instance.collection('stores').get();

    DocumentReference? selected;

    await showDialog(
      context: context,
      builder: (context) {
        DocumentReference? temp;
        return AlertDialog(
          title: const Text("Select Store"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return DropdownButtonFormField<DocumentReference>(
                items: stores.docs.map((doc) {
                  return DropdownMenuItem(
                    value: doc.reference,
                    child: Text(doc['name']),
                  );
                }).toList(),
                onChanged: (value) => temp = value,
                decoration: const InputDecoration(labelText: "Store"),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                selected = temp;
                Navigator.pop(context);
              },
              child: const Text("Select"),
            ),
          ],
        );
      },
    );

    if (selected != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('store_ref', selected!.path);
      await _loadReceipts();
    }
  }

  void _openAddForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptFormPage(storeRef: _storeRef!),
      ),
    );
    if (result == true) await _loadReceipts();
  }

  void _openEditForm(DocumentSnapshot doc) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReceiptFormPage(
        storeRef: _storeRef!,
        receiptDoc: doc,
      ),
    );
    if (result == true) await _loadReceipts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.indigo, title: const Text('Receipts')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _storeRef == null
              ? Center(
                  child: ElevatedButton.icon(
                    onPressed: _selectStore,
                    icon: const Icon(Icons.store),
                    label: const Text("Select Store"),
                  ),
                )
              : _receipts.isEmpty
                  ? const Center(child: Text('No receipts yet.'))
                  : ListView.builder(
                      itemCount: _receipts.length,
                      itemBuilder: (context, index) {
                        final data = _receipts[index].data() as Map<String, dynamic>;
                        final doc = _receipts[index];
                        return Card(
                          color: Colors.indigo.shade50,
                          margin: const EdgeInsets.all(10),
                          child: ListTile(
                            title: Text("No. Form: ${data['no_form']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Grand Total: ${data['grandtotal']}"),
                                Text("Item Total: ${data['item_total']}"),
                                Text("Posted: ${data['post_date']}"),
                              ],
                            ),
                            onTap: () => _openEditForm(doc),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        onPressed: _openAddForm,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ReceiptFormPage extends StatefulWidget {
  final DocumentReference storeRef;
  final DocumentSnapshot? receiptDoc;

  const ReceiptFormPage({super.key, required this.storeRef, this.receiptDoc});

  @override
  State<ReceiptFormPage> createState() => _ReceiptFormPageState();
}

class _ReceiptFormPageState extends State<ReceiptFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _formNumberController = TextEditingController();
  DocumentReference? _supplier, _warehouse;
  List<DocumentSnapshot> _suppliers = [], _warehouses = [], _products = [];
  final List<_DetailItem> _details = [];
  bool _loading = true;

  int get itemTotal => _details.fold(0, (sum, item) => sum + item.qty);
  int get grandTotal => _details.fold(0, (sum, item) => sum + item.subtotal);

  bool get isEditing => widget.receiptDoc != null;

  @override
  void initState() {
    super.initState();
    _fetchDropdowns();
  }

  Future<void> _fetchDropdowns() async {
    final s = await FirebaseFirestore.instance.collection('suppliers').get();
    final w = await FirebaseFirestore.instance.collection('warehouses').get();
    final p = await FirebaseFirestore.instance.collection('products').get();

    if (isEditing) {
      final data = widget.receiptDoc!.data() as Map<String, dynamic>;
      _formNumberController.text = data['no_form'];
      _supplier = data['supplier_ref'] as DocumentReference?;
      _warehouse = data['warehouse_ref'] as DocumentReference?;
      final detailsSnap = await widget.receiptDoc!.reference.collection('details').get();
      for (var doc in detailsSnap.docs) {
        _details.add(_DetailItem.fromMap(doc.data(), _products, doc.reference));
      }
    }

    setState(() {
      _suppliers = s.docs;
      _warehouses = w.docs;
      _products = p.docs;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _details.isEmpty) return;

    final data = {
      'no_form': _formNumberController.text.trim(),
      'grandtotal': grandTotal,
      'item_total': itemTotal,
      'post_date': DateTime.now().toIso8601String(),
      'store_ref': widget.storeRef,
      'supplier_ref': _supplier,
      'warehouse_ref': _warehouse,
      'synced': true,
    };

    if (isEditing) {
      final ref = widget.receiptDoc!.reference;
      await ref.update(data);
      final existingDetails = await ref.collection('details').get();
      for (var doc in existingDetails.docs) {
        await doc.reference.delete();
      }
      for (var item in _details) {
        await ref.collection('details').add(item.toMap());
      }
    } else {
      data['created_at'] = DateTime.now();
      final doc = await FirebaseFirestore.instance.collection('purchaseGoodsReceipts').add(data);
      for (var item in _details) {
        await doc.collection('details').add(item.toMap());
      }
    }

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Delete this receipt?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirm == true && isEditing) {
      final ref = widget.receiptDoc!.reference;
      final details = await ref.collection('details').get();
      for (var doc in details.docs) {
        await doc.reference.delete();
      }
      await ref.delete();
      if (mounted) Navigator.pop(context, true);
    }
  }

  void _addDetail() {
    setState(() => _details.add(_DetailItem(products: _products)));
  }

  void _removeDetail(int index) {
    setState(() => _details.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: isEditing ? Colors.deepOrange : Colors.indigo,
        title: Text(isEditing ? 'Edit Receipt' : 'Add Receipt'),
        actions: isEditing
            ? [IconButton(icon: const Icon(Icons.delete), onPressed: _delete)]
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _formNumberController,
                      decoration: const InputDecoration(labelText: 'No. Form'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    DropdownButtonFormField<DocumentReference>(
                      value: _supplier,
                      items: _suppliers.map((doc) {
                        return DropdownMenuItem(
                          value: doc.reference,
                          child: Text(doc['name']),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _supplier = v),
                      decoration: const InputDecoration(labelText: 'Supplier'),
                    ),
                    DropdownButtonFormField<DocumentReference>(
                      value: _warehouse,
                      items: _warehouses.map((doc) {
                        return DropdownMenuItem(
                          value: doc.reference,
                          child: Text(doc['name']),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _warehouse = v),
                      decoration: const InputDecoration(labelText: 'Warehouse'),
                    ),
                    const SizedBox(height: 16),
                    const Text("Details", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._details.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Card(
                        color: Colors.grey.shade100,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              DropdownButtonFormField<DocumentReference>(
                                value: item.productRef,
                                items: _products.map((doc) {
                                  return DropdownMenuItem(
                                    value: doc.reference,
                                    child: Text(doc['name']),
                                  );
                                }).toList(),
                                onChanged: (v) => setState(() {
                                  item.productRef = v;
                                  item.unitName = 'unit'; // default unit
                                }),
                                decoration: const InputDecoration(labelText: 'Product'),
                              ),
                              TextFormField(
                                initialValue: item.price.toString(),
                                decoration: const InputDecoration(labelText: 'Price'),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => setState(() => item.price = int.tryParse(val) ?? 0),
                              ),
                              TextFormField(
                                initialValue: item.qty.toString(),
                                decoration: const InputDecoration(labelText: 'Qty'),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => setState(() => item.qty = int.tryParse(val) ?? 1),
                              ),
                              Text("Unit: ${item.unitName}"),
                              Text("Subtotal: ${item.subtotal}"),
                              TextButton.icon(
                                onPressed: () => _removeDetail(index),
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                label: const Text("Remove"),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Add Detail"),
                      onPressed: _addDetail,
                    ),
                    const SizedBox(height: 16),
                    Text("Item Total: $itemTotal"),
                    Text("Grand Total: $grandTotal"),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _save,
                      child: Text(isEditing ? 'Update' : 'Save'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _DetailItem {
  DocumentReference? productRef;
  int price;
  int qty;
  String unitName;
  final List<DocumentSnapshot> products;
  final DocumentReference? ref;

  _DetailItem({
    this.productRef,
    this.price = 0,
    this.qty = 1,
    this.unitName = 'unit',
    required this.products,
    this.ref,
  });

  factory _DetailItem.fromMap(Map<String, dynamic> data, List<DocumentSnapshot> products, DocumentReference ref) {
    return _DetailItem(
      productRef: data['product_ref'] as DocumentReference?,
      price: data['price'] ?? 0,
      qty: data['qty'] ?? 1,
      unitName: data['unit_name'] ?? 'unit',
      products: products,
      ref: ref,
    );
  }

  int get subtotal => price * qty;

  Map<String, dynamic> toMap() => {
        'product_ref': productRef,
        'price': price,
        'qty': qty,
        'unit_name': unitName,
        'subtotal': subtotal,
      };
}
