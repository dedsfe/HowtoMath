# O mascote: peças e o que cada emoção faz com elas

Mapa do que o personagem é feito e de como cada peça muda por estado.
Tudo aqui vive hoje em `HowToMath/Character/CharacterLab.swift` (1933 linhas).

Este arquivo é o alvo do detalhamento — quando uma pose estiver errada, o
conserto se descreve aqui primeiro e vira código depois.

---

## As peças

Empilhadas nesta ordem (a primeira fica atrás):

| Peça | O que é | Onde |
|---|---|---|
| **pés** | duas elipses laranja, atrás do corpo | `feet`, `foot(side:)` |
| **corpo** | uma elipse verde com gradiente de cima pra baixo | `body_` |
| **olhos** | branco + pupila + brilho, com pálpebra por cima | `eye(side:)`, `pupil` |
| **sobrancelha** | uma barra preta, só no `serious` | `brow(side:)` |
| **boca** | uma linha que dobra pra cima ou pra baixo | `mouth`, `openMouth` |
| **lágrimas** | gotas + nível de água dentro do olho | `tear(side:)`, `waterLevel(side:)` |

Não existe: pescoço, braços, orelhas, nariz. Toda expressão sai de **olho,
boca e postura** — é por isso que cada um deles tem tantos parâmetros.

---

## Os controles

Os números que as emoções mexem. Quase toda pose nova é uma combinação
diferente destes, e não uma peça nova.

### Olho

| Controle | O que faz |
|---|---|
| `eyeSpan` | tamanho do olho inteiro |
| `pupilSpan` | tamanho da pupila — o controle mais expressivo da cara |
| `pupilDrop` | pupila mais alta ou mais baixa dentro do olho |
| `gaze` | pupila pros lados; passeia sozinha quando ocioso |
| `hood` | pálpebra descendo por cima (0 = aberto, 1 = cerrado) |
| `hoodInward` | de que lado a pálpebra desce — vira tristeza ou raiva |
| `lid` | a piscada; independente do `hood` |

### Boca

| Controle | O que faz |
|---|---|
| `mouthCurve` | 1 sorriso, 0 reta, negativo pra baixo |
| `mouthTilt` | um canto mais baixo que o outro |
| `mouthDrop` | boca inteira mais pra baixo no rosto |

### Corpo e pés

| Controle | O que faz |
|---|---|
| `flightStretch` | achata ou estica o corpo |
| `flightLean` | inclinação |
| `flightStride` | onde cada pé fica |
| `walkBob`, `stride` | a caminhada |

---

## Como cada estado usa isso

Só o que **muda**; o que não aparece está no padrão.

### `idle` — vivo, parado
Respira, pisca, e a cada ~7s dá uma olhadela pro lado e volta. É o padrão de
todos os números.

> A olhadela é o que separa "vivo" de "ligado". Um rosto que só respira parece
> uma tela de descanso.

### `sad` — errou
- pupila **bem pequena** (0.10 — o menor de todos)
- pupila **baixa** (0.055)
- boca pra baixo (−0.75) e **torta** (0.45), caída no rosto
- lágrimas

> A pupila encolhendo é o que faz a tristeza. Olho grande e molhado dá pena;
> olho pequeno dá derrota.

### `gloomy` — tristinho, mas vivo
- pupila **grande** (0.225) e olho grande (0.345)
- pálpebra descendo **pelo canto de fora** (`hood` 1, `hoodInward` false)
- boca pra baixo, mas menos (−0.62)

> Mesma água do `sad`, pupila oposta. É a diferença entre derrotado e carente.

### `joy` — chorinho de alegria
- olho **maior de todos** (0.375), pupila maior de todas (0.245)
- pálpebra **aberta** (sem `hood`)
- **boca não muda** — continua o sorriso normal

> É quase o `gloomy` com a pálpebra aberta e o sorriso mantido. Esse sorriso é
> a diferença inteira entre chorar de tristeza e chorar de felicidade.

### `serious`
- pálpebra descendo **pelo canto de dentro** (`hoodInward` true)
- **sobrancelha** preta por cima
- boca reta (0)
- respiração, piscada e olhadela **continuam normais**

> Só o ângulo da pálpebra separa isso de `gloomy`. Mesma pálpebra, mesma
> quantidade, sinal trocado.

### `flying` — voo de herói *(o único de perfil)*
Único estado que vira o personagem de lado. Tudo abaixo depende disso:

