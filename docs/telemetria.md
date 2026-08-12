# Telemetria — o que puxar e o que nunca puxar

App de matemática para crianças. Isso muda tudo: o limite aqui não é técnico, é
o que a Apple aceita publicar e o que a LGPD deixa guardar sobre um menor.

## A regra que decide tudo

**Um campo só entra se existe uma decisão que ele muda.** "Pode ser útil um dia"
não é motivo — é peso morto que ainda por cima aumenta a superfície de risco.
E o corolário: **não se grava o que dá para derivar.**

Hora do dia, se a soma tem "vai um", se a subtração pede empréstimo, faixa de
magnitude dos números, intervalo desde a última vez que a pessoa viu `7+8` —
tudo isso sai de `left_operand`, `right_operand`, `operation` e `finished_at`.
Gravar cada um como coluna própria é criar quatro maneiras de a mesma verdade
ficar dessincronizada.

## O que puxar

### Já está gravando

| Campo | A pergunta que ele responde |
|---|---|
| `left/right/operation/answer` | Qual conta especificamente trava a pessoa |
| `chosen` | Para qual erro ela vai quando erra |
| `correct`, `is_retry` | Aprendeu na segunda vez ou só chutou de novo |
| `position` | A precisão cai no fim da lição (cansaço) |
| `seconds` | Ficou mais rápida naquele tipo de conta |
| `bad_pairs` | Segurar várias somas ao mesmo tempo é o gargalo |
| `best_streak`, `misses`, `xp` | Resumo da corrida |

### Vale adicionar (nesta ordem)

1. **`hesitation_seconds`** — tempo até o primeiro toque, separado do tempo até
   a resposta. É a diferença entre "não sabia" e "sabia e estava distraída", e
   sem ele `seconds` é uma média de duas coisas diferentes.
2. **`was_backgrounded`** — o app foi para segundo plano durante a questão.
   Sem essa flag, uma criança que largou o celular por sete minutos envenena
   toda média de tempo que a gente for calcular depois. **É o campo mais
   importante da lista** — ele não gera insight, ele impede que todos os outros
   mintam.
3. **`options`** — as alternativas que estavam na tela. Sem elas, `chosen` não
   diz se o distrator existia; com elas dá para saber qual isca funciona.
4. **`streak_at_answer`** — a sequência no momento da resposta. Responde "erra
   mais quando está embalada" (pressão) — um dos poucos dados que vira conselho
   direto ao usuário.
5. **`device_model` + `os_version`** — na lição, não na tentativa. Só para
   separar "o app está lento" de "a pessoa está pensando".

### O que isso permite depois

- **Curva de esquecimento por fato.** Duolingo usa *Half-Life Regression*: com
  o histórico de acertos por item e o intervalo entre revisões, dá para prever
  quando `7+8` vai ser esquecido e trazer de volta na hora certa. Já temos os
  dados — falta só o algoritmo.
- **Diagnóstico honesto ao usuário.** "Suas subtrações com empréstimo levam o
  dobro do tempo" é conselho. "Você fez 12 lições" é vaidade.

## O que NUNCA puxar

Guardrail duro. Nada aqui entra, nem com consentimento, nem "só pra debug":

- **Identidade**: nome, e-mail, telefone, foto, data de nascimento, idade,
  contatos, escola.
- **Localização**: GPS, cidade, CEP. IP também não — é dado pessoal na LGPD e
  identificador de dispositivo para a Apple.
- **IDFA / ATT / IDFV / fingerprint** de aparelho. Em app infantil o IDFA é
  proibição explícita da Apple.
- **Qualquer SDK de analytics de terceiro** — Firebase Analytics, Amplitude,
  Mixpanel, Meta SDK. Guideline 1.3: apps na categoria Kids não podem incluir
  publicidade ou analytics de terceiros. Backend próprio (Supabase) é
  processador dos nossos dados, não SDK de terceiro no app — é justamente por
  isso que a arquitetura atual passa.
- **Texto livre** digitado pela criança.

## Guardrails técnicos

1. **Login anônimo, sem PII.** `user_id` é um UUID que não tem nada atrás dele.
   Se um dia vazar, vazou um número.
2. **RLS por dono, append-only.** Feito e testado: ninguém lê nem escreve a
   linha de outro, e nem o próprio dono reescreve o passado.
3. **Local é a fonte da verdade.** O envio é uma cópia. O app nunca espera a
   rede para mostrar um número, e uma falha de upload não pode custar uma lição.
4. **Fila com retry.** O que não subiu fica marcado e vai na próxima. Sem isso
   toda estatística fica com buraco de metrô.
5. **Retenção.** Tentativa individual não precisa viver para sempre: passado um
   ano, o agregado por lição basta. Menos dado guardado, menos dano possível.
6. **Botão de apagar meus dados.** Exigência da LGPD (art. 18) e da Apple
   (5.1.1(v)) para quem cria conta — e a nossa é criada sozinha, no primeiro
   abrir. Precisa existir **antes** de publicar.
7. **Nutrition Label honesta** no App Store Connect: *Usage Data / Product
   Interaction*, **não vinculado à identidade**, **não usado para rastreamento**.
   Declarar errado é rejeição na certa.
8. **LGPD art. 14.** Dado de criança exige consentimento específico e destacado
   de um responsável, e o melhor interesse da criança prevalece. Como não
   coletamos nada que identifique ninguém, o risco é baixo — mas se um dia
   entrar login com Apple e e-mail real, essa conversa muda de figura e o fluxo
   de consentimento passa a ser obrigatório.

## Fontes

- [App Review Guidelines — Apple](https://developer.apple.com/app-store/review/guidelines/)
- [Kids apps: ads, analytics e Sign in with Apple](https://www.appstorereviewguidelineshistory.com/articles/2019-09-14-kids-apps-ads-analytics-and-sign-in-with-apple/)
- [Learning analytics — o que medir](https://countly.com/blog/learning-analytics-explained-how-edtech-platforms-measure-student-engagement-and-outcomes)
