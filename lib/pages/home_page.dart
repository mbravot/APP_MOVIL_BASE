import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'contratistas_page.dart';
import 'trabajadores_page.dart';
import 'colaboradores_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'cambiar_clave_page.dart';
import 'cambiar_sucursal_page.dart';
import '../widgets/layout/app_bar.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';
import 'usuarios_page.dart';
import 'info_page.dart';
import '../widgets/token_checker.dart';

// 🔧 Sistema de logging condicional
void logDebug(String message) {
  // Comentado para mejorar rendimiento
  // if (kDebugMode) {
  //   print(message);
  // }
}



void logInfo(String message) {
  // Comentado para mejorar rendimiento
  // if (kDebugMode) {
  //   print("ℹ️ $message");
  // }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  String userName = "Usuario";
  String userSucursal = "Sucursal";
  bool _isLoading = false;
  late AnimationController _animationController;
  
  Key _actividadesKey = UniqueKey();
  Key _rendimientosKey = UniqueKey();
  Key _indicadoresKey = UniqueKey();
  List<Map<String, dynamic>> _sucursalesDisponibles = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _cargarNombreUsuario();
    _cargarSucursalesDisponibles(); // Comentado temporalmente para evitar crash
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _forzarRecargaPantallas() {
    setState(() {
      _actividadesKey = UniqueKey();
      _rendimientosKey = UniqueKey();
      _indicadoresKey = UniqueKey();
    });
  }

  Future<void> _cargarNombreUsuario() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        userName = prefs.getString('user_name') ?? "Usuario";
        userSucursal = prefs.getString('user_sucursal') ?? "Sucursal";
        _isLoading = false;
      });
      // logInfo("🏠 Sucursal activa cargada: $userSucursal");
      _forzarRecargaPantallas();
    } catch (e) {
      print("❌ Error cargando datos de usuario: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarSucursalesDisponibles() async {
    try {
      final sucursales = await ApiService().getSucursales();
      setState(() {
        _sucursalesDisponibles = sucursales;
      });
    } catch (e) {
      print("❌ Error al cargar sucursales disponibles: $e");
      // Si no se pueden cargar las sucursales, la app sigue funcionando
      setState(() {
        _sucursalesDisponibles = [];
      });
    }
  }

  Future<void> _seleccionarSucursal(BuildContext context) async {
    final seleccion = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Selecciona una sucursal'),
          content: Container(
            width: double.maxFinite,
            child: _sucursalesDisponibles.isEmpty
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _sucursalesDisponibles.length,
                    itemBuilder: (context, index) {
                      final suc = _sucursalesDisponibles[index];
                      return ListTile(
                        leading: Icon(Icons.location_on, color: Colors.green),
                        title: Text(suc['nombre']),
                        selected: suc['nombre'] == userSucursal,
                        onTap: () => Navigator.pop(context, suc),
                      );
                    },
                  ),
          ),
        );
      },
    );
    
    if (seleccion != null && seleccion['nombre'] != userSucursal) {
      // Actualizar en backend
      final exito = await ApiService().actualizarSucursalActiva(seleccion['id'].toString());
      if (exito) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('id_sucursal', seleccion['id'].toString());
        await prefs.setString('user_sucursal', seleccion['nombre']);
        setState(() {
          userSucursal = seleccion['nombre'];
        });
        _forzarRecargaPantallas();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Sucursal cambiada a ${seleccion['nombre']}'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Recargar la sucursal activa en el AppBar
        await _recargarPagina();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('No se pudo actualizar la sucursal en el servidor'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _recargarPagina() async {
    _animationController.forward(from: 0);
    await _cargarNombreUsuario();
  }

  Future<void> _cerrarSesion() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 10),
              Text("Cerrar Sesión"),
            ],
          ),
          content: Text("¿Está seguro que desea cerrar sesión?"),
          actions: [
            TextButton(
              child: Text("Cancelar"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text("Cerrar Sesión"),
              onPressed: () async {
                Navigator.of(context).pop(); // Cerrar el diálogo
                setState(() => _isLoading = true);
                
                try {
                  // Limpiar preferencias localmente primero
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  
                  // Mostrar mensaje de confirmación
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sesión cerrada exitosamente.'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                  
                  // Navegar al login y limpiar el stack de navegación
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context, 
                      MaterialPageRoute(builder: (context) => LoginPage()),
                      (route) => false
                    );
                  }
                } catch (e) {
                  print('Error al cerrar sesión: $e');
                  // Si hay error, intentar cerrar sesión manualmente
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context, 
                      MaterialPageRoute(builder: (context) => LoginPage()),
                      (route) => false
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String titulo = (_selectedIndex == 0) ? "Actividades" : "Indicadores";

    return TokenChecker(
      child: Stack(
        children: [
          Scaffold(
            appBar: CustomAppBar(
              title: titulo,
              actions: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            userName,
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _seleccionarSucursal(context),
                        child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on, color: Colors.white70, size: 14),
                          SizedBox(width: 4),
                          Text(
                            userSucursal,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                          ),
                            Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                        ],
                        ),
                      ),
                    ],
                  ),
                ),
                RotationTransition(
                  turns: Tween(begin: 0.0, end: 1.0).animate(_animationController),
                  child: IconButton(
                    icon: Icon(Icons.refresh, color: Colors.white),
                    onPressed: () async {
                      await _recargarPagina();
                      await _cargarSucursalesDisponibles();
                    },
                  ),
                ),
              ],
            ),
            drawer: _buildDrawer(),
            body: Column(
              children: [
                Expanded(
                  child: _selectedIndex == 0
                      ? _ActividadesPage(
                          key: _actividadesKey,
                        )
                      : _IndicadoresPage(
                          key: _indicadoresKey,
                        ),
                ),
              ],
            ),
            bottomNavigationBar: _buildBottomNavigationBar(),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Colors.green, // Fondo verde para toda la altura del drawer
        child: SafeArea(
          child: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              ),
            );
          }

          final prefs = snapshot.data!;
          final esAdmin = prefs.getString('id_perfil') == '3';

          return Column(
            children: [
              _buildDrawerHeader(),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        SizedBox(height: 20),
                        if (esAdmin) _buildDrawerItem(
                          icon: Icons.people,
                          title: "Usuarios",
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => UsuariosPage()),
                            );
                          },
                          color: Colors.green,
                        ),
                        _buildDrawerItem(
                          icon: Icons.business,
                          title: "Contratistas",
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ContratistasPage()),
                            );
                          },
                          color: Colors.green,
                        ),
                        _buildDrawerItem(
                          icon: Icons.group,
                          title: "Trabajadores",
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => TrabajadoresPage()),
                            );
                          },
                          color: Colors.green,
                        ),
                        _buildDrawerItem(
                          icon: Icons.groups,
                          title: "Colaboradores",
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ColaboradoresPage()),
                            );
                          },
                          color: Colors.green,
                        ),
                        Divider(height: 30, color: Colors.green.withOpacity(0.2)),
                        _buildDrawerItem(
                          icon: Icons.change_circle,
                          title: "Cambiar Sucursal Activa",
                          onTap: () async {
                            Navigator.pop(context);
                            final resultado = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => CambiarSucursalPage()),
                            );
                            if (resultado == true) {
                              _cargarNombreUsuario();
                              _forzarRecargaPantallas();
                            }
                          },
                          color: Colors.blue,
                        ),
                        _buildDrawerItem(
                          icon: Icons.lock,
                          title: "Cambiar Clave",
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => CambiarClavePage()),
                            );
                          },
                          color: Colors.amber,
                        ),
                        _buildDrawerItem(
                          icon: Icons.info,
                          title: "Acerca de",
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => InfoPage()),
                            );
                          },
                          color: Colors.purple,
                        ),

                        _buildDrawerItem(
                          icon: Icons.logout,
                          title: "Cerrar Sesión",
                          onTap: () {
                            Navigator.pop(context);
                            _cerrarSesion();
                          },
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
        },
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 60, 16, 30),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person, color: Colors.green, size: 40),
              ),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        themeProvider.toggleTheme();
                      },
                      tooltip: themeProvider.isDarkMode ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
                    ),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            "Bienvenido,",
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
          Text(
            userName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  userSucursal,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }



  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Actividades',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Indicadores',
          ),
        ],
      ),
    );
  }
}

// Widget placeholder para Actividades
class _ActividadesPage extends StatelessWidget {
  const _ActividadesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Actividades',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Esta funcionalidad estará disponible próximamente',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// Widget placeholder para Indicadores
class _IndicadoresPage extends StatelessWidget {
  const _IndicadoresPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Indicadores',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Esta funcionalidad estará disponible próximamente',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
