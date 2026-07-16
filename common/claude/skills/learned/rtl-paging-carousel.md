# RTL Horizontal Carousel in React Native

**Extracted:** 2026-05-07
**Context:** RTL apps (Hebrew/Arabic/Persian) using `ScrollView horizontal pagingEnabled`
для карусели изображений/слайдов.

## Problem
Стандартная горизонтальная карусель в RN — LTR-направленная:
- image[0] слева, активная точка слева, правая стрелка = next.
- В RTL пользователь ожидает: image[0] справа, точка справа, левая стрелка = next.

Дополнительно: на больших экранах с `maxWidth` контейнера `pagingEnabled` scrollTo
приземляется со смещением, потому что `imageWidth` считается из `useWindowDimensions().width`,
а реальная ширина viewport ограничена контейнером.

## Solution

### 1. Реверсировать массив для рендера, не менять handler-логику
```tsx
const displayImages = useMemo(() => [...sources].reverse(), [sources]);
// JSX: displayImages.map(...)
// displayImages[N-1] = original[0] → попадает в правый край (последний child горизонтального ScrollView)
```

### 2. Initial scroll к последнему индексу (= original[0])
```tsx
useEffect(() => {
  if (displayImages.length === 0) return;
  const last = displayImages.length - 1;
  setActiveIndex(last);
  carouselRef.current?.scrollTo({ x: last * imageWidth, animated: false });
}, [displayImages.length, imageWidth]);
```

### 3. Handlers стрелок остаются LTR-наивными
- Левая ← (`active - 1`): displayIndex уменьшается → следующий слайд в RTL ✓
- Правая → (`active + 1`): clamped на N-1 → нет "предыдущей" перед первой ✓

### 4. Dots: плоский `flexDirection: 'row'` поверх `displayImages`
```tsx
<View style={{ flexDirection: 'row', gap: 8 }}>
  {displayImages.map((_, i) => (
    <View style={{ backgroundColor: i === activeIndex ? primary : inactive }} />
  ))}
</View>
```
JSX-индекс i ↔ displayImages[i]. Точка для original[0] (i = N-1) физически справа на web и native одинаково. **НЕ использовать `row-reverse`** — иначе подсвечиваемая точка зеркалится не туда.

### 5. imageWidth из реальной ширины контейнера через onLayout
```tsx
const [carouselWidth, setCarouselWidth] = useState(0);
const imageWidth = carouselWidth > 0 ? carouselWidth : Math.min(screenWidth - 10, 560);

<View
  style={{ maxWidth: 560, width: '100%', alignSelf: 'center' }}
  onLayout={(e) => {
    const w = e.nativeEvent.layout.width;
    if (w > 0 && Math.abs(w - carouselWidth) > 0.5) setCarouselWidth(w);
  }}
>
  <ScrollView horizontal pagingEnabled ref={carouselRef}>...</ScrollView>
</View>
```
Без этого: на screenWidth=800 imageWidth=560, контейнер=560, но если есть padding/margin родителя — реальный viewport отличается. scrollTo промахивается, картинка съезжает.

## When to Use
- RN/Expo проект с RTL (he/ar/fa)
- Горизонтальный `ScrollView pagingEnabled` для слайдов/фото
- Контейнер с `maxWidth` (адаптив для desktop/tablet)
- Stable cross-platform поведение (web + native, без `I18nManager.forceRTL` зависимостей)

## Anti-patterns
- ❌ `flexDirection: 'row-reverse'` для контейнера ScrollView — ломает координаты scroll
- ❌ `transform: [{ scaleX: -1 }]` — ломает touch events и порядок касаний
- ❌ Зависимость на `I18nManager.isRTL` — поведение расходится между web и native
- ❌ Вычислять `imageWidth` из `useWindowDimensions().width` если контейнер capped
