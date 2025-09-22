import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NuevoColaboradorPage extends StatefulWidget {
  @override
  _NuevoColaboradorPageState createState() => _NuevoColaboradorPageState();
}

class _NuevoColaboradorPageState extends State<NuevoColaboradorPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController apellidoPController = TextEditingController();
  final TextEditingController apellidoMController = TextEditingController();
  final TextEditingController rutController = TextEditingController();
  final TextEditingController dvController = TextEditingController();
  bool _guardando = false;
  String? idSucursal;

  @override
  void initState() {
    super.initState();
    _cargarSucursal();
  }

  Future<void> _cargarSucursal() async {
    final id = await ApiService().getSucursalActiva();
    setState(() {
      idSucursal = id;
    });
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  void _guardarColaborador() async {
    if (!_formKey.currentState!.validate()) return;
    if (idSucursal == null) {
      _mostrarError('No se pudo obtener la sucursal activa.');
      return;
    }
    setState(() => _guardando = true);
    try {
      final data = {
        "nombre": nombreController.text.trim(),
        "apellido_paterno": apellidoPController.text.trim(),
        "apellido_materno": apellidoMController.text.trim().isEmpty ? null : apellidoMController.text.trim(),
        "id_sucursal": idSucursal,
        "id_estado": 1,
        // Los demás campos van null
        "rut": null,
        "codigo_verificador": null,
        "id_cargo": null,
        "fecha_nacimiento": null,
        "fecha_incorporacion": null,
        "id_prevision": null,
        "id_afp": null
      };
      final res = await ApiService().crearColaborador(data);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _mostrarError('Error al crear colaborador: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        title: const Text("Nuevo Colaborador", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        Text(
                          "Datos del Colaborador",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: nombreController,
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        prefixIcon: Icon(Icons.person_outline_outlined, color: theme.colorScheme.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.withOpacity(0.05),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Ingrese el nombre' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: apellidoPController,
                      decoration: InputDecoration(
                        labelText: 'Apellido Paterno',
                        prefixIcon: Icon(Icons.person_outline_outlined, color: theme.colorScheme.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.withOpacity(0.05),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Ingrese el apellido paterno' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: apellidoMController,
                      decoration: InputDecoration(
                        labelText: 'Apellido Materno (opcional)',
                        prefixIcon: Icon(Icons.person_outline_outlined, color: theme.colorScheme.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.withOpacity(0.05),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: _guardando
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(Icons.save),
                      label: Text(_guardando ? 'Guardando...' : 'Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _guardando ? null : _guardarColaborador,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
