# Changelog

## 0.2.0

- Add `MultipleSideEffectListener` widget to merge multiple `SideEffectListener` widgets without nesting.
- Refactor `SideEffectListener` to extend `SingleChildStatefulWidget` for compatibility with `MultipleSideEffectListener`.
- Add `provider` as a direct dependency.
- Add `SideEffectProvider` widget that combines `BlocProvider` and `SideEffectListener` into a single widget, reducing boilerplate for the common create-provide-listen pattern.

## 0.1.0

- Initial release.
- `SideEffectListener` widget.
- `SideEffectConsumer` widget.
