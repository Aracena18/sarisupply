import 'dart:convert';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sqflite/sqflite.dart';

Future<InventoryStore> openDriverInventory({
  required String merchantId,
  required String branchId,
}) async {
  final root = await getDatabasesPath();
  final scope = base64Url
      .encode(utf8.encode('$merchantId\u0000$branchId'))
      .replaceAll('=', '');
  return InventoryStore.open(
    databaseFactory,
    '$root/driver-$scope.db',
    merchantId: merchantId,
    branchId: branchId,
  );
}
