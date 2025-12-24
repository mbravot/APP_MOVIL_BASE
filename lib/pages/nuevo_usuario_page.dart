import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:app_lh_tarja/utils/colors.dart';
import 'package:app_lh_tarja/pages/usuarios_page.dart';

// Sistema de logging condicional
void logInfo(String message) {
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    print("ℹ️ $message");
  }
}

void logError(String message) {
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    print("❌ $message");
  }
}

class NuevoUsuarioPage extends StatefulWidget {
  @override
  _NuevoUsuarioPageState createState() => _NuevoUsuarioPageState();
}

class _NuevoUsuarioPageState extends State<NuevoUsuarioPage> {
  final _formKey = GlobalKey<FormState>();
  final usuarioController = TextEditingController();
  final correoController = TextEditingController();
  final claveController = TextEditingController();
  final nombreController = TextEditingController();
  final apellidoPaternoController = TextEditingController();
  final apellidoMaternoController = TextEditingController();
  final Color primaryColor = Colors.green;

  List<Map<String, dynamic>> sucursales = [];
  List<Map<String, dynamic>> roles = [];
  List<Map<String, dynamic>> perfiles = [];
  List<Map<String, dynamic>> estados = [];
  
  String? selectedSucursal;
  String? selectedRol;
  String? selectedPerfil;
  String? selectedEstado;
  
  bool _guardando = false;
  bool _ocultarClave = true;
  
  // Variables para funcionalidad de sucursales y aplicaciones
  List<Map<String, dynamic>> aplicaciones = [];
  List<int> sucursalesPermitidasSeleccionadas = [];
  List<int> aplicacionesPermitidasSeleccionadas = [];

  @override
  void initState() {
    super.initState();
    // Establecer valores por defecto según cambios del backend
    selectedRol = '3'; // Rol por defecto (usuario común)
    selectedPerfil = '1'; // Perfil por defecto
    selectedEstado = '1'; // Estado por defecto (activo)
    
    _cargarSucursales();
    _cargarRoles();
    _cargarPerfiles();
    _cargarEstados();
    _cargarAplicaciones();
  }

  Future<void> _cargarSucursales() async {
    try {
      final lista = await ApiService().getSucursalesUsuarios();
      setState(() => sucursales = lista);
    } catch (e) {
      _mostrarError('Error al cargar sucursales: ${e.toString()}');
    }
  }

  Future<void> _cargarRoles() async {
    try {
      final lista = await ApiService().getRoles();
      if (mounted) {
        setState(() => roles = List<Map<String, dynamic>>.from(lista));
      }
    } catch (e) {
      if (mounted) {
        _mostrarError('Error al cargar roles: ${e.toString()}');
      }
    }
  }

  Future<void> _cargarPerfiles() async {
    try {
      final lista = await ApiService().getPerfiles();
      setState(() => perfiles = List<Map<String, dynamic>>.from(lista));
    } catch (e) {
      _mostrarError('Error al cargar perfiles: ${e.toString()}');
    }
  }

  Future<void> _cargarEstados() async {
    try {
      final lista = await ApiService().getEstados();
      if (mounted) {
        setState(() => estados = List<Map<String, dynamic>>.from(lista));
      }
    } catch (e) {
      if (mounted) {
        _mostrarError('Error al cargar estados: ${e.toString()}');
      }
    }
  }


