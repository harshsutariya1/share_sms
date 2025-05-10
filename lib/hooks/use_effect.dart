
/// A custom hook similar to useEffect in React
/// Executes a function when dependencies change
/// Returns dispose function
void useEffect(Function? Function() effect, List<Object?> dependencies) {
  useEffect(() {
    final dispose = effect();
    return dispose;
  }, dependencies);
}
