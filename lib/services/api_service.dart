import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'login_services.dart';
import '../pages/login_page.dart';

// 🔧 Sistema de logging condicional
void logDebug(String message) {
  // Comentado para mejorar rendimiento
  // print("🔍 $message");
}

void logError(String message) {
  // Solo mostrar errores críticos en producción
  // if (kDebugMode) {
  //   print("❌ $message");
  // }
}

void logInfo(String message) {
  // Comentado para mejorar rendimiento
  // print("ℹ️ $message");
}

void logEndpoint(String method, String endpoint) {
  // Comentado para mejorar rendimiento
  // if (kDebugMode) {
  //   print("🌐 [$method] $endpoint");
  // }
}

class ApiService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  //final String baseUrl = 'https://apilhtarja-927498545444.us-central1.run.app/api';
  final String baseUrl = 'http://192.168.1.43:5000/api';

  /// 🔹 Método para manejar token expirado
  Future<void> manejarTokenExpirado() async {
    try {
      logDebug("🔄 Token expirado, limpiando datos y redirigiendo al login...");
      
      // Limpiar todas las preferencias almacenadas
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Mostrar mensaje de confirmación si hay contexto disponible
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sesión expirada. Por favor, inicia sesión nuevamente.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Navegar al login y limpiar el stack de navegación
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      logError('Error al manejar token expirado: $e');
      // Si hay algún error, intentar navegar al login de todas formas
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
      }
    }
  }

  /// 🔹 Método para verificar y manejar token expirado al inicio de la app
  Future<bool> verificarTokenAlInicio() async {
    try {
      final token = await getToken();
      if (token == null) {
        return false;
      }

      // Verificar si el token es válido haciendo una petición simple
      final response = await http.get(
        Uri.parse('$baseUrl/usuarios/sucursal-activa'),
        headers: await _getHeaders(),
      ).timeout(Duration(seconds: 10)); // Agregar timeout

      if (response.statusCode == 401) {
        // Token expirado, intentar refresh primero
        try {
          bool refreshed = await AuthService().refreshToken();
          if (refreshed) {
            return true; // Si el refresh fue exitoso, el token es válido
          } else {
            // Si el refresh falla, limpiar sesión
            await manejarTokenExpirado();
            return false;
          }
        } catch (refreshError) {
          // Si el refresh falla, limpiar sesión
          await manejarTokenExpirado();
          return false;
        }
      }

      return response.statusCode == 200;
    } catch (e) {
      logError('Error al verificar token al inicio: $e');
      
      // Si hay error de conexión o timeout, mantener la sesión
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('Network is unreachable') ||
          e.toString().contains('TimeoutException')) {
        return true; // Mantener la sesión si es error de red
      }
      
      // Para otros errores, intentar refresh del token
      try {
        bool refreshed = await AuthService().refreshToken();
        if (refreshed) {
          return true;
        } else {
          // Si el refresh falla, limpiar sesión
          await manejarTokenExpirado();
          return false;
        }
      } catch (refreshError) {
        // Si el refresh falla, limpiar sesión
        await manejarTokenExpirado();
        return false;
      }
    }
  }

  // Método para obtener el token almacenado en SharedPreferences
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token'); // Obtener el token almacenado correctamente
  }

  // Método para obtener el refresh token almacenado en SharedPreferences
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token'); // Obtener el refresh token almacenado
  }

  // ✅ Obtener headers con token
  Future<Map<String, String>> _getHeaders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      if (token == null) {
        logError("❌ No hay token de acceso");
        throw Exception('No hay token de acceso disponible');
      }

      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
    } catch (e) {
      logError("❌ Error al obtener headers: $e");
      throw Exception('Error al obtener headers: $e');
    }
  }

  Future<http.Response> _manejarRespuesta(http.Response response) async {
    // Manejar errores de token expirado
    if (response.statusCode == 401 || 
        (response.body.isNotEmpty && 
         (response.body.toLowerCase().contains('token has expired') ||
          response.body.toLowerCase().contains('token expired') ||
          response.body.toLowerCase().contains('unauthorized')))) {
      await manejarTokenExpirado();
      throw Exception('Sesión expirada. Por favor, inicia sesión nuevamente.');
    }
    return response;
  }

  /// 🔹 Método helper para hacer peticiones HTTP con manejo automático de tokens expirados
  Future<http.Response> _makeRequest(Future<http.Response> Function() requestFunction) async {
    try {
      final response = await requestFunction();
      
      // Log solo en caso de error para debugging
      
      // Si la respuesta es una redirección (3xx)
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          logDebug("🔄 Siguiendo redirección a: $redirectUrl");
          final redirectResponse = await http.get(
            Uri.parse(redirectUrl),
            headers: await _getHeaders(),
          );
          return await _manejarRespuesta(redirectResponse);
        }
      }
      
      // Si la respuesta es 401, intentar refresh del token
      if (response.statusCode == 401) {
        logDebug("🔄 Detectado error 401, intentando refresh del token...");
        bool refreshed = await AuthService().refreshToken();
        
        if (refreshed) {
          logDebug("✅ Token refresh exitoso, reintentando petición original...");
          // Reintentar la petición original con el nuevo token
          final retryResponse = await requestFunction();
          return await _manejarRespuesta(retryResponse);
        } else {
          // Si el refresh falla, manejar como token expirado
          await manejarTokenExpirado();
          throw Exception('Sesión expirada. Por favor, inicia sesión nuevamente.');
        }
      }

      // Verificar si la respuesta es HTML en lugar de JSON
      if (response.headers['content-type']?.toLowerCase().contains('text/html') == true) {
        logError("❌ Error: Respuesta HTML recibida cuando se esperaba JSON");
        throw Exception('Error de servidor: Se recibió HTML cuando se esperaba JSON');
      }
      
      return await _manejarRespuesta(response);
    } catch (e) {
      logError("❌ Error en _makeRequest: $e");
      
      // Si es un error de red o conexión, no manejar como token expirado
      if (e.toString().contains('Sesión expirada')) {
        rethrow;
      }
      
      // Verificar si es un error de conexión
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('Network is unreachable')) {
        throw Exception('Error de conexión. Verifica tu conexión a internet.');
      }
      
      throw Exception('Error de conexión: $e');
    }
  }

  /// 🔹 Método para verificar si el token está expirado
  Future<bool> verificarTokenValido() async {
    try {
      final response = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/usuarios/sucursal-activa'), // Usar endpoint que existe
          headers: await _getHeaders(),
        );
      });
      return response.statusCode == 200;
    } catch (e) {
      // Si hay cualquier error, asumir que el token no es válido
      return false;
    }
  }

  /// 🔹 Método para cerrar sesión manualmente
  Future<void> cerrarSesion() async {
    try {
      // Limpiar todas las preferencias almacenadas
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Esto incluye token, refresh_token, y todos los demás datos

      // Mostrar mensaje de confirmación si hay contexto disponible
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sesión cerrada exitosamente.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Navegar al login y limpiar el stack de navegación
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      logError('Error al cerrar sesión: $e');
      // Si hay algún error, intentar navegar al login de todas formas
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
      }
    }
  }

  /// 🔹 Método para reintentar la petición si el token expira
  Future<http.Response> _retryRequest(http.Request request) async {
    try {
      logDebug("🔄 Token expirado, intentando refresh...");
      bool refreshed = await AuthService().refreshToken();
      
      if (refreshed) {
        logDebug("✅ Token refresh exitoso, reintentando petición...");
        final newHeaders = await _getHeaders();
        request.headers.clear();
        request.headers.addAll(newHeaders);
        return await http.Response.fromStream(await request.send());
      } else {
        logError("❌ Falló el refresh del token");
        throw Exception('Sesión expirada, inicia sesión nuevamente.');
      }
    } catch (e) {
      logError("❌ Error en retry request: $e");
      throw Exception('Sesión expirada, inicia sesión nuevamente.');
    }
  }

  // 🔹 Obtener sucursal activa del usuario logueado
  Future<String?> getSucursalActiva() async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/usuarios/sucursal-activa'), // ← este es el correcto
        headers: await _getHeaders(),
      );
    });

            // logDebug("🔍 Respuesta API Sucursal Activa: ${response.statusCode} - ${response.body}");

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
              // logInfo("✅ Sucursal activa obtenida: ${data["sucursal_activa"]}");
      return data["sucursal_activa"].toString();
    } else {
      logError("❌ Error al obtener sucursal activa: ${response.body}");
      return null;
    }
  }

  Future<bool> actualizarSucursalActiva(String nuevaSucursalId) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/usuarios/sucursal-activa'),
        headers: await _getHeaders(),
        body: jsonEncode({"id_sucursal": nuevaSucursalId}),
      );
    });

    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> cambiarClave(
      String claveActual, String nuevaClave) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse("$baseUrl/auth/cambiar-clave"), // ✅ URL corregida
        headers: await _getHeaders(),
        body: jsonEncode({"clave_actual": claveActual, "nueva_clave": nuevaClave}),
      );
    });

    return jsonDecode(response.body);
  }

  // Método para obtener contratistas filtrados por sucursal
  Future<List<Map<String, dynamic>>> getContratistas(String idSucursal) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/opciones/contratistas?id_sucursal=$idSucursal'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Error al obtener los contratistas');
    }
  }

  /// 🔹 Obtener la lista de contratistas
  Future<List<Map<String, dynamic>>> getContratistasPorSucursal() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) throw Exception('No se encontró el token');

    final response = await http.get(
      Uri.parse('$baseUrl/contratistas'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Error al obtener los contratistas');
    }
  }

  /// 🔹 Crear un nuevo contratista
  Future<bool> crearContratista(Map<String, dynamic> contratistaData) async {
    try {
      final url = '$baseUrl/contratistas/';
      final response = await _makeRequest(() async {
        return await http.post(
          Uri.parse(url),
          headers: await _getHeaders(),
          body: jsonEncode(contratistaData),
        );
      });

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        // logInfo("✅ Contratista creado exitosamente: $responseData");
        return true;
      } else {
        logError("❌ Error al crear contratista: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      logError("❌ Error en crearContratista: $e");
      return false;
    }
  }

  /// Actualiza un contratista existente
  Future<Map<String, dynamic>> updateContratista(String id, Map<String, dynamic> contratistaData) async {
    final response = await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/contratistas/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(contratistaData),
      );
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      logError("❌ Error al actualizar contratista: ${response.statusCode} - ${response.body}");
      throw Exception('Error al actualizar el contratista: ${response.body}');
    }
  }

  /// Obtiene las sucursales disponibles
  Future<List<Map<String, dynamic>>> getSucursales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        throw Exception('No se encontró el token');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/opciones/sucursales'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

    if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Si el backend devuelve un array directamente (caso especial)
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        
        // Manejar tanto boolean como string para el campo success
        final success = data['success'];
        if (success == true || success == "true" || success == 1) {
          return List<Map<String, dynamic>>.from(data['sucursales'] ?? []);
        } else {
          throw Exception(data['error'] ?? 'Error al obtener las sucursales');
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al obtener las sucursales');
    }
    } catch (e) {
      logError('❌ Error al cargar sucursales disponibles: $e');
      throw Exception('Error al obtener las sucursales: $e');
    }
  }

  // Metodo para obtener usuarios
  Future<List<dynamic>> getUsuarios() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/usuarios/'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token", // Enviar token JWT en el header
      },
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Acceso no autorizado. Inicia sesión nuevamente.');
    } else {
      throw Exception('Error al obtener los usuarios');
    }
  }

  // Metodo para obtener roles
  Future<List<dynamic>> getRoles() async {
    logEndpoint("GET", "/opciones/roles");
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/opciones/roles'),
      headers: await _getHeaders(),
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al obtener roles');
    }
  }

  // Metodo para obtener perfiles
  Future<List<dynamic>> getPerfiles() async {
    logEndpoint("GET", "/opciones/perfiles");
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/opciones/perfiles'),
      headers: await _getHeaders(),
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al obtener perfiles');
    }
  }

  // Metodo para obtener estados
  Future<List<dynamic>> getEstados() async {
    logEndpoint("GET", "/opciones/estados");
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/opciones/estados'),
      headers: await _getHeaders(),
    );

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al obtener estados');
    }
  }

  Future<String?> crearUsuario({
    required String usuario,
    required String correo,
    required String clave,
    required int idSucursalActiva,
    String? idColaborador,
    String? nombre,
    String? apellidoPaterno,
    String? apellidoMaterno,
    int? idRol,
    int? idPerfil,
    int? idEstado,
  }) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No se encontró un token. Inicia sesión nuevamente.');
    }

    final Map<String, dynamic> userData = {
      'usuario': usuario,
      'correo': correo,
      'clave': clave,
      'id_sucursalactiva': idSucursalActiva,
    };

    if (idColaborador != null) {
      userData['id_colaborador'] = idColaborador;
    }

    if (nombre != null) {
      userData['nombre'] = nombre;
    }

    if (apellidoPaterno != null) {
      userData['apellido_paterno'] = apellidoPaterno;
    }

    if (apellidoMaterno != null) {
      userData['apellido_materno'] = apellidoMaterno;
    }

    if (idRol != null) {
      userData['id_rol'] = idRol;
    }

    if (idPerfil != null) {
      userData['id_perfil'] = idPerfil;
    }

    if (idEstado != null) {
      userData['id_estado'] = idEstado;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/usuarios/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(userData),
      );

      await _manejarRespuesta(response);

      if (response.statusCode == 201) {
        // Intentar obtener el ID del usuario creado de la respuesta
        try {
          final responseData = jsonDecode(response.body);
          if (responseData is Map<String, dynamic> && responseData.containsKey('id')) {
            return responseData['id'].toString();
          }
        } catch (e) {
          logError('No se pudo obtener el ID del usuario creado: $e');
        }
        return null; // Si no se puede obtener el ID, retornar null
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Error al crear el usuario');
      }
    } catch (e) {
      logError("❌ Error al crear usuario: $e");
      rethrow;
    }
  }

  Future<bool> editarUsuario(String id, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final response = await http.put(
      Uri.parse('$baseUrl/usuarios/$id'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
              // logInfo("✅ Usuario editado correctamente");
      return true;
    } else {
      logError("❌ Error al editar usuario: ${response.body}");
      return false;
    }
  }

  /// 🔹 Obtener porcentajes de contratista
  Future<List<Map<String, dynamic>>> getPorcentajesContratista() async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/opciones/porcentajes-contratista'),
        headers: await _getHeaders(),
      );
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return List<Map<String, dynamic>>.from(data['porcentajes'] ?? []);
    } else {
      logError("❌ Error al obtener porcentajes: ${response.body}");
      throw Exception('Error al obtener los porcentajes de contratista');
    }
  }

  /// 🔹 Obtener trabajadores por sucursal
  Future<List<dynamic>> getTrabajadoresPorSucursal() async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/trabajadores'),
        headers: await _getHeaders(),
      );
    });

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      logError("❌ Error al obtener trabajadores: ${response.body}");
      throw Exception('Error al obtener los trabajadores');
    }
  }

  /// 🔹 Crear trabajador
  Future<bool> crearTrabajador(Map<String, dynamic> data) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/trabajadores/'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
    });

    if (response.statusCode == 201 || response.statusCode == 200) {
      return true;
    } else {
      logError("❌ Error al crear trabajador: ${response.statusCode} - ${response.body}");
      return false;
    }
  }

  /// 🔹 Editar trabajador
  Future<bool> editarTrabajador(String id, Map<String, dynamic> data) async {
    final response = await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/trabajadores/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
    });

    if (response.statusCode == 200) {
      return true;
    } else {
      logError("❌ Error al editar trabajador: ${response.statusCode} - ${response.body}");
      return false;
    }
  }

  /// 🔹 Obtener colaboradores
  Future<List<Map<String, dynamic>>> getColaboradores() async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/colaboradores'),
        headers: await _getHeaders(),
      );
    });

    await _manejarRespuesta(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return List<Map<String, dynamic>>.from(data['colaboradores'] ?? []);
    } else {
      logError("❌ Error al obtener colaboradores: ${response.body}");
      throw Exception('Error al obtener los colaboradores');
    }
  }

  /// 🔹 Crear colaborador
  Future<bool> crearColaborador(Map<String, dynamic> data) async {
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/colaboradores/'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
    });

    if (response.statusCode == 201 || response.statusCode == 200) {
      return true;
    } else {
      logError("❌ Error al crear colaborador: ${response.statusCode} - ${response.body}");
      return false;
    }
  }

  /// 🔹 Editar colaborador
  Future<bool> editarColaborador(String id, Map<String, dynamic> data) async {
    final response = await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/colaboradores/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
    });

    if (response.statusCode == 200) {
      return true;
    } else {
      logError("❌ Error al editar colaborador: ${response.statusCode} - ${response.body}");
      return false;
    }
  }

  /// 🔹 Obtener sucursales para usuarios
  Future<List<Map<String, dynamic>>> getSucursalesUsuarios() async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/opciones/sucursales-usuarios'),
        headers: await _getHeaders(),
      );
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return List<Map<String, dynamic>>.from(data['sucursales'] ?? []);
    } else {
      logError("❌ Error al obtener sucursales de usuarios: ${response.body}");
      throw Exception('Error al obtener las sucursales de usuarios');
    }
  }

  /// 🔹 Obtener aplicaciones
  Future<List<Map<String, dynamic>>> getAplicaciones() async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/opciones/aplicaciones'),
        headers: await _getHeaders(),
      );
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return List<Map<String, dynamic>>.from(data['aplicaciones'] ?? []);
    } else {
      logError("❌ Error al obtener aplicaciones: ${response.body}");
      throw Exception('Error al obtener las aplicaciones');
    }
  }

  /// 🔹 Obtener sucursales permitidas de un usuario
  Future<List<Map<String, dynamic>>> getSucursalesPermitidasUsuario(String usuarioId) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/usuarios/$usuarioId/sucursales-permitidas'),
        headers: await _getHeaders(),
      );
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return List<Map<String, dynamic>>.from(data['sucursales'] ?? []);
    } else {
      logError("❌ Error al obtener sucursales permitidas: ${response.body}");
      return [];
    }
  }

  /// 🔹 Obtener aplicaciones permitidas de un usuario
  Future<List<Map<String, dynamic>>> getAplicacionesPermitidasUsuario(String usuarioId) async {
    final response = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/usuarios/$usuarioId/aplicaciones-permitidas'),
        headers: await _getHeaders(),
      );
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return List<Map<String, dynamic>>.from(data['aplicaciones'] ?? []);
    } else {
      logError("❌ Error al obtener aplicaciones permitidas: ${response.body}");
      return [];
    }
  }

  /// 🔹 Asignar sucursales permitidas a un usuario
  Future<bool> asignarSucursalesPermitidas(String usuarioId, List<dynamic> sucursalesIds) async {
    // Convertir todos los IDs a String
    final sucursalesIdsString = sucursalesIds.map((id) => id.toString()).toList();
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/usuarios/$usuarioId/sucursales-permitidas'),
        headers: await _getHeaders(),
        body: jsonEncode({'sucursales_ids': sucursalesIdsString}),
      );
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      return true;
    } else {
      logError("❌ Error al asignar sucursales permitidas: ${response.statusCode} - ${response.body}");
      return false;
    }
  }

  /// 🔹 Eliminar sucursales permitidas de un usuario
  Future<bool> eliminarSucursalesPermitidas(String usuarioId) async {
    final response = await _makeRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/usuarios/$usuarioId/sucursales-permitidas'),
        headers: await _getHeaders(),
      );
    });

    if (response.statusCode == 200 || response.statusCode == 204) {
      return true;
    } else {
      logError("❌ Error al eliminar sucursales permitidas: ${response.statusCode} - ${response.body}");
      return false;
    }
  }

  /// 🔹 Asignar aplicaciones permitidas a un usuario
  Future<bool> asignarAplicacionesPermitidas(String usuarioId, List<dynamic> aplicacionesIds) async {
    // Convertir todos los IDs a String
    final aplicacionesIdsString = aplicacionesIds.map((id) => id.toString()).toList();
    final response = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/usuarios/$usuarioId/aplicaciones-permitidas'),
        headers: await _getHeaders(),
        body: jsonEncode({'aplicaciones_ids': aplicacionesIdsString}),
      );
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      return true;
    } else {
      logError("❌ Error al asignar aplicaciones permitidas: ${response.statusCode} - ${response.body}");
      return false;
    }
  }

  /// 🔹 Eliminar aplicaciones permitidas de un usuario
  Future<bool> eliminarAplicacionesPermitidas(String usuarioId) async {
    final response = await _makeRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/usuarios/$usuarioId/aplicaciones-permitidas'),
        headers: await _getHeaders(),
      );
    });

    if (response.statusCode == 200 || response.statusCode == 204) {
      return true;
    } else {
      logError("❌ Error al eliminar aplicaciones permitidas: ${response.statusCode} - ${response.body}");
      return false;
    }
  }

 


}
