# liveondesk
### App de escritorio macOS — Documento de idea y tecnologías
*Versión 1.0 — Marzo 2026*

---

## Qué es

Una aplicación de escritorio para Mac que convierte la foto real de una mascota o cualquier criatura en un compañero animado que vive sobre el escritorio. La mascota detecta automáticamente todas las ventanas que el usuario tiene abiertas, las clasifica por su forma geométrica, y reacciona a ellas con comportamientos físicos y emocionales coherentes. Camina sobre el borde superior de ventanas anchas, salta encima de ventanas cuadradas, se esconde en esquinas, sigue el cursor, baila si detecta música, duerme si el usuario está inactivo, y genera pensamientos visibles en una burbuja flotante según el contexto de lo que hay en pantalla.

El diferenciador central frente a cualquier competidor existente es que el sprite se parece de verdad a la foto real del usuario — no es un personaje genérico sino su mascota específica, generada con inteligencia artificial.

---

## La experiencia del usuario

### Onboarding
El usuario abre la app, sube una foto de su mascota, le pone nombre, y en menos de dos minutos su mascota ya está viva sobre el escritorio. No hay configuración técnica ni pasos complicados. La IA hace todo el trabajo de análisis y generación.

### Día a día
La mascota vive en el escritorio de forma permanente. No interfiere con el trabajo — la ventana donde vive es completamente transparente y deja pasar los clics al contenido de debajo. Pero está ahí, moviéndose, reaccionando, pensando. Si el usuario abre Xcode, la mascota se sube al editor y "programa". Si pone música, baila. Si lleva horas sin moverse, la mascota se duerme con una burbuja de ZZZ. Si cierra una ventana sobre la que estaba parada, cae por gravedad hasta el suelo.

### Interacciones disponibles
El usuario puede hacer clic sobre la mascota para acariciarla. Puede darle de comer arrastrando un icono hacia ella. Puede cambiar su nombre y personalidad desde el menú. La mascota tiene estados de ánimo que evolucionan — si el usuario la ignora mucho tiempo se pone triste, si interactúa seguido se pone feliz.

---

## Cómo detecta las ventanas y clasifica las formas

macOS expone en tiempo real la posición exacta, el tamaño y el dueño de cada ventana abierta mediante una API del sistema llamada `CGWindowListCopyWindowInfo`. Esta API no requiere ningún permiso especial para leer la geometría — solo el nombre de la app y las coordenadas. La mascota la consulta cada medio segundo para tener un mapa actualizado del escritorio.

Con ese mapa, clasifica cada ventana por su proporción geométrica:

- **Ventana muy ancha** (más de 2.5 veces más ancha que alta) → plataforma para caminar de punta a punta
- **Ventana aproximadamente cuadrada** → bloque para saltar encima y "conquistar"
- **Ventana pequeña en una esquina de la pantalla** → escondite donde la mascota se mete y se asoma
- **Ventana de app de música activa** → zona de baile, activa el ciclo de animación de danza
- **Borde inferior (Dock)** → pista de carrera entre los íconos

Cuando una ventana se cierra mientras la mascota está encima, la mascota cae por gravedad al siguiente nivel disponible o al suelo. Esto crea momentos espontáneos muy llamativos que los usuarios querrán grabar y compartir.

---

## Cómo se genera el sprite con IA

### El problema
Tomar una foto real de una mascota y convertirla en un sprite animado con múltiples ciclos de movimiento (caminar, saltar, dormir, bailar, olfatear) que se vea consistente en todos los frames. Esto no existe como herramienta única — requiere un pipeline de varios pasos.

### El pipeline completo

**Paso 1 — Aislar la mascota del fondo**
El sistema operativo tiene una herramienta integrada (`VNGenerateForegroundInstanceMaskRequest` del framework Vision de Apple) que recorta automáticamente el sujeto principal de cualquier foto. Funciona con cualquier animal, no solo gatos y perros. Es gratuita y funciona en el dispositivo sin enviar datos a ningún servidor.

**Paso 2 — Identificar el tipo de animal**
También con Vision framework de Apple se detecta si es gato o perro (los dos más comunes). Para otros animales, el usuario confirma manualmente en el onboarding. Esto determina qué modelo base de movimiento usar.

**Paso 3 — Extraer el color dominante del pelaje**
Se analiza la imagen aislada (ya sin fondo) y se extrae el color o los colores principales del animal. Esto se usa para personalizar el sprite base con los colores reales de la mascota.

