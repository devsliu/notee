/// Simple mutable reference — Dart has no built-in ref semantics.
/// Pass an [ObjectRef] to let callee read/write caller's variable by reference.
class ObjectRef<T> {
  T value;
  ObjectRef(this.value);
}
