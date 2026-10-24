# Confronto

Battle royale em 3D para Android, no estilo dos primeiros battle royale de celular. Visual simples, mas puxado pro realista (sem cartoon, sem futurista). Feito em Godot 4.3, leve pra rodar em celular fraco.

## Como é a partida

0. **Menu**: palco 3D com o seu boneco no meio (arraste pra girar), menu à esquerda, novidades que vão trocando e botão INICIAR. A cada vez sorteia um cenário (arena acesa, base de guerra ao pôr do sol ou acampamento à noite com fogueira) e toca um rock/metal pesado no lobby (duas faixas CC0 sorteadas, dá pra desligar). O carregamento mostra a arte do jogo com uma barra fina embaixo.
1. **Sala de espera (lobby)**: um pátio cercado fora do mapa, com todo mundo junto (bots também). Ninguém leva dano; você recebe uma M4A1 e uma Glock só pra aquecer a mira (somem ao entrar no avião).
2. **Avião**: o avião cruza o mapa por uma rota sorteada (sempre por cima do mapa). Toque em **SALTAR** quando quiser.
3. **Queda**: queda livre guiada pelo joystick; o paraquedas abre sozinho perto do chão (ou toque em **PARAQUEDAS**).
4. **Loot**: todo mundo começa sem arma e sem equipamento, só com os punhos. Munição não é infinita: cada arma usa um dos 4 tipos (SMG, fuzil, sniper e calibre 12) e a munição aparece do lado das armas e solta pelo mapa. Armas, acessórios, coletes, capacetes, mochilas, bandagens e kits ficam nas casas, nas caixas, perto de pedras e na base militar. Quem morre vira uma **caixa** com tudo o que tinha.
5. **Zona**: o círculo azul fecha em 7 etapas; o branco no mapa mostra a próxima. Fora dele você perde vida.
6. **Vitória**: não tem renascimento. O último de pé vence.

50 jogadores por partida: no treino são você + 49 bots. Os bots saltam, pegam loot e munição, saqueiam caixas, se curam (inclusive no meio da briga, quando perdem você de vista), entram na zona com antecedência (e brigam andando pra dentro dela), saem das casas pela porta e brigam entre si.

## Conteúdo

