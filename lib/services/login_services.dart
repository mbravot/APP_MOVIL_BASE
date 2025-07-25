import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

// 🔧 Sistema de logging condicional
void logDebug(String message) {
  if (kDebugMode) {
    print(message);
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

class AuthService {
  //final String baseUrl = 'https://apilhtarja.lahornilla.cl/api';
  final String baseUrl = 'http://192.168.1.37:5000/api';

  Future<void> login(String usuario, String clave) async {
    try {
      logDebug("🔄 Intentando login con URL: $baseUrl/auth/login");
      logInfo("📤 Datos de login - Usuario: $usuario");

      final Map<String, String> body = {
        "usuario": usuario,
        "clave": clave,
      };

      logDebug("📦 Body de la petición: ${jsonEncode(body)}");

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(body),
      );

      logDebug("📡 Código de respuesta: ${response.statusCode}");
      logDebug("📝 Respuesta del servidor: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final token = data['access_token'];
        final refreshToken = data['refresh_token'];
        
        // Construir el nombre del usuario (solo nombre, sin apellidos)
        final nombre = data['nombre'] ?? '';
        final usuario = data['usuario'] ?? '';
        final nombreCompleto = nombre.trim().isNotEmpty ? nombre.trim() : usuario;
        
        // Debug: mostrar qué datos está devolviendo el backend
        logDebug("🔍 Datos del backend:");
        logDebug("  - nombre: '$nombre'");
        logDebug("  - nombreCompleto: '$nombreCompleto'");
        logDebug("  - Todos los datos: $data");
        
        final idSucursal = data['id_sucursal'];
        final nombreSucursal = data['sucursal_nombre'];
        final idRol = data['id_rol'];
        final idPerfil = data['id_perfil'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', token);
        if (refreshToken != null) {
          await prefs.setString('refresh_token', refreshToken);
        }
        await prefs.setString('user_name', nombreCompleto);
        await prefs.setString('id_sucursal', idSucursal.toString());
        await prefs.setString('user_sucursal', nombreSucursal);
        await prefs.setString('id_rol', idRol.toString());
        await prefs.setString('id_perfil', idPerfil.toString());

        logInfo(
            "✅ Login exitoso - Usuario: $nombreCompleto, Sucursal: $idSucursal ($nombreSucursal)");
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

      logDebug("🔄 Intentando refresh token...");

      final response = await http.post(
        Uri.parse("$baseUrl/auth/refresh"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $refreshToken",
        },
      );

      logDebug("📡 Código de respuesta refresh: ${response.statusCode}");
      logDebug("📝 Respuesta del servidor refresh: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Actualizar el token y otros datos si vienen en la respuesta
        await prefs.setString('access_token', data['access_token']);
        if (data['refresh_token'] != null) {
          await prefs.setString('refresh_token', data['refresh_token']);
        }
        if (data['nombre'] != null || data['usuario'] != null) {
          final nombre = data['nombre'] ?? '';
          final usuario = data['usuario'] ?? '';
          final nombreCompleto = nombre.trim().isNotEmpty ? nombre.trim() : usuario;
          await prefs.setString('user_name', nombreCompleto);
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

        logInfo("✅ Token refresh exitoso");
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