- **rosto deslocado 0.30 pra frente**, um olho só, olho estreitado em 84%
- **pupila travada na frente** (`gaze` fixo em −0.055), sem passear
- **pálpebra cerrada caindo pra frente** — não pro canto de dentro
- **boca reta e cortada pela metade** (0.075), levemente à frente do olho
- corpo virado **cápsula** (1.38 × 0.78), inclinação de só 8°
- **pés esticados pra trás**, na altura do corpo, alongados no comprimento

> De perfil não existe canto de dentro e de fora — existe **frente e trás**.
> Toda decisão aqui é sobre qual lado é a frente.

### `wtf`
- olhos = dois círculos vazios (sem pupila, sem brilho)
- boca = um quadrado torto

> A única cara desenhada com outro traço. É o ponto: nada dele parece assim.

### `walkIn` / `leapIn` / `arrive` — chegadas
Não mexem no rosto. São só escala, altura e os pés — o personagem chega de
longe e cresce. `leapIn` faz o mesmo trajeto com um mortal no meio.

---

## Regras que já custaram caro

Aprendidas quebrando:

1. **Perfil é um pacote.** Corpo deitado + pés pra trás + rosto de lado vêm
   juntos. Rosto de frente deitado na horizontal lê como o bicho tombando.
2. **Pupila centralizada = ninguém pilotando.** Não importa quão cerrado esteja
   o olho: com o ponto no meio, ele semicerra pra nada.
3. **De perfil a boca é metade.** A outra metade deu a volta na bochecha.
   Desenhada inteira, vira palito na boca.
4. **Linha que começa fora do corpo** lê como objeto que ele carrega, não como
   parte do rosto.
5. **Esforço não sorri.** O sorriso é o que faz parecer que ele está curtindo o
   passeio em vez de ir a algum lugar.
6. **A pálpebra faz o trabalho da sobrancelha.** Com o olho já cortado, uma
   barra por cima vira risco solto na testa.

---

## A referência (Clucky), peça por peça

Análise dos frames do vídeo. **Correção importante primeiro:**

> ### Ela usa óculos.
>
> Aquele anel cinza grosso que eu vinha tratando como "olho enorme" é um **aro
> de óculos**. O olho de verdade é a bolinha preta minúscula dentro dele.
>
> E a consequência: o corte diagonal que me pareceu **pálpebra cerrada** é o
> **reflexo na lente** — a diagonal de brilho que todo vidro desenhado tem. A
> cara de determinada não vem de olho apertado, vem dos dois reflexos formando
> um V sobre as lentes.
>
> Nosso mascote não usa óculos, então isso não se copia direto. O que se
> aproveita é a **posição** do olho: pequeno, baixo, e à frente.

### De perfil (voando)

| Peça | Como é |
|---|---|
| **corpo** | uma massa branca orgânica, tipo batata — **não** é elipse limpa |
| **cabeça** | não existe separada; é a ponta esquerda da mesma massa |
| **óculos** | aro cinza grosso, circular, ~40% da altura do corpo |
| **lente** | branca, com uma diagonal de reflexo mais escura no alto |
| **olho** | bolinha preta **minúscula**, em vírgula, no canto de baixo da lente |
| **crista** | laranja escuro, no alto da cabeça, à frente |
| **bico** | amarelo, pequeno, saindo pra frente no meio da cabeça |
| **barbela** | laranja escuro, logo abaixo do bico |
| **asa** | só uma mancha cinza clara oval no meio do corpo |
| **cauda** | três pontas brancas, em cima e atrás |
| **pés** | amarelos, atrás e embaixo, com dedos |

### De frente (mascote pequeno do paywall)

| Peça | Como é |
|---|---|
| **óculos** | dois aros quase se tocando no meio |
| **olhos** | bolinhas pretas com **brilho branco em cima**, na parte de baixo e de dentro de cada lente |
| **crista** | vertical, entre os dois óculos |
| **bico** | amarelo, triangular, pequeno, no centro |
| **braços** | dois traços cinza finos e curvos nas laterais |

### O que dá pra aproveitar

Sem copiar os óculos:

1. **Olho pequeno dentro de área grande.** A expressão vem do contraste entre
   uma forma grande e clara e um ponto preto pequeno dentro dela.
2. **Olho baixo e à frente**, nunca centrado.
3. **Corpo orgânico, não geométrico.** Nossa elipse é limpa demais; a dela tem
   barriga, cauda e caroços.
4. **Contorno é uma peça só.** Cabeça e corpo são a mesma massa — não há
   pescoço nem divisão.

---

## Próximo passo

Separar `CharacterLab.swift` (1933 linhas) em arquivos por peça: `Eye.swift`,
`Mouth.swift`, `Body.swift`, `Feet.swift`, e um `Expression.swift` com os
switches por emoção. Este documento é o mapa do corte.
