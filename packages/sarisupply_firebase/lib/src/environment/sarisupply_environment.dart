enum SariSupplyEnvironment {
  dev,
  prod,
}

SariSupplyEnvironment parseSariSupplyEnvironment(String value) {
  return switch (value) {
    'dev' => SariSupplyEnvironment.dev,
    'prod' => SariSupplyEnvironment.prod,
    _ => throw ArgumentError.value(
        value,
        'value',
        'must be dev or prod',
      ),
  };
}
