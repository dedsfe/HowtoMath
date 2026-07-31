# HowToMath — Design System

Linguagem visual inspirada no **Duolingo**: superfícies claras, tipografia
arredondada pesada, botões com "lábio" 3D que afunda no toque, e feedback
exagerado a cada acerto.

O que puxamos do Duo são **padrões de interface** (formato de botão, hierarquia,
ritmo de feedback), não assets, mascote ou marca — nada de arte deles entra aqui.

---

## 1. Cores

| Token | Hex | Uso |
|---|---|---|
| `green` | `#85CB33` | Cor primária. CTA, progresso, acerto, símbolo da conta. |
| `greenEdge` | `#689E28` | Lábio 3D e borda do CTA. É `green` a 78% de luz. |
| `ink` | `#100B00` | Texto principal, numerais, ícones. |
| `pale` | `#EFFFC8` | Preenchimento suave: tile selecionado, halo, faixa de acerto. |
| `white` | `#FFFFFF` | Fundo da tela e face dos tiles em repouso. |

Derivados (não são cores novas, são o `ink` transparente):

| Token | Valor | Uso |
|---|---|---|
| `dim` | `ink` @ 45% | Texto secundário, ícone de fechar. |
| `line` | `ink` @ 16% | Borda e lábio dos tiles neutros. |
| `track` | `ink` @ 8% | Trilho da barra de progresso. |

**Único tom fora da paleta:** o vermelho de erro, em três variações e mais nada.

| Token | Hex | Uso |
|---|---|---|
| `miss` | `#FF4B4B` | Borda e numeral do tile errado. |
| `missSoft` | `#FFDFE0` | Fundo do banner de erro. |
| `missDeep` | `#EA2B2B` | Texto do banner e face do botão ENTENDI. |
| `missEdge` | `#C02222` | Lábio do botão ENTENDI. |

Erro precisa ler como erro — verde-escuro não resolve isso.

### Regra de contraste
Texto sobre `green` é **branco**. Texto sobre `white` ou `pale` é **`ink`**.
Nunca `green` sobre `white` em texto pequeno — não passa em contraste.

---

## 2. Tipografia

Uma família só: **SF Rounded**, sempre `.bold` ou `.heavy`.
(É o equivalente de sistema ao Feather Bold do Duo.)

| Papel | Tamanho | Peso |
|---|---|---|
| Numeral da conta | 62 | bold, monospacedDigit |
| Numeral do tile | 34 | bold, monospacedDigit |
| Placar final | 64 | bold |
| Label de CTA | 18 | heavy, **CAIXA ALTA**, tracking 0.8 |
| Label secundário | 15–17 | semibold |

Numerais sempre `monospacedDigit` — sem isso o número dança quando troca.

---

## 3. Botões — o lábio 3D

É a assinatura do Duo e a peça central daqui.

```
┌─────────────┐  ← face (radius 16)
│    TEXTO    │
└─────────────┘
└─────────────┘  ← lábio: 4pt de uma cor mais escura, só embaixo
```

- **Repouso:** face na cor cheia, lábio de 4pt visível abaixo.
- **Pressionado:** a face desce 4pt e o lábio some. O botão inteiro *não* muda de
  tamanho — só afunda. É isso que dá a sensação física.
- Som e háptico disparam no **touch-down**, nunca no release. Isso já está certo
  no código e não deve mudar.
- Sem `scaleEffect`. Escala é atalho; o lábio é a coisa de verdade.

| Variante | Face | Lábio | Texto |
|---|---|---|---|
| CTA primário | `green` | `greenEdge` | `white` |
| Tile em repouso | `white` | `line` | `ink` |
| Tile certo | `pale` | `green` | `ink` |
| Tile errado | `miss` @ 12% | `miss` | `miss` |

Raio: **16** em botões e tiles. Cápsula em pills e barra de progresso.
Altura: tile **84**, CTA **56**.

---

## 4. Feedback

**O feedback é assimétrico, de propósito.**

- **Acerto:** confirma e segue sozinho em 0,62s — bloom (1.0 → 1.09 → 1.0),
  partículas e tom subindo já dizem "certo" três vezes. Pedir um toque de
  confirmação aqui só custaria ritmo (o Duo pede porque lá a resposta é digitada
  ou montada; aqui é 1 toque entre 4).
- **Erro:** sobe o banner `missSoft` com a resposta certa e o botão **ENTENDI**.
  Sem timer — ler leva o tempo que leva, então quem sai é o usuário.
- **Erro (tile):** shake com amplitude decaindo — tropeço, não chacoalhada.
- **Streak:** pill com raio aparece a partir de 2 acertos seguidos.

O que muda: a barra de progresso e o pill agora são sempre `green` fixo.
O gradiente cyan→âmbar por streak sai — a identidade agora é a cor da marca,
não temperatura.

---

## 5. Espaçamento

Margem lateral **20**. Gap da grade **14**. Respiro do rodapé **24**.
Escala de 4 em 4 (4, 8, 12, 16, 20, 24). Nada de valores fora dela.

---

## 6. Movimento

Já calibrado em `Theme.swift`, não mexer:

| Token | Uso |
|---|---|
| `press` (0.16s / 0.70) | Afundar do botão. |
| `snap` (0.30s / 0.62) | Bloom, pill, troca de estado do tile. |
| `settle` (0.45s / 0.80) | Progresso, troca de conta, telas. |

---

## 7. Pendências

- [ ] Tela de mapa/trilha de lições (o "caminho" do Duo).
- [ ] Vidas ou timer.
- [ ] Tela de fim de sessão com placar animado.
