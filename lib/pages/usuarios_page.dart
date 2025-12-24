import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../services/api_service.dart';
import 'editar_usuario_page.dart';
import 'nuevo_usuario_page.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({Key? key}) : super(key: key);

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final Color primaryColor = Colors.green;
  List<dynamic> usuarios = [];
  List<dynamic> usuariosFiltrados = [];
  TextEditingController searchController = TextEditingController();
  bool isLoading = true;
  bool isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    if (!mounted) return;
    
    if (!isRefreshing) {
      setState(() => isLoading = true);
    }

    try {
      final lista = await ApiService().getUsuarios();
      if (!mounted) return;
      
      setState(() {
        usuarios = lista;
        usuariosFiltrados = lista;
        isLoading = false;
        isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        isLoading = false;
        isRefreshing = false;
      });
      
      _mostrarError('Error al cargar usuarios: ${e.toString()}');
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _filtrarUsuarios(String query) {
    final resultados = usuarios.where((usuario) {
      final nombre = usuario['nombre']?.toLowerCase() ?? '';
      final correo = usuario['correo']?.toLowerCase() ?? '';
      final sucursal = usuario['nombre_sucursal']?.toLowerCase() ?? '';
      return nombre.contains(query.toLowerCase()) ||
          correo.contains(query.toLowerCase()) ||
          sucursal.contains(query.toLowerCase());
    }).toList();

    setState(() => usuariosFiltrados = resultados);
  }

  String _formatearRol(int? idRol) {
    if (idRol == 1) return "Administrador";
    if (idRol == 2) return "Usuario";
    return "Sin rol";
  }

  Map<String, List<dynamic>> _agruparPorSucursal(List<dynamic> usuarios) {
    Map<String, List<dynamic>> agrupado = {};

    for (var usuario in usuarios) {
      String sucursal = usuario['nombre_sucursal'] ?? 'Sin Sucursal';
      if (!agrupado.containsKey(sucursal)) {
        agrupado[sucursal] = [];
      }
      agrupado[sucursal]!.add(usuario);
    }

    return Map.fromEntries(
      agrupado.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  Widget _buildUsuarioCard(dynamic usuario) {
    bool isActivo = usuario['id_estado'] == 1;
    String estado = isActivo ? "Activo" : "Inactivo";
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    
    return Card(
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: isActivo ? primaryColor.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre completo y estado
            Row(
              children: [
                Icon(Icons.person, color: primaryColor),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getNombreCompleto(usuario),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                      if (usuario['usuario'] != null)
                        Text(
                          '@${usuario['usuario']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withOpacity(0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActivo ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    estado,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.green, size: 28),
                  onPressed: () async {
                    final actualizado = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditarUsuarioPage(usuario: usuario),
                      ),
                    );
                    if (actualizado == true) {
                      _cargarUsuarios();
                    }
                  },
                  tooltip: 'Editar',
                ),
              ],
            ),
            Divider(height: 16, color: Colors.grey.withOpacity(0.3)),
            // Correo electrónico
            Row(
              children: [
                Icon(Icons.email, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    usuario['correo'] ?? 'No especificado',
                    style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.7)),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            // Rol y Perfil
            if (usuario['id_rol'] != null || usuario['id_perfil'] != null)
              Row(
                children: [
                  Icon(Icons.admin_panel_settings, color: Colors.purple, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getRolYPerfil(usuario),
                      style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.7)),
                    ),
                  ),
                ],
              ),
            if (usuario['id_rol'] != null || usuario['id_perfil'] != null)
              SizedBox(height: 8),
            // Sucursal asignada
            Row(
              children: [
                Icon(Icons.business, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    usuario['nombre_sucursal'] ?? 'Sin sucursal asignada',
                    style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.7)),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuariosAgrupados = _agruparPorSucursal(usuariosFiltrados);
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          "Usuarios",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() => isRefreshing = true);
              _cargarUsuarios();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarUsuarios,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: TextField(
                controller: searchController,
                onChanged: _filtrarUsuarios,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, correo o sucursal',
                  prefixIcon: Icon(Icons.search, color: primaryColor),
                  suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          _filtrarUsuarios('');
                        },
                      )
                    : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor),
                  ),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.05),
                ),
              ),
            ),
            Expanded(
              child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  )
                : usuariosAgrupados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "No hay usuarios disponibles",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      children: usuariosAgrupados.keys.map((sucursal) {
                        final cantidadUsuarios = usuariosAgrupados[sucursal]!.length;
                        return Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    sucursal,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: primaryColor.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '$cantidadUsuarios usuarios',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            initiallyExpanded: true,
                            children: usuariosAgrupados[sucursal]!
                              .map((usuario) => _buildUsuarioCard(usuario))
                              .toList(),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final creado = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NuevoUsuarioPage()),
          );
          if (creado == true) {
            _cargarUsuarios();
          }
        },
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: primaryColor,
      ),
    );
  }

  // Método auxiliar para obtener el nombre completo
  String _getNombreCompleto(dynamic usuario) {
    String nombre = usuario['nombre'] ?? '';
    String apellidoPaterno = usuario['apellido_paterno'] ?? '';
    String apellidoMaterno = usuario['apellido_materno'] ?? '';
    
    if (nombre.isEmpty && apellidoPaterno.isEmpty && apellidoMaterno.isEmpty) {
      return usuario['usuario'] ?? 'Sin nombre';
    }
    
    List<String> partes = [];
    if (nombre.isNotEmpty) partes.add(nombre);
    if (apellidoPaterno.isNotEmpty) partes.add(apellidoPaterno);
    if (apellidoMaterno.isNotEmpty) partes.add(apellidoMaterno);
    
    return partes.join(' ');
  }

  // Método auxiliar para obtener rol y perfil
  String _getRolYPerfil(dynamic usuario) {
    List<String> info = [];
    
    if (usuario['id_rol'] != null) {
      info.add('Rol: ${usuario['id_rol']}');
    }
    if (usuario['id_perfil'] != null) {
      info.add('Perfil: ${usuario['id_perfil']}');
    }
    
    return info.isEmpty ? 'Sin rol/perfil asignado' : info.join(' | ');
  }
}
