# Afina 🎸

Afinador e metrónomo para macOS, sempre à mão na barra de menus.

> Nome provisório. Projeto em desenvolvimento — ver o [plano de implementação](docs/PLANO.md).

## Funcionalidades

### MVP
- **Afinador cromático** com indicação em cents, nota e frequência
- **Modo por instrumento** com afinações pré-definidas:
  guitarra (Standard, Drop D, DADGAD, Open G/D/E, meio tom e tom abaixo), baixo de 4 e 5 cordas, ukulele, cavaquinho e guitarra portuguesa (Lisboa e Coimbra)
- **Lá de referência** ajustável (440 Hz por defeito)
- **Capotraste**
- **Metrónomo** preciso à amostra, com *tap tempo*, compassos, acentos e subdivisões
- Escolha do **dispositivo de entrada** (microfone interno ou interface de áudio)

### Planeado
- Afinações personalizadas
- Speed trainer, drone e nota de referência
- Modo strobe
- Atalhos de teclado globais
- Registo de prática, gravador e detetor de acordes

## Instalar

1. Descarrega o `Afina-<versão>.dmg` da [última release](https://github.com/maiaxi/afina/releases/latest).
2. Abre o DMG e arrasta o **Afina** para **Aplicações**.
3. Na primeira abertura, o macOS avisa que não consegue verificar o programador (a app ainda não é assinada com Developer ID nem notarizada pela Apple). Para a abrir:
   - abre a app uma vez e fecha o aviso;
   - vai a **Definições do Sistema → Privacidade e Segurança** e, ao fundo, carrega em **Abrir mesmo assim**;
   - confirma com a tua palavra-passe.

   Só é preciso fazer isto uma vez.

As versões seguintes chegam por **atualização automática** (Sparkle): a app procura novas versões nas releases do GitHub e instala-as quando aceitas. Podes desligar isto ou procurar manualmente em **Definições → Geral → Atualizações**.

## Requisitos

- macOS 15 (Sequoia) ou mais recente
- Mac com Apple Silicon ou Intel
- Para compilar: Xcode 16 ou mais recente (Swift 6)

## Compilar e correr

```bash
git clone <url-do-repo> guitar-app
cd guitar-app
open Afina.xcodeproj        # e carregar em ⌘R
```

Ou pela linha de comandos:

```bash
xcodebuild -project Afina.xcodeproj -scheme Afina -configuration Debug build
```

Na primeira utilização do afinador, o macOS pede acesso ao microfone. Se recusares, podes ativá-lo depois em **Definições do Sistema → Privacidade e Segurança → Microfone**.

## Testes

A lógica (modelo musical, deteção de pitch, motor do metrónomo) vive no package `AfinaCore` e testa-se sem abrir o Xcode:

```bash
swift test --package-path Packages/AfinaCore
```

## Publicar uma versão

As releases são feitas pelo GitHub Actions ([`release.yml`](.github/workflows/release.yml)) quando se envia uma tag:

```bash
git tag v0.2.0
git push origin v0.2.0
```

O workflow corre os testes, compila em Release (universal), assina ad-hoc, cria o DMG, assina-o com a chave EdDSA do Sparkle (segredo `SPARKLE_PRIVATE_KEY`) e publica a release com o `appcast.xml`. O número da build é o número de commits, por isso cresce sempre.

Para testar localmente: `scripts/build_release.sh 0.2.0 999`.

## Arquitetura

```
Afina/                  App SwiftUI (MenuBarExtra + janela opcional)
Packages/AfinaCore/
  Music/                Notas, afinações, instrumentos, conversão Hz ↔ nota/cents
  Pitch/                Deteção de pitch (MPM, YIN) e suavização
  Audio/                Captura (AVAudioEngine), dispositivos, ring buffer
  Metronome/            Motor do metrónomo com agendamento à amostra
```

- **Deteção de pitch:** McLeod Pitch Method (MPM) sobre `vDSP`, com YIN como alternativa. Mais estável que FFT simples nas cordas graves (Mi grave da guitarra a 82 Hz, do baixo a 41 Hz).
- **Metrónomo:** os cliques são gerados dentro do render callback de um `AVAudioSourceNode` e contados em amostras, por isso não há deriva.

Mais detalhe em [`docs/PLANO.md`](docs/PLANO.md). Convenções de código e regras para o thread de áudio em [`CLAUDE.md`](CLAUDE.md).

## Privacidade

O áudio do microfone é processado apenas localmente e só enquanto o afinador está visível. Nada é gravado nem enviado para lado nenhum.

A única ligação à rede é a verificação de atualizações, que descarrega o `appcast.xml` das releases do GitHub (pode ser desligada nas Definições).

## Licença

[GPL-3.0](LICENSE). Usa o [Sparkle](https://sparkle-project.org) (licença MIT) para as atualizações.
