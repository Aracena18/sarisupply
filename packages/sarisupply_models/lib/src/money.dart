final class Money {
  const Money(this.centavos);

  factory Money.nonNegative(int centavos) {
    if (centavos < 0) {
      throw ArgumentError.value(
        centavos,
        'centavos',
        'must not be negative',
      );
    }
    return Money(centavos);
  }

  final int centavos;

  Money operator +(Money other) => Money(centavos + other.centavos);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Money && other.centavos == centavos;

  @override
  int get hashCode => centavos.hashCode;
}