**Paso 4 — Entrenar un LoRA con las fotos**
LoRA es una técnica de inteligencia artificial que enseña a un modelo de generación de imágenes a reconocer y reproducir una identidad visual específica — en este caso, la mascota concreta del usuario. Con 3 a 10 fotos del animal desde distintos ángulos, se entrena un adaptador pequeño que "memoriza" su apariencia. Este entrenamiento toma aproximadamente 2 minutos y cuesta alrededor de $2-3 USD por mascota. Se hace a través del servicio **fal.ai**.

**Paso 5 — Generar los frames de animación**
Usando el LoRA entrenado, se generan frames individuales para cada pose: caminar (8 frames), estar quieto (4 frames), saltar (4 frames), dormir (4 frames), bailar (8 frames), olfatear (6 frames). El modelo garantiza que la identidad del animal se mantiene en todas las poses. Para ciclos de movimiento fluido como caminar, se puede usar generación de video corto con **Wan 2.1** — el mejor modelo open source de video a marzo 2026, disponible vía fal.ai.

**Paso 6 — Remover fondos de cada frame y ensamblar spritesheet**
Cada frame generado pasa por remoción de fondo automática. Luego todos los frames se ensamblan en un spritesheet (una imagen única con todos los fotogramas en cuadrícula) con un archivo de metadatos que le dice a la app qué frames corresponden a qué animación.

**Paso 7 — Guardar y cachear**
El spritesheet final se guarda localmente y en la nube (Supabase) para que no haya que regenerarlo cada vez.

### Por qué este pipeline y no otro
Los modelos de video como Kling AI 2.5 o Runway Gen-4 producen animaciones de alta calidad pero no permiten fine-tuning (LoRA) para preservar la identidad del animal específico del usuario — generan movimiento bonito pero el personaje cambia entre sesiones. Wan 2.1 con LoRA resuelve esto: el animal se parece de verdad a la foto original en todos los frames.

---

## Tecnologías por área

### Renderizado del escritorio
- **Framework**: SpriteKit (Apple) — motor de juegos 2D integrado en macOS. Tiene física (gravedad, colisiones, rebotes), gestión de sprites y animaciones, y soporte nativo de transparencia. Consumo de CPU menor al 5% en estado idle.
- **Ventana**: NSPanel (AppKit) — ventana especial de macOS sin bordes, con fondo transparente, que flota sobre todas las demás apps sin robarles el foco ni interferir con los clics del usuario.
- **Aparece en todos los escritorios virtuales**: propiedad `canJoinAllSpaces` de macOS.

### Detección de ventanas y física
- **API**: `CGWindowListCopyWindowInfo` (CoreGraphics, Apple) — sin permisos especiales para leer geometría.
- **Física**: Motor integrado de SpriteKit con gravedad, bordes de colisión y detección de contacto.
- **Frecuencia de actualización**: 2 Hz (cada 500ms) — suficiente para un desktop pet, sin impacto en CPU.

### Generación de sprites
- **Plataforma principal**: **fal.ai** — marketplace de APIs de IA con los mejores modelos de generación de imagen y video, facturación por uso, sin suscripción mínima.
- **LoRA training**: FLUX LoRA Fast Training (fal.ai) — ~$2-3 por mascota, ~2 minutos.
- **Generación de frames**: FLUX Kontext Pro (fal.ai) — ~$0.04 por imagen.
- **Generación de video/animación**: Wan 2.1 Image-to-Video (fal.ai) — ~$0.05 por segundo de video.
- **Alternativa**: Replicate — mismos modelos, precios similares, más conocido por desarrolladores con experiencia previa.
- **Remoción de fondo**: Vision framework de Apple (on-device, gratuito) + rembg como alternativa cloud.
- **Moderación de contenido**: filtro NSFW de fal.ai activado en todas las generaciones. Obligatorio.

### Sistema de pensamientos
Los pensamientos se generan con un modelo de lenguaje que recibe como contexto el estado actual de la mascota (qué está haciendo), la app que tiene el usuario activa en ese momento, la hora del día, y el nombre y personalidad de la mascota.

