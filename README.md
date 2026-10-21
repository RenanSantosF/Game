# Confronto

Jogo de tiro online em 3D para Android, simples, no estilo dos primeiros battle royale de celular. Feito em Godot 4.3.

- 5 cidadezinhas com 5 ou 6 casas cada (sem porta e sem móveis), próximas umas das outras
- Morros, árvores, moitas (escondem, mas a bala passa) e pedras (seguram bala)
- Armas reais: Glock 17, MP5, M4A1, AK-47, Remington 870 e AWM
- Todo mundo nasce de Glock. As outras armas ficam no chão das casas e voltam 25 s depois de pegas
- Mata-mata: morreu, volta em 4 segundos. O placar mostra os 3 primeiros
- Modo treino offline contra bots

## Como baixar o APK

Cada vez que você manda alteração pro GitHub (branch `main`), o próprio GitHub compila o APK sozinho, em uns 5 a 10 minutos.

- Acompanhe em **Actions** no repositório
- Quando terminar, baixe em **Releases → Última versão → confronto.apk**
- Link direto: `https://github.com/SEU_USUARIO/SEU_REPO/releases/download/ultima/confronto.apk`

Na primeira instalação, o Android pede pra liberar "instalar apps desconhecidos" no navegador. A chave de assinatura é sempre a mesma, então as próximas versões instalam por cima, sem precisar desinstalar.

## Como jogar com amigos

**No mesmo Wi-Fi (grátis):** um celular toca em *Criar sala no Wi-Fi*, e o jogo mostra o IP. Os outros digitam esse IP e tocam em *Entrar na sala*.

**Pela internet:** precisa de um servidor ligado 24h (veja abaixo). Todo mundo digita o IP do servidor e entra.

## Controles

| Ação | Celular | PC (teste) |
|---|---|---|
| Andar | Arrastar o lado esquerdo da tela | WASD |
| Olhar e mirar | Arrastar o lado direito (ou o próprio botão ATIRAR) | Arrastar com o mouse |
| Atirar | ATIRAR (segurar) | F |
| Pular / recarregar / trocar arma / mira | Botões da direita | Espaço / R / Q / C |
| Pegar arma | PEGAR (aparece perto da arma) | E |

## Servidor na internet

Qualquer VPS Linux serve. Opções:

- **Oracle Cloud "Always Free"**: tem região em São Paulo e é gratuita. Escolha uma máquina Ampere (ARM). O script já baixa a versão ARM do Godot.
- **VPS paga em São Paulo** (Hostinger, Contabo, Magalu Cloud, etc.), de R$ 25 a 50 por mês.

Na VPS:

```bash
git clone https://github.com/SEU_USUARIO/SEU_REPO.git confronto
cd confronto
./server/rodar_servidor.sh 4    # 4 = quantidade de bots
```

Libere a porta **7777 UDP** no firewall da VPS (e, na Oracle, também em "Security List").

Pra deixar o servidor ligado mesmo depois de fechar o terminal, use `tmux` ou crie um serviço do `systemd`.

## Estrutura

```
scripts/main.gd     menu, partida, câmera, efeitos e lógica do servidor (dano, morte, armas)
scripts/player.gd   personagem, movimento, animação e IA dos bots
scripts/world.gd    geração do mapa (terreno, cidades, árvores, pedras)
scripts/hud.gd      controles de toque, mira, vida, placar
scripts/weapons.gd  dados das armas (dano, cadência, pente, recarga...)
.github/workflows/apk.yml   compilação automática do APK
```

Para balancear uma arma, mude os números em `scripts/weapons.gd`.

## Testes (PC/Linux)

```bash
godot --headless --path . -- --server --bots=6 --quit-after=25   # servidor com bots
godot --headless --path . -- --autojoin=127.0.0.1                # cliente entrando
godot --path . -- --autotrain                                    # treino direto
```
