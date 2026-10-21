# Confronto

Battle royale em 3D para Android, no estilo dos primeiros battle royale de celular. Visual simples, mas puxado pro realista (sem cartoon, sem futurista). Feito em Godot 4.3, leve pra rodar em celular fraco.

## Como é a partida

1. **Sala de espera**: todo mundo aparece no mapa, ninguém leva dano. Dá pra aquecer a mira.
2. **Avião**: o avião cruza o mapa por uma rota sorteada. Toque em **SALTAR** quando quiser (se não saltar, é jogado no fim da rota).
3. **Queda**: queda livre guiada pelo joystick; o paraquedas abre sozinho perto do chão (ou toque em **PARAQUEDAS**).
4. **Loot**: todo mundo começa só com a Glock. Armas, coletes, capacetes e kits médicos ficam no chão das casas, perto de caixotes e pedras. Quem morre deixa tudo cair.
5. **Zona**: o círculo azul fecha em 6 etapas; o branco no mapa mostra a próxima. Fora dele você perde vida (cada vez mais).
6. **Vitória**: não tem renascimento. O último de pé vence. Morreu? Assiste quem te matou (botão PRÓXIMO troca).

20 jogadores por partida: no treino são você + 19 bots. Os bots saltam, pegam loot, se curam, fogem da zona e brigam entre si.

## Conteúdo

- Mapa de 640 m com 13 vilas/fazendas com nome (Vila Nova, Cruzeiro, Pedreira, São Miguel...), estradas de terra, morros, bosques, moitas (escondem, mas a bala passa), pedras e carros abandonados (seguram bala)
- Casas com telhado de duas águas, sem porta e sem móveis; casas de dois cômodos e galpões
- Armas reais: Glock 17, Desert Eagle, MP5, UMP-45, M4A1, SCAR-L, AK-47, Remington 870, Kar98k e AWM
- Colete (absorve metade do dano), capacete (reduz tiro na cabeça) e kit médico (+45 de vida em 3 s)
- Agachar (mira melhor, mais difícil de ver de longe), mira com zoom, luneta nas de precisão
- Indicador de onde veio o tiro, marcador de acerto, minimapa e mapa grande (toque no minimapa)

## Desempenho em celular fraco

- Menu **GRÁFICOS**: BAIXA (resolução 60%, sem sombra, sem grama, visão curta), MÉDIA (padrão) e ALTA
- Casas de cada vila e cada tipo de vegetação viram poucas malhas (poucas chamadas de desenho); vegetação distante some em blocos
- Renderizador "Compatibilidade" (OpenGL ES 3), sem texturas pesadas: uma textura de ruído de 128 px serve pro jogo todo

## Como baixar o APK

Cada vez que você manda alteração pro GitHub (qualquer branch), o próprio GitHub compila o APK sozinho, em uns 5 a 10 minutos.

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
| Andar / guiar a queda | Arrastar o lado esquerdo da tela | WASD |
| Olhar e mirar | Arrastar o lado direito (ou o próprio botão ATIRAR) | Arrastar com o mouse |
| Atirar | ATIRAR (segurar) | F |
| Saltar do avião / pular | SALTAR / PULAR | Espaço |
| Paraquedas | PARAQUEDAS | Espaço |
| Agachar | AGACHAR | Z ou Ctrl |
| Recarregar / trocar arma / mira | Botões da direita | R / Q / C |
| Curar | CURAR (mostra quantos kits tem) | H |
| Pegar arma | PEGAR (aparece perto da arma). Colete, capacete e kit pegam sozinhos | E |
| Mapa grande | Tocar no minimapa | M |

## Servidor na internet

Qualquer VPS Linux serve. Opções:

- **Oracle Cloud "Always Free"**: tem região em São Paulo e é gratuita. Escolha uma máquina Ampere (ARM). O script já baixa a versão ARM do Godot.
- **VPS paga em São Paulo** (Hostinger, Contabo, Magalu Cloud, etc.), de R$ 25 a 50 por mês.

Na VPS:

```bash
git clone https://github.com/SEU_USUARIO/SEU_REPO.git confronto
cd confronto
./server/rodar_servidor.sh 16    # 16 = bots por partida (completa até 20 com os jogadores)
```

Libere a porta **7777 UDP** no firewall da VPS (e, na Oracle, também em "Security List").

Pra deixar o servidor ligado mesmo depois de fechar o terminal, use `tmux` ou crie um serviço do `systemd`.

## Estrutura

```
scripts/main.gd     menu, fluxo da partida (sala, avião, zona, vencedor), câmera, efeitos e servidor (dano, loot)
scripts/player.gd   personagem (modelo, animação, queda, paraquedas) e IA dos bots
scripts/world.gd    geração do mapa (terreno, vilas, estradas, vegetação, minimapa)
scripts/hud.gd      controles de toque, mira, vida/colete, minimapa, mapa grande
scripts/weapons.gd  dados e modelos das armas e itens
scripts/mb.gd       monta várias peças numa malha só (desempenho)
scripts/util.gd     materiais e textura de detalhe
.github/workflows/apk.yml   compilação automática do APK
```

Para balancear uma arma, mude os números em `scripts/weapons.gd`. O tempo e o tamanho de cada fechamento da zona ficam em `ZONES`, no começo de `scripts/main.gd`.

## Testes (PC/Linux)

```bash
godot --headless --path . -- --server --bots-only --bots=19 --timescale=8 --quit-after=70   # partida só de bots, acelerada
godot --headless --path . -- --server --bots=8                                              # servidor com 8 bots
godot --headless --path . -- --autojoin=127.0.0.1 --autojump=0.5                            # cliente entrando e saltando
godot --path . -- --autotrain                                                               # treino direto
```
