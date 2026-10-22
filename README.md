# Confronto

Battle royale em 3D para Android, no estilo dos primeiros battle royale de celular. Visual simples, mas puxado pro realista (sem cartoon, sem futurista). Feito em Godot 4.3, leve pra rodar em celular fraco.

## Como é a partida

0. **Menu**: palco 3D com o seu boneco no meio (arraste pra girar), menu à esquerda e botão INICIAR. O carregamento mostra uma barra com as etapas.
1. **Sala de espera (lobby)**: um pátio cercado fora do mapa, com todo mundo junto (bots também). Ninguém leva dano; você recebe uma M4A1 e uma Glock só pra aquecer a mira (somem ao entrar no avião).
2. **Avião**: o avião cruza o mapa por uma rota sorteada (sempre por cima do mapa). Toque em **SALTAR** quando quiser.
3. **Queda**: queda livre guiada pelo joystick; o paraquedas abre sozinho perto do chão (ou toque em **PARAQUEDAS**).
4. **Loot**: todo mundo começa sem arma e sem equipamento, só com os punhos. Munição não é infinita: cada arma usa um tipo (9 mm, 5.56, 7.62, calibre 12) e a munição aparece do lado das armas e solta pelo mapa. Armas, acessórios, coletes, capacetes, mochilas, bandagens e kits ficam nas casas, nas caixas, perto de pedras e na base militar. Quem morre vira uma **caixa** com tudo o que tinha.
5. **Zona**: o círculo azul fecha em 7 etapas; o branco no mapa mostra a próxima. Fora dele você perde vida.
6. **Vitória**: não tem renascimento. O último de pé vence.

50 jogadores por partida: no treino são você + 49 bots. Os bots saltam, pegam loot e munição, saqueiam caixas, se curam (inclusive no meio da briga, quando perdem você de vista), entram na zona com antecedência (e brigam andando pra dentro dela), saem das casas pela porta e brigam entre si.

## Conteúdo

- Boneco animado (modelo feito no Meshy, reduzido pra celular): anda, corre, pula, agacha, morre; braços seguram a arma
- Vida 200; colete, capacete, mochila, coronha e carregador com nível 1, 2 e 3 (cor diferente no chão e no ícone); dano de queda só em queda alta
- Granada (botão aparece quando você tem), energético, mais kits e bandagens
- Duas cidades com chão de cimento; casas de laje com escada por fora pra subir no teto
- Carros: esportivo (rápido) e picape (mais lenta), com rodas girando que acompanham o terreno; explodem com tiro ou granada espalhados perto das cidades; botão do carro pra entrar e sair; dá pra atropelar
- Cada arma com coice e dispersão própria: os primeiros tiros são precisos e, segurando o dedo, o tiro abre (a AK abre muito)
- Mapa de 800 m com 23 localidades fictícias e formatos diferentes: vilas redondas, bairros com rua asfaltada, casas espalhadas, fazendas (silos, celeiro, feno), base militar (muro, contêineres, torres de vigia), posto de gasolina, pedreiras, serraria, ruínas, torre de rádio, estação de trem e porto na lagoa
- Relevo suave com subidas longas entre as cidades, duas rodovias de asfalto que cruzam o mapa (com postes, fios e carros), estradas de terra ligando as cidades às rodovias, plantações cercadas, linha de trem com vagões, lagoa rasa (água na canela, sem nadar)
- Árvores pequenas e ralas (dá pra ver através), sem flutuar em barranco
- Casas quase todas térreas (algumas de dois andares, com escada e sacada), varandas, muros baixos, cercas, carros e picapes abandonados
- **Pular janela e muro baixo**: chegue perto e toque em PULAR. Pulando da janela de cima, cai, faz barulho e fica ~1 s sem andar
- Armas reais: Glock 17, Desert Eagle, MP5, UMP-45, M4A1, SCAR-L, AK-47, Remington 870, M1014 (escopeta 12 semiautomática), Kar98k e AWM, além do soco
- Acessórios: coronha (menos coice), carregador estendido, mira holográfica, luneta 4x e silenciador
- Duas armas principais + pistola. Painel de armas como no FF: a da mão grande em cima, as outras pequenas embaixo (ícones brancos com o nome). Toque na arma da mão pra guardar
- Botão de **correr** do lado do minimapa: só com o joystick anda mais devagar; com ele corre (de mãos livres corre mais). No ar não dá pra mudar a direção do pulo
- **Mochila** níveis 1, 2 e 3 (sem mochila cabe pouco). Tela da mochila com ícones: toque num item pra usar/equipar/largar, ou **arraste o acessório até a arma** pra equipar e da arma pra mochila pra tirar; arraste qualquer coisa pra lixeira pra largar. Tocar fora fecha
- Itens por perto aparecem numa faixa horizontal embaixo (5 por vez; arraste pro lado pra ver mais); toque pra pegar
- Bússola no topo (N, NE, L, SE, S, SO, O, NO) e minimapa com uma seta só (pra onde a câmera olha)
- Botões só com ícones
- Sons gravados de verdade (bibliotecas CC0, veja `sounds/CREDITOS.txt`): cada arma tem o seu tiro; passos diferentes na grama, no cascalho e no piso; silenciador com o "tiu" abafado; vento na queda livre e outro no paraquedas; pouso; acerto, tiro na cabeça e abate novos
- Números de dano subindo, seta discreta mostrando de onde veio o tiro, contador de vivos e abates
- Texturas realistas geradas pelo próprio projeto (grama, terra, pedra, reboco, tijolo, telha, madeira, metal, asfalto, casca, folhagem)

## Configurações