- **Opción 1 — On-device gratuita**: Apple Foundation Models — disponible en macOS 26 (Tahoe) en Macs con Apple Silicon. Modelo de ~3B parámetros, funciona offline, sin costo, los datos no salen del dispositivo. Limitado a macOS 26+.
- **Opción 2 — Cloud económica**: GPT-4o-mini (OpenAI API) — $14 al mes para 1,000 usuarios activos diarios con 10 pensamientos por sesión. La opción más barata de las APIs cloud a esta fecha.
- **Opción 3 — On-device para Mac antiguas**: MLX + Gemma 3 1B — framework open source de Apple para ejecutar modelos localmente en Apple Silicon. El modelo pesa ~800MB y genera texto muy rápido. Gratuito.
- **Estrategia**: usar Apple Foundation Models como primera opción, MLX como fallback para macOS anterior, GPT-4o-mini como fallback cloud para cuando los modelos locales no estén disponibles.
- **Frecuencia**: máximo un pensamiento cada 30 segundos para no generar costos innecesarios.

### Procesamiento de foto en onboarding
- **Detección de animal**: `VNRecognizeAnimalsRequest` (Vision, Apple) — detecta gatos y perros automáticamente. Para otros animales, selector manual.
- **Remoción de fondo**: `VNGenerateForegroundInstanceMaskRequest` (Vision, Apple) — la misma tecnología que "Levantar sujeto" en macOS. Funciona con cualquier animal.
- **Extracción de color dominante**: `CIAreaAverage` (Core Image, Apple) sobre la imagen ya aislada.
- Todo on-device, gratuito, sin latencia de red.

### Detección de contexto del sistema
- **App activa**: `NSWorkspace` (AppKit, Apple) — notificaciones en tiempo real sin permisos.
- **Inactividad del usuario**: `CGEventSource.secondsSinceLastEventType` — sin permisos.
- **Audio activo**: `kAudioDevicePropertyDeviceIsRunningSomewhere` (Core Audio) — heurístico. No existe API pública perfecta desde macOS 15.4. Alternativa más confiable: detectar si la app activa es Spotify, Apple Music, Tidal, etc. por su bundle ID.

### Backend
- **Supabase** (free tier) — autenticación de usuarios, almacenamiento de sprites generados, configuración sincronizada entre dispositivos. Gratuito hasta 500MB de storage y 50,000 usuarios activos al mes.

### Todo lo que el desarrollador producirá con IA
En lugar de contratar personas, estas tareas se resuelven con herramientas de IA:

| Tarea | Herramienta de IA |
|---|---|
| Código Swift completo | Claude / GPT-4o con contexto del proyecto |
| Sprites base (6 animales) | Midjourney / FLUX / Ideogram para pixel art cartoon |
| Ícono de la app | Midjourney / DALL-E 3 |
| Textos de onboarding y UI | Claude |
| Landing page HTML/CSS | Claude / Cursor |
| Video demo para la landing | Kling AI / Runway con capturas de pantalla reales |
| Metadatos del App Store | Claude |
| Respuestas a reviews | Claude |

---

## Competencia existente y qué los diferencia

**BitTherapy** (App Store, macOS, Swift nativo) — la referencia técnica más directa. Tiene 35+ personajes pixel art, física sobre ventanas, multi-monitor. No tiene generación con IA ni personalización con foto real. Su repo es open source en GitHub (`CyrilCermak/bit-therapy`) — arquitectura estudiable.

**Shimeji** (Windows principalmente, Java) — el clásico del género. Personajes animados sobre el escritorio, interacción con ventanas. Solo Windows nativamente, requiere Java. No tiene IA.

