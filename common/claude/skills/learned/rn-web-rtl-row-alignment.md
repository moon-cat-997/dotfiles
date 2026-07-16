# React Native Web — RTL row alignment that works on both web and native

**Extracted:** 2026-05-05
**Context:** React Native + react-native-web проекты с RTL-локалью (иврит/арабский). Когда нужно прижать row-контент к правому краю и контролировать порядок элементов, не полагаясь на `I18nManager.isRTL`.

## Problem

В RTL-приложениях на RN фиксы вида `flexDirection: 'row'` + `justifyContent: 'flex-end'/'flex-start'` ведут себя по-разному на web и native:

- **Native (RN, RTL включён через I18nManager):** `row` зеркалится автоматически, `flex-start` визуально = правый край.
- **Web (react-native-web):** контейнер по умолчанию рендерится как LTR-flex, `flex-start` = левый край физически. I18nManager.forceRTL не всегда зеркалит layout-движок web.

В результате одинаковый CSS даёт разные визуальные результаты. Самый частый симптом: цифры/значки в RTL-блоке прижимаются к левому краю на web, хотя на native всё ок (или наоборот).

## Solution

Не полагайся на `justifyContent` + flexDirection для RTL-выравнивания. Вместо этого:

1. **Прижми сам row к правому краю родительской column** через `alignSelf: 'flex-end'`. Это работает одинаково на web и native, потому что `alignSelf` действует на cross-axis колонки и не зависит от направления текста.
2. **Внутри row контролируй порядок через `flexDirection: 'row-reverse'`** — порядок JSX-детей переворачивается визуально, идентично на обеих платформах.
3. **Не ставь `justifyContent`** — row сожмётся до ширины контента благодаря `alignSelf`.

## Example

Было (ломалось на web — контент уезжал влево):
```tsx
amountRow: {
  flexDirection: 'row-reverse',
  alignItems: 'center',
  justifyContent: 'flex-end', // ← на web = левый край
  gap: 8,
}
```

Стало (работает везде — row справа, badge слева от amount):
```tsx
amountRow: {
  flexDirection: 'row-reverse', // JSX [Text, Badge] → визуально [Badge, Text]
  alignItems: 'center',
  alignSelf: 'flex-end',        // прижимает row к правому краю column-родителя
  gap: 8,
}
```

JSX:
```tsx
<View style={styles.amountRow}>
  <Text style={styles.amount}>₪42,500</Text>
  <Badge label="12%+" />
</View>
```

Результат на обеих платформах: `[12%+] ₪42,500` прижато к правому краю.

## When to Use

- RTL-компонент должен работать одинаково на web (react-native-web) и native (iOS/Android)
- Нужно прижать строку контента к правому краю в RTL
- Текущий `justifyContent: 'flex-end'/'flex-start'` даёт разный результат на web vs native
- Заголовок/значение карточки «прыгает» к противоположному краю при сборке на web

## Anti-pattern

Не пиши `right: X` через absolute positioning для решения проблем выравнивания — это ломается при разных длинах контента и при изменениях шрифта.

Не используй `writingDirection: 'rtl'` как замену layout-выравниванию — он влияет только на направление текста внутри `<Text>`, не на flex-выкладку родителя.

## Related

- Уже есть в memory: `feedback_rtl_flexstart.md` (для native), `feedback_rtl_horizontal_scroll.md`, `feedback_rtl_horizontal_scroll_cards.md`. Этот паттерн дополняет их — фокус на cross-platform консистентности.
