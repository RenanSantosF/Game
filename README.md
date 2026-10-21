# Confronto

Battle royale em 3D para Android, no estilo dos primeiros battle royale de celular. Visual simples, mas puxado pro realista (sem cartoon, sem futurista). Feito em Godot 4.3, leve pra rodar em celular fraco.

## Como é a partida

1. **Sala de espera**: todo mundo aparece no mapa, ninguém leva dano. Dá pra aquecer a mira.
2. **Avião**: o avião cruza o mapa por uma rota sorteada (sempre por cima do mapa). Toque em **SALTAR** quando quiser.
3. **Queda**: queda livre guiada pelo joystick; o paraquedas abre sozinho perto do chão (ou toque em **PARAQUEDAS**).
4. **Loot**: todo mundo começa só com a Glock (e os punhos). Armas, acessórios, coletes, capacetes, mochilas, bandagens e kits ficam nas casas, nas caixas, perto de pedras e na base militar. Quem morre vira uma **caixa** com tudo o que tinha.
5. **Zona**: o círculo azul fecha em 7 etapas; o branco no mapa mostra a próxima. Fora dele você perde vida.
6. **Vitória**: não tem renascimento. O último de pé vence.

50 jogadores por partida: no treino são você + 49 bots. Os bots saltam, pegam loot, saqueiam caixas, se curam, fogem da zona e brigam entre si.

## Conteúdo

- Mapa de 800 m com 23 localidades fictícias e formatos diferentes: vilas redondas, bairros com rua asfaltada, casas espalhadas, fazendas (silos, celeiro, feno), base militar (muro, contêineres, torres de vigia), posto de gasolina, pedreiras, serraria, ruínas, torre de rádio, estação de trem e porto na lagoa
- Morros altos, barrancos, lagoa rasa, linha de trem com vagões, estradas de terra com postes, bosques de pinheiros
- Casas de um e dois andares (com escada e sacada), varandas, muros baixos, cercas, carros e picapes abandonados
- **Pular janela e muro baixo**: chegue perto e toque em PULAR
- Armas reais: Glock 17, Desert Eagle, MP5, UMP-45, M4A1, SCAR-L, AK-47, Remington 870, Kar98k e AWM, além do soco
- Acessórios: coronha (menos coice), carregador estendido, mira holográfica, luneta 4x e silenciador
- Duas armas principais + pistola. Toque na arma que já está na mão pra guardar e correr mais rápido (soco)
- **Mochila**: veja os itens, use, equipe acessórios, largue o que quiser. Mochila grande dobra o espaço
- Itens por perto aparecem na lista do canto direito (rola se tiver muitos); toque pra pegar
- Sons de tudo: passos (dá pra ouvir o inimigo chegando, e eles aparecem no minimapa), tiros por arma, silenciador, pulo, janela, troca de arma, recarga, cura, soco, acerto, abate
- Números de dano subindo, seta discreta mostrando de onde veio o tiro, contador de vivos e abates
- Texturas realistas geradas pelo próprio projeto (grama, terra, pedra, reboco, tijolo, telha, madeira, metal, asfalto, casca, folhagem)

## Configurações

- **Mira assistida**: CONTROLE TOTAL (sem ajuda), GRUDA SEM MIRA (puxa só no tiro sem mirar) ou GRUDA SEMPRE. Arrastar pra cima enquanto atira sobe a mira pra cabeça (capa)
- Sensibilidade geral e mirando, inverter vertical
- **Editar posição dos botões**: arraste cada botão e mude o tamanho
- Gráficos BAIXA/MÉDIA/ALTA, limite de FPS (30/45/60), mostrar FPS, volume

## Desempenho em celular fraco

- Casas de cada localidade e cada tipo de vegetação viram poucas malhas (poucas chamadas de desenho); árvores longe usam um modelo simples e a vegetação distante some em blocos
- Na BAIXA: resolução 60%, sem sombra e sem grama
- Todas as texturas ficam numa só (Texture2DArray comprimida em ETC2)

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
| Atirar | ATIRAR (segurar) | F |
| Saltar do avião / pular | SALTAR / PULAR | Espaço |
| Paraquedas | PARAQUEDAS | Espaço |
| Pular janela / muro | PULAR, de frente pra janela | Espaço |
| Agachar | AGACHAR | Z ou Ctrl |
| Recarregar / mira | RECAR. / MIRA | R / C |
| Trocar arma / guardar | Tocar na arma no canto superior direito | X, 1, 2, 3 |
| Curar | CURAR (mostra bandagens e kits) | H |
| Pegar item | Tocar na lista do canto direito (colete, capacete e mochila pegam sozinhos) | E |
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