- **Mira assistida**: CONTROLE TOTAL (sem ajuda), GRUDA SEM MIRA (puxa só no tiro sem mirar) ou GRUDA SEMPRE (padrão). Arrastar pra cima enquanto atira sobe a mira pra cabeça (capa)
- Sensibilidade geral e mirando, inverter vertical
- **Editar posição dos botões**: arraste cada botão e mude o tamanho
- Gráficos BAIXA/MÉDIA/ALTA, sombras, texturas detalhadas, grama, distância de visão, limite de FPS (30/45/60), mostrar FPS, mostrar sangue, volume

## Desempenho em celular fraco

- Casas de cada localidade e cada tipo de vegetação viram poucas malhas (poucas chamadas de desenho); árvores longe usam um modelo simples e a vegetação distante some em blocos
- Na BAIXA: resolução 60%, sem sombra e sem grama
- Todas as texturas ficam numa só imagem (atlas 2D com borda, comprimida)

## Como baixar o APK

Cada vez que você manda alteração pro GitHub (branch `main`), o próprio GitHub compila o APK sozinho, em uns 5 a 10 minutos.

- Acompanhe em **Actions** no repositório
- Quando terminar, baixe em **Releases → Última versão → confronto.apk**
- Link direto: `https://github.com/SEU_USUARIO/SEU_REPO/releases/download/ultima/confronto.apk`

Na primeira instalação, o Android pede pra liberar "instalar apps desconhecidos" no navegador. A chave de assinatura é sempre a mesma, então as próximas versões instalam por cima, sem precisar desinstalar.

## Como jogar com amigos

**No mesmo Wi-Fi (grátis):** um celular toca em *Criar sala no Wi-Fi*, e o jogo mostra o IP. Os outros digitam esse IP e tocam em *Entrar*. Quem criou a sala toca em **COMEÇAR**; as vagas que sobram até 20 viram bots.

**Pela internet:** precisa de um servidor ligado 24h (veja abaixo). Todo mundo digita o IP do servidor e entra. A partida começa 45 s depois que alguém entra, e uma nova começa sozinha 15 s depois de acabar. Quem entra no meio assiste e joga a próxima.

## Controles

| Ação | Celular | PC (teste) |
|---|---|---|
| Andar / guiar a queda (o personagem vira pra onde anda) | Arrastar o lado esquerdo da tela | WASD |
| Olhar e mirar | Arrastar o lado direito (ou o próprio botão ATIRAR) | Arrastar com o mouse |
| Atirar | Botão da mira (segurar) | F |
| Correr | Botão do bonequinho correndo, do lado do minimapa | — |
| Saltar do avião / pular | SALTAR / PULAR | Espaço |
| Paraquedas | PARAQUEDAS | Espaço |
| Pular janela / muro | PULAR, de frente pra janela | Espaço |
| Agachar | AGACHAR | Z ou Ctrl |
| Recarregar / mira | RECAR. / MIRA | R / C |
| Trocar arma / guardar | Tocar na arma no canto superior direito | X, 1, 2, 3 |
| Curar | CURAR (mostra bandagens e kits) | H |
| Pegar item | Tocar na faixa de itens embaixo (colete, capacete e mochila pegam sozinhos) | E |
| Mochila | MOCHILA | Tab |
| Mapa grande | Tocar no minimapa | M |

## Servidor na internet

Qualquer VPS Linux serve. Opções:

- **Oracle Cloud "Always Free"**: tem região em São Paulo e é gratuita. Escolha uma máquina Ampere (ARM). O script já baixa a versão ARM do Godot.
- **VPS paga em São Paulo** (Hostinger, Contabo, Magalu Cloud, etc.), de R$ 25 a 50 por mês.

Na VPS:

```bash
git clone https://github.com/SEU_USUARIO/SEU_REPO.git confronto
cd confronto
./server/rodar_servidor.sh 40    # 40 = bots por partida (completa até 50 com os jogadores)
```

Libere a porta **7777 UDP** no firewall da VPS (e, na Oracle, também em "Security List").

Pra deixar o servidor ligado mesmo depois de fechar o terminal, use `tmux` ou crie um serviço do `systemd`.

## Estrutura

```
scripts/main.gd        menu, fluxo da partida, câmera, mira assistida, servidor (dano, loot, mochila, caixas)
scripts/player.gd      personagem (modelo, animação, pulo de janela, queda) e IA dos bots
scripts/world.gd       relevo, localidades, estradas, lagoa, trem, vegetação, minimapa
scripts/build.gd       construções e objetos (casas, sobrados, galpões, torres, carros...)
scripts/hud.gd         controles de toque, barra de armas, lista de itens, mochila, mapa, editor de botões
scripts/settings_ui.gd tela de configurações
scripts/cfg.gd         configurações salvas no aparelho
scripts/sfx.gd         sons
scripts/weapons.gd     dados e modelos das armas, acessórios e itens
scripts/mb.gd          monta várias peças numa malha só (desempenho)
shaders/               material do mundo, terreno e água
tools/gen_assets.py    gera textures/atlas.png e sounds/*.wav (python3 + numpy + pillow)
.github/workflows/apk.yml   compilação automática do APK
```

Para balancear uma arma, mude os números em `scripts/weapons.gd`. O tempo e o tamanho de cada fechamento da zona ficam em `ZONES`, no começo de `scripts/main.gd`.

## Testes (PC/Linux)

```bash
godot --headless --path . -- --server --bots-only --bots=49 --timescale=6 --quit-after=80   # partida só de bots, acelerada
godot --headless --path . -- --server --bots=8                                              # servidor com 8 bots
godot --headless --path . -- --autojoin=127.0.0.1 --autojump=0.5                            # cliente entrando e saltando
godot --path . -- --autotrain                                                               # treino direto
```
