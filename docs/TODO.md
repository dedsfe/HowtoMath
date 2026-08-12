# A fazer

Despejo do que observamos no Duolingo e do que queremos construir.
Nada aqui é compromisso — é a lista de onde puxar o próximo trabalho.

## Lição — combo

- [x] Barra de progresso fica **dourada** e solta raiozinhos enquanto o combo dura
- [x] Texto **"COMBO x6"** acima da barra — aparece só no acerto, some antes do próximo
- [x] Dispara de 5 em 5 acertos seguidos; erra, zera
- ~~Raio grande cruzando a tela~~ — decidido não fazer
- [ ] Verificar o **som** e o **feedback háptico** do disparo do combo

## Lição — mascote

- [ ] De 5 em 5 seguidos, o mascote entra em **pose de super-herói** e recarrega a vida
- [ ] Áudio forte acompanhando a entrada
- [ ] **Sons de comemoração e de tristeza** do próprio personagem (grunhidos, não fala)

## Lição — progresso

- [ ] Barra já começa **com um pouco preenchido** quando a lição abre, em vez de zero
- [ ] Ao fim da sequência normal: se acertou tudo → oferece **modo mais difícil**;
      se errou alguma → entra na rodada de correção ("vamos resolver")

## Card de sair

- [x] Mascote fora de sincronia — era um `transaction` meu no Creature limpando a animação da subárvore
- [x] Fundo atrás **muito mais escuro** (0.45 → 0.78)
- [x] Removidos **grabber**, **arrasto** e **toque no scrim**; só os dois botões saem
- [x] Mascote da lição **sai enquanto o card sobe** — não existem mais duas cópias na tela

## Tela de fim de lição

- [x] Tela 1: celebração (título, raios, confete, botão)
- [ ] Trocar o `.celebrate` pelo combo **`.walkIn` → `.joy`**: entra andando do fundo e trava na cara de emoção
- [ ] Tela 2: **cards de estatística** — Total de XP, Precisão (%), Tempo — cada um com cor e ícone próprios
- [ ] Subtítulo abaixo do título, com frase de personagem ("Não que eu jamais tenha duvidado de você.")
- [ ] Botão de **compartilhar** ao lado do CTA
- [ ] Contadores dos cards **subindo** até o valor final em vez de aparecerem prontos

## Feel

- [ ] **Háptica precisa em tudo** — hoje só existe em acerto, erro e toque
- [ ] Revisar o sound design inteiro; o do Duolingo é a referência a bater
- [ ] Avaliar troca de fonte mantendo a identidade (peso pesado + arredondada)

## Dúvidas em aberto

- Confete em duas camadas resolve profundidade ou precisa de mais planos?
- Vale ter um estado de mascote por tela, ou isso vira zoológico?
