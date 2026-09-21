/// Debe reflejar el enum `RolUsuario` del backend (app/models.py).
enum RolUsuario {
  instructor('instructor', 'Instructor'),
  aprendiz('aprendiz', 'Aprendiz');

  final String value;
  final String label;
  const RolUsuario(this.value, this.label);
}
