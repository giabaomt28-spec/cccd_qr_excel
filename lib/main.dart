import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: CCCDScannerScreen(),
  ));
}

// Model lưu cấu trúc dữ liệu CCCD
class CCCDInfo {
  final String idNumber;
  final String oldIDNumber;
  final String fullName;
  final String dateOfBirth;
  final String gender;
  final String address;
  final String issueDate;

  CCCDInfo({
    required this.idNumber,
    required this.oldIDNumber,
    required this.fullName,
    required this.dateOfBirth,
    required this.gender,
    required this.address,
    required this.issueDate,
  });

  // Tách chuỗi QR dạng: CCCD|CMND_CŨ|HỌ_TÊN|NGÀY_SINH|GIỚI_TÍNH|ĐỊA_CHỈ|NGÀY_CẤP
  static CCCDInfo? parse(String rawData) {
    List<String> parts = rawData.split('|');
    if (parts.length < 6) return null;

    return CCCDInfo(
      idNumber: parts[0],
      oldIDNumber: parts[1],
      fullName: parts[2],
      dateOfBirth: parts[3],
      gender: parts[4],
      address: parts[5],
      issueDate: parts.length > 6 ? parts[6] : '',
    );
  }
}

class CCCDScannerScreen extends StatefulWidget {
  const CCCDScannerScreen({super.key});

  @override
  State<CCCDScannerScreen> createState() => _CCCDScannerScreenState();
}

class _CCCDScannerScreenState extends State<CCCDScannerScreen> {
  final List<CCCDInfo> scannedList = [];
  bool isScanning = true;

  // Hàm tạo và lưu danh sách danh sách CCCD ra file Excel (.xlsx)
  Future<void> exportToExcel() async {
    if (scannedList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có dữ liệu để xuất file Excel!')),
      );
      return;
    }

    // Xin quyền truy cập bộ nhớ
    await Permission.storage.request();

    // Tạo file Excel mới
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['DanhSach_CCCD'];
    excel.delete('Sheet1'); // Xóa sheet mặc định

    // Ghi tiêu đề cột (Header)
    sheetObject.appendRow([
      TextCellValue('STT'),
      TextCellValue('Số CCCD'),
      TextCellValue('Số CMND cũ'),
      TextCellValue('Họ và Tên'),
      TextCellValue('Ngày sinh'),
      TextCellValue('Giới tính'),
      TextCellValue('Địa chỉ thường trú'),
      TextCellValue('Ngày cấp'),
    ]);

    // Ghi dữ liệu từng người
    for (int i = 0; i < scannedList.length; i++) {
      var item = scannedList[i];
      sheetObject.appendRow([
        IntCellValue(i + 1),
        TextCellValue(item.idNumber),
        TextCellValue(item.oldIDNumber),
        TextCellValue(item.fullName),
        TextCellValue(item.dateOfBirth),
        TextCellValue(item.gender),
        TextCellValue(item.address),
        TextCellValue(item.issueDate),
      ]);
    }

    // Lấy thư mục lưu trữ file
    Directory? directory = await getExternalStorageDirectory();
    if (directory == null) {
      directory = await getApplicationDocumentsDirectory();
    }

    String filePath = "${directory.path}/DanhSach_CCCD_${DateTime.now().millisecondsSinceEpoch}.xlsx";
    File file = File(filePath);
    
    // Ghi dữ liệu ra file
    var fileBytes = excel.save();
    if (fileBytes != null) {
      await file.writeAsBytes(fileBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xuất file Excel thành công!\nLưu tại: $filePath'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét QR CCCD & Xuất Excel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Xuất Excel',
            onPressed: exportToExcel,
          ),
        ],
      ),
      body: Column(
        children: [
          // Khung Quét Camera
          SizedBox(
            height: 280,
            child: MobileScanner(
              onDetect: (capture) {
                if (!isScanning) return;
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    final parsed = CCCDInfo.parse(barcode.rawValue!);
                    if (parsed != null) {
                      // Kiểm tra xem số CCCD này đã quét chưa để tránh trùng lặp
                      bool isDuplicate = scannedList.any((e) => e.idNumber == parsed.idNumber);
                      if (!isDuplicate) {
                        setState(() {
                          scannedList.add(parsed);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã thêm: ${parsed.fullName}')),
                        );
                      }
                    }
                  }
                }
              },
            ),
          ),
          
          // Thanh danh sách kết quả đã quét
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Đã quét: ${scannedList.length} người',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                ElevatedButton.icon(
                  onPressed: exportToExcel,
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Xuất file Excel'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                )
              ],
            ),
          ),

          const Divider(),

          // Hiển thị danh sách kết quả
          Expanded(
            child: ListView.builder(
              itemCount: scannedList.length,
              itemBuilder: (context, index) {
                final item = scannedList[index];
                return ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(item.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('CCCD: ${item.idNumber}\nĐịa chỉ: ${item.address}'),
                  isThreeLine: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}