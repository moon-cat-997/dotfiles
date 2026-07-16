# React Native — Shadow clipping in horizontal ScrollView (and how to compensate)

**Extracted:** 2026-05-05
**Context:** React Native / Expo / react-native-web. Карточки с тенью внутри `<ScrollView horizontal>` или `<FlatList horizontal>`.

## Problem

Тень элементов внутри горизонтального scroll-контейнера обрезается по краям viewport'а ScrollView. Проявляется когда:

- У карточки есть `shadowOffset.height > 0` или `shadowRadius > 0` (RN style на iOS/web) или `elevation` (Android)
- ScrollView не имеет достаточного `padding` внутри `contentContainerStyle`
- ScrollView (или родитель) имеет неявный clip на границах viewport'а

Симптом — тень снизу/сверху и/или слева/справа карточки рендерится «отрубленной по линии». На web особенно заметно, потому что `box-shadow` генерируется через CSS.

## Solution

Добавь `padding` внутрь `contentContainerStyle` равный диапазону тени (offsetY + radius ≈ 30-40px чаще всего), и **компенсируй** его отрицательным `margin` на самом ScrollView — тогда визуальное положение карточек не сдвигается.

Формула breathing-room для RN-shadow:
- **Vertical:** `Math.abs(shadowOffset.height) + shadowRadius`
- **Horizontal:** `shadowRadius` (если offsetX = 0)

## Example

Было (тени обрезаны):
```tsx
<ScrollView
  horizontal
  contentContainerStyle={styles.row}
>
  {items.map(item => <Card key={item.id} {...item} />)}
</ScrollView>

// styles
row: { gap: 12, paddingBottom: 4 }
// Card shadow: offsetY=10, radius=30 → нужно ≥40px вокруг
```

Стало:
```tsx
<ScrollView
  horizontal
  style={styles.scroll}                    // ← negative margin
  contentContainerStyle={styles.row}       // ← padding for shadow
>
  ...
</ScrollView>

// styles
scroll: {
  marginHorizontal: -8,
  marginVertical: -8,
},
row: {
  gap: 12,
  paddingHorizontal: 8,
  paddingTop: 8,
  paddingBottom: 28,    // 10 (offsetY) + 30 (radius) - 12 (visual breathing room sufficient)
},
```

## When to Use

- Карточки с `shadow*` или `elevation` в горизонтальном ScrollView/FlatList
- QA-репорт «тень обрезается», «shadow cut off», «הצל נחתך»
- На web виден «срез» CSS box-shadow по границе scroll-контейнера
- Тебе нужно сохранить исходную визуальную позицию карточек

## Anti-pattern

Не ставь `overflow: 'visible'` на ScrollView — на native это не помогает (RN-ScrollView clipping не управляется через CSS-overflow), на web частично работает, но ломает hit-testing на горизонтальный скролл.

Не убирай тень — лучше дать ей правильно отрисоваться.

Не добавляй `padding` без компенсирующего `margin` — карточки заметно сместятся внутри родительского контейнера, поломает остальной лейаут.

## Cross-platform notes

- **iOS/web:** тень формируется из `shadowColor/shadowOffset/shadowOpacity/shadowRadius`. Padding всегда работает.
- **Android:** тень из `elevation`. Это fake-shadow, нарисованный отдельным compositing layer. Padding также нужен — иначе clipping.
- **react-native-web:** мапит RN shadow* в CSS `box-shadow`. CSS box-shadow рисуется снаружи box, и он точно режется на границе скрытого overflow родителя.