- Personagem com rig e animações do Mixamo (preparado por tools/prepare_mixamo.gd a partir de models_src/mixamo): skin padrão fixa pra todos (camiseta, bermuda cargo e tênis); parado, parado com rifle, andar com rifle, corrida, corrida rápida, pulo (o pulo correndo com as pernas menos abertas), salto de janela (nunca em escada), queda livre, paraquedas (pendurado), aterrissagem, tiro, reação a tiro, morte, dirigindo e comemoração na vitória; o ritmo dos passos acompanha a velocidade do jogo; braços seguram a arma; arma grande fica nas costas e a pistola sai rápido do coldre
- Árvores com tronco reto e grosso (~1 m, colisão de 0,5 m de raio: protege o personagem do tiro) e copa com folhas; moita do Poly Haven (CC0). (A árvore do Tripo foi testada, mas o tronco ficava com a textura esticada de perto e saiu)
- Avião bimotor com camuflagem e hélices girando (OpenGameArt, CC0)
- Vida 200; colete, capacete, mochila, coronha e carregador com nível 1, 2 e 3 (cor diferente no chão e no ícone); dano de queda só em queda alta
- Granada: segure o botão pra tirar o pino (bipes contando), solte pra jogar; se segurar demais explode na mão; o X guarda de volta; segurando, o braço vai pra trás com a granada na mão, o mesmo dedo anda como o analógico e aparece o começo do arco em pontinhos discretos. Um só tipo de cura: kit médico (ocupa 15 de espaço na mochila)
- Cenário de começo de guerra: casas com rombo na parede, fuligem e telhado queimado, paredes encardidas, ruas com buracos, rachaduras e entulho, barricadas de madeira em X, caixotes militares com arma em cima
- Cinco cidades bem no alto de morro, com rampa longa e suave cheia de cobertura (pedras, sacos de areia, barricadas, caixotes, carcaças) pra trocar tiro subindo e descendo
- Duas cidades com chão de cimento; casas de laje com escada maciça por fora pra subir no teto
- Carros (muscle car da T Allen Studios, CC-BY 4.0, e jipe GAZ-67 da Artie31, CC0, repintados com poeira): esportivo (rápido) e jipe aberto (mais lento, mas sobe morro e anda fora da estrada), cada um com o seu ronco, sem vidro (dá pra ver e acertar quem dirige), rodas com suspensão que acompanham o terreno, barulho de batida (batida não tira vida, só tiro e granada); explodem; botão do carro pra entrar e sair; dá pra atropelar
- Cada cidade com a sua cara (cor das paredes, telhado e um marco no meio: monumento, moinho, ônibus ou caixa d'água) e mais casas
- Casas nunca ficam tortas: o chão fica plano embaixo delas e de todos os objetos; cercas acompanham o terreno
- Armas detalhadas (Ultimate Gun Pack da Quaternius, CC0) com mira 2x, luneta 4x e silenciador encaixados (retículo com tracinhos, sem tela preta em volta) (só essas duas miras; Kar98 e AWM têm luneta 4x própria); dano cai com a distância (SMG e 12 fortes de perto e fracas de longe)
- Colete, capacete e mochila redesenhados, com cor por nível (cores de guerra): 1 verde-oliva, 2 verde-acinzentado, 3 cinza; mochila militar arredondada (lona estufada, tampa, bolsos e fitas)
- Bots se escondem atrás de caixote, muro, carro ou árvore na troca de tiro (abaixam pra recarregar/curar e levantam pra atirar) e erram um pouco mais
- Animações: corrida com as pernas mexendo até pulando, recarga (inclina a arma e troca o pente), kit médico (enrolando o braço)
- Arma baixa e atravessada na frente do corpo sem atirar; saque animado (a arma vem das costas e engatilha) com som de ferrolho de verdade; arma vazia recarrega sozinha ao sacar; tiros mais lentos e mais fortes, com tranco na arma e na câmera
- Recarga com som do começo ao fim (tira o pente, pente novo entra, puxa o ferrolho); silenciador abafado e grave
- Colete justo no corpo com bordas e listras brilhantes na cor do nível (1, 2 ou 3 listras); armas menores nas costas
- Rodovias gastas (rachaduras, remendos, buracos, faixas apagadas, terra na beirada); casas de madeira com tábuas bem marcadas
- Muito loot (do lado de fora 2 a 4 itens a mais espalhados em volta de cada ponto; dentro de casa no máximo 1, pra não lotar o cômodo; arma sempre com munição do lado: 30 balas pra fuzil e SMG, 12 pra pistola, 10 de sniper, 12 cartuchos de 12); armas só brilham se a vaga delas estiver vazia (qual arma é melhor quem decide é você); os recomendados aparecem primeiro na lista; munição só brilha na lista se for de arma equipada e estiver faltando (fuzil/SMG abaixo de 170, sniper abaixo de 20, 12 abaixo de 30; pistola nunca); tocar num colete/capacete/mochila de nível menor troca pelo que você está usando
- Abate: caveira animada no meio da tela (dourada no tiro na cabeça) com estrondo grave
- Escopetas 12 mais lentas e com mais impacto; agachado o tiro fica um pouco mais preciso; pular janela termina com o som do pé no chão
- Paraquedas tipo asa, largo e de pano grosso, abre num tranco bruto (estoura, sacode o corpo e a câmera), de nylon brilhante com células estufadas tremendo no vento e cordas finas em cascata; corpo balança com o vento na queda e no paraquedas
- De longe o mapa aparece inteiro em versão simples (blocos de casas e árvores, serra no horizonte), leve pro celular
- Sem coice na tela; segurando o dedo o tiro abre em 2-3 s (com colete/capacete nível 3, um pouco mais devagar) e a mira abre junto. Mirando, a câmera vai pra primeira pessoa (com ou sem luneta)
- Bots lootam e brigam pouco no começo e ficam agressivos quando sobra pouca gente (final cheio)
- Luz fria e clara de guerra (sem amarelado), cores um pouco lavadas
- Clima de guerra com cor: céu azul com bruma de poeira, verde vivo com manchas queimadas, sombras fundas, colunas de fumaça no horizonte e sons de guerra ao longe (explosões, metralhadora, sirene, jato passando, vento)
- Lugares novos: Aeródromo Carcará (pista de pouso, hangares em arco, torre de controle, tanques de combustível), Pátio dos Galpões (galpões com mezanino e escada, contêineres), Acampamento Sentinela (tendas, casamatas, canhões, ninho de metralhadora, trincheira, arame farpado), Brejo Seco com palafitas de madeira em cima da terra seca ligadas por passarelas, e Chapada Ventania bem no alto (subida longa e suave a pé e de carro) com praça elevada de concreto, escadas e passarela
- Marcas da guerra no mapa todo: postos de controle nas rodovias, tanques queimados, crateras, trincheiras, arame farpado, ouriços de aço, casamatas e canhões
- Asfalto, calçadas, pistas e cimento com colisão de verdade (o pé não afunda); nenhuma estrutura nasce dentro da outra; sem barranco onde as rampas das cidades se encontram
- Texturas de reboco, tijolo, telha, madeira, zinco, concreto, asfalto, grama e terra com fotos CC0 do Poly Haven em 1024 px (tools/atlas_photo.py): casas nítidas e detalhadas
- Vale do Corvo em cima de um deque de concreto de 7 m com escadas largas nos quatro lados (carro não sobe); fazendas com celeiro vermelho com mezanino de feno
- Botão de deitar (rasteja devagar, tiro mais preciso); colete, capacete e mochila militares (oliva, coiote, verde-escuro) com remendo da cor do nível
- Marca de tiro (furo com borda lascada, poeira e lascas), explosão com fogo, poeira em anel, fumaça subindo e queimado no chão
- Mapa de 800 m com 26 localidades fictícias e formatos diferentes: vilas redondas, bairros com ruas curvas, casas espalhadas, fazendas (silos, celeiro, feno), base militar (muro, contêineres, torres de vigia), posto de gasolina, pedreiras, serraria, ruínas, torre de rádio, estação de trem e porto na lagoa
- Relevo suave com subidas longas entre as cidades, duas rodovias de asfalto que cruzam o mapa (com postes, fios e carros), estradas de terra ligando as cidades às rodovias, plantações cercadas, linha de trem com vagões, lagoa rasa (água na canela, sem nadar)
- Árvores pequenas e ralas (dá pra ver através), sem flutuar em barranco
- Casas quase todas térreas (algumas de dois andares, com escada e sacada), varandas, muros baixos, cercas e carcaças de carro queimadas (amassadas, sem rodas, chão preto e destroços em volta: dá pra ver de longe que não anda)
- **Pular janela e muro baixo**: chegue perto e toque em PULAR. Pulando da janela de cima, cai, faz barulho e fica ~1 s sem andar
- Armas reais: Glock 17, Desert Eagle, MP5, UMP-45, M4A1, SCAR-L, AK-47, Remington 870, M1014 (escopeta 12 semiautomática), Kar98k e AWM, além do soco
- Acessórios: coronha (menos coice), carregador estendido, mira holográfica, luneta 4x e silenciador
- Duas armas principais + pistola. Painel de armas como no FF: a da mão grande em cima, as outras pequenas embaixo (ícones brancos com o nome). Toque na arma da mão pra guardar
- Botão de **correr** do lado do minimapa: só com o joystick anda mais devagar; com ele corre (de mãos livres corre mais). No ar não dá pra mudar a direção do pulo
- **Mochila** níveis 1, 2 e 3 por quantidade (cada item pesa: munição pouco, kit e colete mais). Tela da mochila com ícones: toque num item pra usar/equipar/largar, ou **arraste o acessório até a arma** pra equipar e da arma pra mochila pra tirar; arraste pra fora da mochila pra largar. Tocar fora fecha
- Itens por perto aparecem numa faixa horizontal embaixo (5 por vez; arraste pro lado pra ver mais); toque pra pegar
- Bússola no topo (N, NE, L, SE, S, SO, O, NO) e minimapa com uma seta só (pra onde a câmera olha)
- Botões só com ícones
- Sons gravados de verdade (bibliotecas CC0, veja `sounds/CREDITOS.txt`): cada arma tem o seu tiro; passos diferentes na grama, no cascalho e no piso; silenciador com o "tiu" abafado; vento na queda livre e outro no paraquedas; pouso; acerto, tiro na cabeça e abate novos
- Números de dano subindo, seta discreta mostrando de onde veio o tiro, contador de vivos e abates
- Texturas realistas geradas pelo próprio projeto (grama, terra, pedra, reboco, tijolo, telha, madeira, metal, asfalto, casca, folhagem)

## Editor de cenário (pelo celular)

No menu, **EDITAR MAPA** abre o mapa sem ninguém, com câmera livre:

- Analógico (esquerda) anda; arrastar no lado direito olha em volta; ▲ ▼ sobe e desce; x1/x4 muda a velocidade
- Toque rápido num objeto (casa, muro, cerca, barricada, caixote, carro, pedra, árvore, moita...) pra selecionar
- Painel: FRENTE/TRÁS/ESQ/DIR move (segurar repete), GIRA, SOBE/DESCE, MAIOR/MENOR, CHÃO (encosta no chão), AQUI (leva pra onde a mira do meio aponta), DUPLICAR, APAGAR
- INCLINA ▲▼◄► inclina o objeto (RETO tira a inclinação)
- **+ ADICIONAR** coloca peças novas na mira do meio; **DESFAZER** volta o último passo
- **▶ JOGAR AQUI** põe o boneco onde a mira aponta, com colete/capacete/mochila nível 3, munição e todas as armas e acessórios no chão em volta; ninguém perde vida e o pente enche sozinho. **+3 BOTS** chama bots que não morrem; **✈ VOAR** volta pra câmera livre
- Tudo fica salvo no aparelho e já vale no treino (o minimapa acompanha as casas). **COPIAR** copia as alterações em texto: cole no chat do Claude pra elas irem pro jogo de todo mundo (`data/map_edits.json`). **LIMPAR** (toque duas vezes) apaga as alterações do aparelho
- Partida em rede usa só as alterações que vão no jogo, pra todo mundo ver o mesmo mapa

## Novidades da 0.24.2 (otimização)

- Jipe (carro e carcaças) com versão simplificada de longe: 14,5 mil → 4,2 mil triângulos a partir de 45 m (tools/prepare_car_lod.gd)
- Boneco com versão simplificada a partir de 20 m: 10,3 mil → 5,7 mil triângulos, sem buraco na roupa (tools/prepare_soldier_lod.gd)
- Postes, fios e placas da rodovia eram uma malha do tamanho do mapa desenhada inteira: agora em pedaços de 100 m
- Molduras, parapeitos, tábuas e pedacinhos de entulho somem a partir de 130 m (sacos de areia, caixotes e barris continuam)
- Terreno com metade da resolução nos blocos longe (com "saia" nas bordas, sem fresta)
- Resultado: 40% a 57% menos triângulos que a 0.24.0 nos mesmos pontos do mapa e o quadro ~15% mais rápido no teste

## Novidades da 0.24.1 (otimização)

- Celular com limite de 30 FPS: a física roda 30 vezes por segundo (antes eram 2 passos de física por quadro mostrado)
- Árvores com shader próprio: tronco e folhas numa chamada de desenho só, casca com 1 leitura de textura (antes 3) e luz por vértice
- Cenário de longe de cada cidade num bloco só, trocando com a cidade detalhada na hora certa (sem buraco nem piscar)
- Estradas, pedras, moitas e troncos em pedaços maiores; pneus soltos e fumaça de carro parado não desenham de longe/à toa
- Resultado: 24% a 37% menos chamadas de desenho nos mesmos pontos do mapa, com o mesmo visual

## Novidades da 0.24.0

- Corrigido o boneco "pendurado" embaixo do avião (era o seu próprio boneco, que a câmera deixava visível)
- Não dá pra atirar pulando janela; com o kit médico não dá pra atirar, e trocar de arma cancela a cura
- Munição total da arma aparece mesmo com ela guardada; colete e capacete só diminuem o dano (sem barra extra de vida)
- Carro desliga o motor quando você sai; carro andando perto aparece no minimapa com um carrinho laranja discreto; carro passa por cima de coisas baixas sem "agarrar"
- Pular da altura de uma casa já dá a queda com a mão no chão; granada sempre recomendada
- Tela de equipar: arma grande no meio e os acessórios em volta, no lugar de cada um (mira em cima, silenciador na frente, coronha atrás, pente embaixo); o item some da mochila assim que você começa a arrastar
- Recarga com som mais grave e encorpado; M4 e SCAR um pouco mais lentas e com o primeiro tiro levemente atrasado
- Mapa e minimapa: mar azul fora da ilha (no lobby também), lago com a forma de verdade; sem fumaça no mar; menos serrilhado/piscando na queda
- Janelas das casas não ficam mais na frente da escada nem da parede interna
- Árvore antiga de volta (a nova bugava o tronco de perto)

## Configurações

- **Mira assistida**: CONTROLE TOTAL (sem ajuda), GRUDA SEM MIRA (puxa só no tiro sem mirar) ou GRUDA SEMPRE (padrão). Arrastar pra cima enquanto atira sobe a mira pra cabeça (capa)
- Sensibilidade geral e mirando, inverter vertical
- **Editar posição dos botões**: arraste cada botão e mude o tamanho
- Botões com ícone da pose do boneco (de pé, agachado, deitado, pulando, correndo) e **transparência dos botões** ajustável
- Gráficos BAIXA/MÉDIA/ALTA (sem sombras em nenhuma; a distância de visão é a mesma em todas, sem opção), grama, limite de FPS (30/45/60), mostrar FPS, mostrar sangue, volume

## Desempenho em celular fraco

- Casas de cada localidade e cada tipo de vegetação viram poucas malhas (poucas chamadas de desenho); árvores longe usam um modelo simples e a vegetação distante some em blocos
- Na BAIXA: resolução 50% e sem grama
- Ilha cercada de mar até o horizonte (praia descendo pra água); quem entra no mar fundo se afoga
- **Ajuste pro aparelho (só na primeira vez)**: ao abrir pela primeira vez o jogo vê a placa de vídeo e a memória do celular e escolhe a qualidade (fraco: BAIXA, 30 FPS, sem grama, visão curta; médio: MÉDIA; forte: ALTA). Na primeira partida confere o FPS no lobby uma vez e, se não aguentar, desce um nível. Depois disso não mexe mais sozinho (você muda nas configurações)
- Malhas com níveis de detalhe (boneco, armas, carros) trocam pro simples um pouco antes de longe
- Céu em degradê leve, sem mapa de reflexo; árvores com material simples (sem brilho); bonecos longe ou fora da tela animam menos vezes; bots longe da câmera calculam movimento e decisões em quadros alternados; minimapa redesenhado 20x por segundo
- Itens no chão só existem perto de você (carregam aos poucos em blocos de 40 m), então dá pra ter muito mais loot sem pesar
- Câmera com faixa de profundidade ajustada e sem sobreposição de cenário perto/longe: nada de casas e avião piscando
- Botões da tela desenhados uma vez e guardados como imagem (a tela desenha bem menos por quadro)
- Clarão de tiro e explosão sem luz dinâmica (luz extra redesenha tudo em volta no celular); efeitos pré-carregados no começo pra não travar no primeiro tiro
- Terreno em blocos (só desenha o que está na frente), sombreamento do chão e das casas mais simples, bots longe de todo mundo calculam o movimento 1 vez a cada 3 quadros
- Todas as texturas ficam numa só imagem (atlas 2D com borda, comprimida)
- No chão as árvores de longe somem (só aparecem até ~180 m; do avião e na queda dá pra ver a ilha toda pra escolher onde cair)
- Muita gente junta (cidade lotada, lobby): quem não está colado na câmera anima menos vezes e os efeitos de tiro dos outros têm limite por quadro

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
scripts/map_editor.gd  editor de cenário dentro do jogo
scripts/map_edits.gd   ajustes feitos à mão no mapa (data/map_edits.json + arquivo do aparelho)
scripts/hud.gd         controles de toque, barra de armas, lista de itens, mochila, mapa, editor de botões
scripts/settings_ui.gd tela de configurações
scripts/cfg.gd         configurações salvas no aparelho
scripts/sfx.gd         sons
scripts/weapons.gd     dados e modelos das armas, acessórios e itens
scripts/mb.gd          monta várias peças numa malha só (desempenho)
shaders/               material do mundo, terreno e água
tools/gen_assets.py    gera textures/atlas.png e sounds/*.wav (python3 + numpy + pillow)
tools/prepare_guns.gd  converte as armas CC0 de models_src/guns pra models/guns/*.res e gera scripts/gun_info.gd
tools/prepare_cars2.gd converte o muscle car e o jipe de models_src pra models/car*.res
tools/prepare_trees.gd árvores do Poly Haven (com tools/decimate_trees.py e tools/make_leaf_cards.py) pra models/trees/
tools/prepare_tripo_tree.gd + tools/tripo_tree.py: árvore do Tripo (FBX) -> atlas de textura e malha reduzida (models/trees/tripo*.res)
tools/prepare_plane.gd avião de models_src/plane pra models/plane.scn
tools/prepare_man.gd   reduz o personagem (com tools/decimate_man.py e tools/man_mask.py) pra models/soldier.scn
tools/render_keyart.gd arte da tela de carregamento (depois tools/keyart_post.py -> art/loading.jpg)
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