**Desktop Goose** (Windows, C#) — viral por comportamientos disruptivos y cómicos. Sin personalización, sin IA. Lo que lo hizo viral: comportamientos inesperados que los usuarios quieren grabar y compartir. Lección: los momentos espontáneos son el motor de marketing orgánico.

**Pengu by Born AI** — el más cercano conceptualmente, usa LLMs para personalidad. $15M en funding, 15M usuarios. Compite en el espacio de "AI companion" pero no hace la generación de sprite a partir de foto real de mascota.

El único diferenciador que ningún competidor tiene: **la mascota se parece a la foto real de TU animal específico**, generada con IA en el onboarding.

---

## Modelo de negocio

### Plan gratuito
Una mascota. Sprite base (sin generación IA con foto). Pensamientos estáticos (banco de frases). Comportamientos completos. Sin límite de tiempo.

### Plan Pro — $2.99/mes o $19.99/año
Mascotas ilimitadas. Generación de sprite personalizado con IA a partir de foto real. Pensamientos dinámicos con LLM. Accesorios y skins adicionales (v2). Soporte prioritario.

### Pago único — $34.99
Acceso Pro de por vida. Para usuarios que prefieren no suscripciones.

### Comisiones
Con el Small Business Program de Apple (ingresos bajo $1M), la comisión es 15% — no 30%. El desarrollador retiene $2.54 de cada suscripción mensual de $2.99.

### Break-even
Con costos fijos de ~$22/mes (Supabase + LLM), se necesitan solo **9 suscriptores Pro** para cubrir gastos. Todo lo demás es margen.

---

## Distribución

### Estrategia principal — Mac App Store
El hallazgo clave de la investigación: como liveondesk solo lee geometría de ventanas (no capturas de pantalla ni contenido), **no necesita el permiso de Screen Recording**. Esto elimina la principal barrera que muchos developers asumen para este tipo de apps. La distribución vía App Store es viable sin fricción de permisos.

### Estrategia secundaria — Distribución directa
DMG firmado y notarizado con certificado Apple Developer para usuarios que prefieren instalar fuera del App Store. Pagos a través de Paddle (actúa como Merchant of Record, gestiona impuestos globalmente). Auto-actualizaciones con Sparkle (framework open source estándar del sector).

### Requisito mínimo
Apple Developer Program — $99 USD/año. Incluye certificados para ambas formas de distribución, notarización, TestFlight para betas, y acceso a App Store Connect.

---

## Costos operativos reales

### Costo por usuario nuevo (onboarding con sprite IA)
- Entrenamiento LoRA: ~$2.50
- Generación de frames (~30 imágenes): ~$1.20-3.00
- Almacenamiento: ~$0.02
- **Total: ~$4-6 por mascota generada**

### Costo mensual con 1,000 usuarios activos diarios
- Supabase (free tier): $0
- GPT-4o-mini (pensamientos): ~$14
- fal.ai (40 usuarios Pro nuevos × $5): ~$200
- Apple Developer Program (amortizado): ~$8
- **Total fijo: ~$22/mes**
- **Total variable: ~$200-400/mes según crecimiento**

### Margen por suscriptor Pro
Ingreso neto (después de comisión Apple): $2.54/mes
Costo variable por suscriptor activo (LLM + amortización sprite): ~$0.46/mes
**Margen: ~82%**

---

## Riesgos honestos

**Consistencia de identidad en sprites generados** — los modelos actuales preservan la identidad del animal con ~90% de fidelidad usando LoRA. El 10% restante son frames que se ven "raro". Solución: generar más frames de los necesarios y descartar los que no pasan un umbral de similitud automático.

**Detección de audio** — no existe API pública perfecta en macOS desde la versión 15.4. La detección por bundle ID de app de música es más confiable. Se puede complementar preguntándole al usuario si quiere activar el modo baile manualmente.

**Apple Foundation Models** — disponible solo en macOS 26+ con Apple Intelligence activado. Hay que tener bien implementado el fallback a GPT-4o-mini para usuarios en macOS anterior.

**Comportamiento sobre ventanas en tiempo real** — si el usuario mueve muchas ventanas rápidamente, hay que manejar bien las transiciones físicas para que la mascota no "teletransporte" sino que caiga y aterrice naturalmente.

---

## Orden de construcción recomendado

1. Ventana transparente + sprite estático sobre el escritorio — validar que el efecto visual es el correcto
2. Detección de ventanas + física básica — mascota cae y camina sobre ventanas reales
3. Motor de comportamientos — todos los estados (caminar, saltar, dormir, bailar, etc.)
4. Burbuja de pensamiento con frases estáticas
5. Onboarding — foto → detección → sprite base personalizado por color
6. Pipeline de generación IA — LoRA + frames + spritesheet
7. Pensamientos dinámicos con LLM
8. Monetización — StoreKit 2 y paywalls
9. Distribución — App Store submission

El momento más importante de todo el proceso es el paso 1. Si ver una mascota animada encima de las ventanas reales genera la reacción emocional correcta en las primeras 10 personas que lo prueban, todo lo demás es implementación. Si no genera esa reacción, hay que iterar antes de seguir.

---

*Documento de idea y arquitectura — liveondesk v1.0*
