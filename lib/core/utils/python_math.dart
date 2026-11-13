/// Arredondamento compatível com o `round()` do Python (banker's rounding).
///
/// O backend foi escrito em Python e usa `round()` em taxas, metas e notas.
/// Em casos de `.5` exato, `double.round()` do Dart arredonda para longe do
/// zero e produziria um resultado diferente do servidor.
int pythonRound(num value) {
  if (value.isNaN || value.isInfinite) {
    throw ArgumentError.value(value, 'value', 'Valor não finito');
  }
  final lower = value.floor();
  final fraction = value - lower;
  if (fraction < 0.5) return lower;
  if (fraction > 0.5) return lower + 1;
  return lower.isEven ? lower : lower + 1;
}

/// `round(value, digits)` equivalente ao Python para `digits >= 0`.
double pythonRoundTo(num value, int digits) {
  final factor = _pow10(digits);
  return pythonRound(value * factor) / factor;
}

double _pow10(int digits) {
  var result = 1.0;
  for (var i = 0; i < digits; i++) {
    result *= 10;
  }
  return result;
}
