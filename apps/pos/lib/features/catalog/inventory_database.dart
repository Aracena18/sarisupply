import 'dart:convert';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sqflite/sqflite.dart';

Future<InventoryStore> openInventory(String merchantId, String branchId) async {
  final root = await getDatabasesPath();
  final scope = base64Url
      .encode(utf8.encode('$merchantId\u0000$branchId'))
      .replaceAll('=', '');
  return InventoryStore.open(databaseFactory, '$root/inventory-$scope.db',
      merchantId: merchantId, branchId: branchId);
}