  Future<void> _cargarAplicaciones() async {
    try {
      final lista = await ApiService().getAplicaciones();
      setState(() => aplicaciones = List<Map<String, dynamic>>.from(lista));
    } catch (e) {
      _mostrarError('Error al cargar aplicaciones: ${e.toString()}');
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

  Future<void> _guardarUsuario() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _guardando = true);

    try {
      final usuarioId = await ApiService().crearUsuario(
        usuario: usuarioController.text.trim(),
        correo: correoController.text.trim(),
        clave: claveController.text,
        idSucursalActiva: int.parse(selectedSucursal!),
        nombre: nombreController.text.trim().isNotEmpty ? nombreController.text.trim() : null,
        apellidoPaterno: apellidoPaternoController.text.trim().isNotEmpty ? apellidoPaternoController.text.trim() : null,
        apellidoMaterno: apellidoMaternoController.text.trim().isNotEmpty ? apellidoMaternoController.text.trim() : null,
        idRol: selectedRol != null ? int.parse(selectedRol!) : 3, // Valor por defecto: rol 3
        idPerfil: selectedPerfil != null ? int.parse(selectedPerfil!) : 1, // Valor por defecto: perfil 1
        idEstado: selectedEstado != null ? int.parse(selectedEstado!) : 1, // Valor por defecto: estado 1
      );

      if (usuarioId != null) {
        // Si se seleccionaron sucursales permitidas, asignarlas al usuario
        if (sucursalesPermitidasSeleccionadas.isNotEmpty) {
          try {
            await ApiService().asignarSucursalesPermitidas(
              usuarioId,
              sucursalesPermitidasSeleccionadas,
            );
          } catch (e) {
            logInfo('Error al asignar sucursales permitidas: $e');
            // No mostrar error al usuario, ya que el usuario se creó correctamente
          }
        }

        // Si se seleccionaron aplicaciones permitidas, asignarlas al usuario
        if (aplicacionesPermitidasSeleccionadas.isNotEmpty) {
          try {
            await ApiService().asignarAplicacionesPermitidas(
              usuarioId,
              aplicacionesPermitidasSeleccionadas,
            );
          } catch (e) {
            logInfo('Error al asignar aplicaciones permitidas: $e');
            // No mostrar error al usuario, ya que el usuario se creó correctamente
          }
        }
        
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        _mostrarError('Error al crear el usuario: No se pudo obtener el ID del usuario creado');
      }
    } catch (e) {
      _mostrarError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Nuevo Usuario",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Colors.green.withOpacity(0.1),
              ],
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Campo de usuario
                          TextFormField(
                    controller: usuarioController,
                            decoration: InputDecoration(
                      labelText: "Nombre de Usuario",
                      prefixIcon: Icon(Icons.person, color: primaryColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: primaryColor),
                              ),
                            ),
                            validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese un nombre de usuario';
                              }
                              return null;
                            },
                          ),
                  SizedBox(height: 20),
                  // Campo de correo
                          TextFormField(
                            controller: correoController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                      labelText: "Correo Electrónico",
                      prefixIcon: Icon(Icons.email, color: primaryColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: primaryColor),
                              ),
                            ),
                            validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese un correo electrónico';
                              }
                      if (!value.contains('@')) {
                        return 'Por favor ingrese un correo electrónico válido';
                              }
                              return null;
                            },
                          ),
                  SizedBox(height: 20),
                  // Campo de contraseña
                          TextFormField(
                            controller: claveController,
                            obscureText: _ocultarClave,
                            decoration: InputDecoration(
                      labelText: "Contraseña",
                      prefixIcon: Icon(Icons.lock, color: primaryColor),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _ocultarClave ? Icons.visibility : Icons.visibility_off,
                                  color: primaryColor,
                                ),
                        onPressed: () {
                          setState(() => _ocultarClave = !_ocultarClave);
                        },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: primaryColor),
                              ),
                            ),
                            validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingrese una contraseña';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 20),
                  // Campo de nombre
                  TextFormField(
                    controller: nombreController,
                    decoration: InputDecoration(
                      labelText: "Nombre",
                      prefixIcon: Icon(Icons.badge, color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Campo de apellido paterno
                  TextFormField(
                    controller: apellidoPaternoController,
                    decoration: InputDecoration(
                      labelText: "Apellido Paterno",
                      prefixIcon: Icon(Icons.badge, color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Campo de apellido materno
                  TextFormField(
                    controller: apellidoMaternoController,
                    decoration: InputDecoration(
                      labelText: "Apellido Materno",
                      prefixIcon: Icon(Icons.badge, color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Selector de sucursal
                          DropdownSearch<String>(
                            popupProps: PopupProps.menu(
                              fit: FlexFit.loose,
                              menuProps: MenuProps(
                                backgroundColor: Colors.white,
                                elevation: 2,
                              ),
                              showSelectedItems: true,
                            ),
                    items: sucursales.map((s) => s['nombre'].toString()).toList(),
                            dropdownDecoratorProps: DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                labelText: "Sucursal",
                                prefixIcon: Icon(Icons.business, color: primaryColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: primaryColor),
                                ),
                              ),
                            ),
                            onChanged: (String? value) {
                              if (value != null) {
                                final sucursal = sucursales.firstWhere(
                                  (s) => s['nombre'] == value,
                                  orElse: () => {'id': null},
                                );
                                setState(() => selectedSucursal = sucursal['id']?.toString());
                              }
                            },
                            selectedItem: selectedSucursal != null
                                ? sucursales
                                    .firstWhere(
                                      (s) => s['id'].toString() == selectedSucursal,
                                      orElse: () => {'nombre': ''},
                                    )['nombre']
                                : null,
                            validator: (value) =>
                        value == null ? 'Por favor seleccione una sucursal' : null,
                          ),
                          SizedBox(height: 20),
                  // Selector de rol - OCULTO (valor por defecto: rol 3)
                  // DropdownSearch<String>(
                  //   popupProps: PopupProps.menu(
                  //     fit: FlexFit.loose,
                  //     menuProps: MenuProps(
                  //       backgroundColor: Colors.white,
                  //       elevation: 2,
                  //     ),
                  //     showSelectedItems: true,
                  //   ),
                  //   items: roles.map((r) => r['nombre'].toString()).toList(),
                  //   dropdownDecoratorProps: DropDownDecoratorProps(
                  //     dropdownSearchDecoration: InputDecoration(
                  //       labelText: "Rol",
                  //       prefixIcon: Icon(Icons.admin_panel_settings, color: primaryColor),
                  //       border: OutlineInputBorder(
                  //         borderRadius: BorderRadius.circular(12),
                  //       ),
                  //       enabledBorder: OutlineInputBorder(
                  //         borderRadius: BorderRadius.circular(12),
                  //         borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  //       ),
                  //       focusedBorder: OutlineInputBorder(
                  //         borderRadius: BorderRadius.circular(12),
                  //         borderSide: BorderSide(color: primaryColor),
                  //       ),
                  //     ),
                  //   ),
                  //   onChanged: (String? value) {
                  //     if (value != null) {
                  //       final rol = roles.firstWhere((r) => r['nombre'] == value);
                  //       selectedRol = rol['id'].toString();
                  //     } else {
                  //       selectedRol = null;
                  //     }
                  //   },
                  //   // No es obligatorio, tiene valor por defecto
                  // ),
                  SizedBox(height: 20),
                  // Selector de perfil - OCULTO (valor por defecto: perfil 1 - LECTOR)
                  // DropdownSearch<String>(
                  //   popupProps: PopupProps.menu(
                  //     fit: FlexFit.loose,
                  //     menuProps: MenuProps(
                  //       backgroundColor: Colors.white,
                  //       elevation: 2,
                  //     ),
                  //     showSelectedItems: true,
                  //   ),
                  //   items: perfiles.map((p) => p['nombre'].toString()).toList(),
                  //   dropdownDecoratorProps: DropDownDecoratorProps(
                  //     dropdownSearchDecoration: InputDecoration(
                  //       labelText: "Perfil",
                  //       prefixIcon: Icon(Icons.person_pin, color: primaryColor),
                  //       border: OutlineInputBorder(
                  //         borderRadius: BorderRadius.circular(12),
                  //       ),
                  //       enabledBorder: OutlineInputBorder(
                  //         borderRadius: BorderRadius.circular(12),
                  //         borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  //       ),
                  //       focusedBorder: OutlineInputBorder(
                  //         borderRadius: BorderRadius.circular(12),
                  //         borderSide: BorderSide(color: primaryColor),
                  //       ),
                  //     ),
                  //   ),
                  //   onChanged: (String? value) {
                  //     if (value != null) {
                  //       final perfil = perfiles.firstWhere((p) => p['nombre'] == value);
                  //       selectedPerfil = perfil['id'].toString();
                  //     } else {
                  //       selectedPerfil = null;
                  //     }
                  //   },
                  //   // No es obligatorio, tiene valor por defecto
                  // ),
                  SizedBox(height: 20),
                  // Selector de estado - OCULTO (valor por defecto: estado 1)
                  // DropdownSearch<String>(
                  //   popupProps: PopupProps.menu(
                  //     fit: FlexFit.loose,
                  //     menuProps: MenuProps(
                  //       backgroundColor: Colors.white,
                  //       elevation: 2,
                  //     ),
                  //     showSelectedItems: true,
                  //   ),
                  //   items: estados.map((e) => e['nombre'].toString()).toList(),
                  //   dropdownDecoratorProps: DropDownDecoratorProps(
                  //     dropdownSearchDecoration: InputDecoration(
                  //       labelText: "Estado",
                  //       prefixIcon: Icon(Icons.check_circle, color: primaryColor),
                  //       border: OutlineInputBorder(
                  //         borderRadius: BorderRadius.circular(12),
                  //       ),
                  //       enabledBorder: OutlineInputBorder(
                  //         borderRadius: BorderRadius.circular(12),
                  //         borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  //       ),
                  //       focusedBorder: OutlineInputBorder(
                  //         borderRadius: BorderRadius.circular(12),
                  //         borderSide: BorderSide(color: primaryColor),
                  //       ),
                  //     ),
                  //   ),
                  //   onChanged: (String? value) {
                  //     if (value != null) {
                  //       final estado = estados.firstWhere((e) => e['nombre'] == value);
                  //       selectedEstado = estado['id'].toString();
                  //     } else {
                  //       selectedEstado = null;
                  //     }
                  //   },
                  //   // No es obligatorio, tiene valor por defecto
                  // ),
                  SizedBox(height: 20),
                  // Funcionalidad de colaborador eliminada
                  SizedBox(height: 30),
                  
                  // Sección de Sucursales Permitidas
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, color: primaryColor),
                              SizedBox(width: 8),
                              Text(
                                'Sucursales Permitidas',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Selecciona las sucursales a las que este usuario tendrá acceso:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          // Lista de sucursales con checkboxes
                          Container(
                            constraints: BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: sucursales.length,
                              itemBuilder: (context, index) {
                                final sucursal = sucursales[index];
                                final sucursalId = sucursal['id'] as int;
                                final isSelected = sucursalesPermitidasSeleccionadas.contains(sucursalId);
                                
                                return CheckboxListTile(
                                  title: Text(
                                    sucursal['nombre'],
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(
                                    sucursal['ubicacion'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  value: isSelected,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      if (value == true) {
                                        sucursalesPermitidasSeleccionadas.add(sucursalId);
                                      } else {
                                        sucursalesPermitidasSeleccionadas.remove(sucursalId);
                                      }
                                    });
                                  },
                                  activeColor: primaryColor,
                                  checkColor: Colors.white,
                                  controlAffinity: ListTileControlAffinity.leading,
                                );
                              },
                            ),
                          ),
                          
                          // Botones de acción para sucursales permitidas
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      sucursalesPermitidasSeleccionadas.clear();
                                    });
                                  },
                                  icon: Icon(Icons.clear, color: primaryColor),
                                  label: Text(
                                    'Limpiar',
                                    style: TextStyle(color: primaryColor),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: primaryColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      sucursalesPermitidasSeleccionadas = sucursales
                                          .map((s) => s['id'] as int)
                                          .toList();
                                    });
                                  },
                                  icon: Icon(Icons.select_all, color: primaryColor),
                                  label: Text(
                                    'Seleccionar Todas',
                                    style: TextStyle(color: primaryColor),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: primaryColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 30),
                  
                  // Sección de Aplicaciones Permitidas
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.apps, color: primaryColor),
                              SizedBox(width: 8),
                              Text(
                                'Aplicaciones Permitidas',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Selecciona las aplicaciones a las que este usuario tendrá acceso:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          // Lista de aplicaciones con checkboxes
                          Container(
                            constraints: BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: aplicaciones.length,
                              itemBuilder: (context, index) {
                                final aplicacion = aplicaciones[index];
                                final aplicacionId = aplicacion['id'] as int;
                                final isSelected = aplicacionesPermitidasSeleccionadas.contains(aplicacionId);
                                
                                return CheckboxListTile(
                                  title: Text(
                                    aplicacion['nombre'],
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  value: isSelected,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      if (value == true) {
                                        aplicacionesPermitidasSeleccionadas.add(aplicacionId);
                                      } else {
                                        aplicacionesPermitidasSeleccionadas.remove(aplicacionId);
                                      }
                                    });
                                  },
                                  activeColor: primaryColor,
                                  checkColor: Colors.white,
                                  controlAffinity: ListTileControlAffinity.leading,
                                );
                              },
                            ),
                          ),
                          
                          // Botones de acción para aplicaciones permitidas
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      aplicacionesPermitidasSeleccionadas.clear();
                                    });
                                  },
                                  icon: Icon(Icons.clear, color: primaryColor),
                                  label: Text(
                                    'Limpiar',
                                    style: TextStyle(color: primaryColor),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: primaryColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      aplicacionesPermitidasSeleccionadas = aplicaciones
                                          .map((a) => a['id'] as int)
                                          .toList();
                                    });
                                  },
                                  icon: Icon(Icons.select_all, color: primaryColor),
                                  label: Text(
                                    'Seleccionar Todas',
                                    style: TextStyle(color: primaryColor),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: primaryColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 30),
                  // Botón de guardar
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor,
                          primaryColor.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _guardarUsuario,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _guardando
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save),
                                SizedBox(width: 8),
                                Text(
                                  'Crear Usuario',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
