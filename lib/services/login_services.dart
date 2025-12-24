import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

// 🔧 Sistema de logging condicional
void logDebug(String message) {
  if (kDebugMode) {
    print("🔍 $message");
  }
}

void logError(String message) {
  if (kDebugMode) {
    print("❌ $message");
  }
}

void logInfo(String message) {
  if (kDebugMode) {
    print("ℹ️ $message");
  }
}

void logEndpoint(String method, String endpoint) {
  if (kDebugMode) {
    print("🌐 [$method] $endpoint");
  }
}

class AuthService {
  //final String baseUrl = 'https://apilhtarja-927498545444.us-central1.run.app/api';
  final String baseUrl = 'http://192.168.1.43:5000/api';

  Future<void> login(String usuario, String clave) async {
    try {
      logEndpoint("POST", "/auth/login");
      final Map<String, String> body = {
        "usuario": usuario,
        "clave": clave,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final token = data['access_token'];
        final refreshToken = data['refresh_token'];
        final nombreUsuario = data['nombre'] ?? data['usuario']; // Usar nombre si está disponible, sino usuario
        final idSucursal = data['id_sucursal'];
        final nombreSucursal = data['sucursal_nombre'];
        final idRol = data['id_rol'];
        final idPerfil = data['id_perfil'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', token);
        if (refreshToken != null) {
          await prefs.setString('refresh_token', refreshToken);
        }
        await prefs.setString('user_name', nombreUsuario);
        await prefs.setString('id_sucursal', idSucursal.toString());
        await prefs.setString('user_sucursal', nombreSucursal);
        await prefs.setString('id_rol', idRol.toString());
        await prefs.setString('id_perfil', idPerfil.toString());

        // logInfo("✅ Login exitoso - Usuario: $nombreUsuario, Sucursal: $idSucursal ($nombreSucursal)");
      } else {
        logError("❌ Error en login - Código: ${response.statusCode}");
        logError("❌ Detalle del error: ${response.body}");
        
        // Extraer el mensaje de error del JSON
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ?? 'Error desconocido';
        throw Exception(errorMessage);
      }
    } catch (e) {
      logError("🚨 Error de conexión: $e");
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// 🔥 Método para renovar el token si expira
  Future<bool> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? refreshToken = prefs.getString('refresh_token');

      if (refreshToken == null) {
        logError("❌ No hay refresh token para refresh");
        return false;
      }

      // Intentando refresh token...
      logEndpoint("POST", "/auth/refresh");

      final response = await http.post(
        Uri.parse("$baseUrl/auth/refresh"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $refreshToken",
        },
      );

      // Log solo en caso de error para debugging

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Actualizar el token y otros datos si vienen en la respuesta
        await prefs.setString('access_token', data['access_token']);
        if (data['refresh_token'] != null) {
          await prefs.setString('refresh_token', data['refresh_token']);
        }
        if (data['nombre'] != null) {
          await prefs.setString('user_name', data['nombre']);
        } else if (data['usuario'] != null) {
          await prefs.setString('user_name', data['usuario']);
        }
        if (data['id_sucursal'] != null) {
          await prefs.setString('id_sucursal', data['id_sucursal'].toString());
        }
        if (data['sucursal_nombre'] != null) {
          await prefs.setString('user_sucursal', data['sucursal_nombre']);
        }
        if (data['id_rol'] != null) {
          await prefs.setString('id_rol', data['id_rol'].toString());
        }
        if (data['id_perfil'] != null) {
          await prefs.setString('id_perfil', data['id_perfil'].toString());
        }

        // logInfo("✅ Token refresh exitoso");
        return true;
      } else {
        logError("❌ Error en refresh token - Código: ${response.statusCode}");
        logError("❌ Detalle del error refresh: ${response.body}");
        return false;
      }
    } catch (e) {
      logError("🚨 Error de conexión en refresh: $e");
      return false;
    }
  }
}
