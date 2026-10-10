import 'package:sqflite/sqflite.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';

Future<CompanyWorkStorage> openCompanyWorkStorage({
  required String companyId,
  required String uid,
  required String role,
}) async {
  final root = await getDatabasesPath();
  return CompanyWorkStore.open(
    databaseFactory,
    '$root/company-${Uri.encodeComponent(companyId)}-${Uri.encodeComponent(uid)}-${Uri.encodeComponent(role)}.db',
    companyId: companyId,
    uid: uid,
    role: role,
  );
}
