enum RolUsuario {
  instructor('instructor', 'Instructor'),
  aprendiz('aprendiz', 'Aprendiz');

  final String value;
  final String label;
  const RolUsuario(this.value, this.label);
}
