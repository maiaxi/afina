# CLAUDE.md

Guia para o Claude (e para humanos) trabalharem neste repositório.

## O projeto

**Afina** (nome provisório): afinador e metrónomo nativos para macOS, a viver na barra de menus. O roteiro completo, com fases e critérios de aceitação, está em [`docs/PLANO.md`](docs/PLANO.md). **Lê-o antes de começar uma tarefa** e marca as caixas que concluíres.

- Idioma da conversa, dos commits e da documentação: **português europeu**.
- Código (identificadores, tipos, funções) em **inglês**; comentários podem ser em português.
- Strings visíveis ao utilizador vão sempre para `Localizable.xcstrings` (pt-PT e en), nunca hardcoded.

## Stack

- Swift 6 com strict concurrency, SwiftUI, macOS 15+
- `AVAudioEngine` para entrada e saída de áudio, Accelerate (`vDSP`) para DSP
- Sem dependências externas, salvo decisão explícita registada no `PLANO.md`

## Estrutura

- `Afina/` — target da app: views, view models, integração. **Sem lógica de DSP nem de música aqui.**
- `Packages/AfinaCore/` — lógica pura e testável: `Music/`, `Pitch/`, `Audio/`, `Metronome/`.
- `docs/` — plano e notas de design.

Regra prática: se dá para testar sem UI, vai para o `AfinaCore`.

## Comandos

```bash
# Regenerar o projeto Xcode depois de mudar project.yml ou adicionar/remover ficheiros na app
xcodegen generate

# Testes da lógica (rápido, sem Xcode aberto)
swift test --package-path Packages/AfinaCore

# Um teste específico
swift test --package-path Packages/AfinaCore --filter PitchDetectorTests

# Build da app
xcodebuild -project Afina.xcodeproj -scheme Afina -configuration Debug build

# Testes via Xcode (inclui os do package)
xcodebuild -project Afina.xcodeproj -scheme Afina test
```

Corre sempre os testes do `AfinaCore` antes de dar uma tarefa como concluída.

## Regras do thread de áudio (críticas)

Código que corre no render callback de `AVAudioSourceNode` ou no tap de `installTap`:

- **Proibido:** alocar memória (incluindo criar/crescer `Array`, `String`, closures que capturam), locks/`DispatchQueue.sync`, `print`/logging, `async/await`, aceder a objetos `@MainActor`, chamadas Objective-C que possam bloquear.
- **Permitido:** ler/escrever buffers pré-alocados (`UnsafeMutablePointer`), `Atomic` do módulo `Synchronization`, aritmética.
- Passagem de dados áudio → análise: ring buffer SPSC lock-free. Análise → UI: publicar no `MainActor` a no máximo ~30 Hz.
- Parâmetros UI → áudio (BPM, compasso, volume): `Atomic`, lidos uma vez por buffer.

## Metrónomo

- O tempo conta-se em **amostras** dentro do render callback. Nunca `Timer`, `DispatchSourceTimer` ou `Task.sleep` para marcar tempos.
- Cliques pré-sintetizados na inicialização; o callback só copia/mistura.
- Mudanças de BPM entram no próximo tempo, não a meio.

## Deteção de pitch

- Algoritmo principal: MPM; YIN como alternativa, atrás do protocolo `PitchDetector`.
- Nunca assumir sample rate: usar sempre o do formato do input.
- Qualquer alteração ao detetor tem de manter os testes de precisão (erro < 1 cent em senos de 40–1500 Hz) e de erros de oitava.
- Testes usam sinais sintéticos gerados no próprio teste (senos, harmónicos, ruído) — não depender de ficheiros de áudio grandes no repo.

## Estilo

- `@Observable` + `@MainActor` para view models; nada de `ObservableObject`/`@Published` em código novo.
- Tipos de valor (`struct`/`enum`) para o modelo musical; tudo `Sendable`.
- Funções pequenas, nomes explícitos; evitar abreviaturas tirando as do domínio (BPM, MIDI, RMS, FFT).
- Sem `force unwrap` fora de testes, exceto com comentário a justificar.
- Views pequenas e compostas; pré-visualizações (`#Preview`) com dados falsos, sem microfone.

## Permissões e entitlements

- `NSMicrophoneUsageDescription` no `Info.plist`.
- App Sandbox ativo com `com.apple.security.device.audio-input`.
- Se o microfone for negado, mostrar ecrã explicativo com botão para as Definições do Sistema — nunca falhar em silêncio.

## Fluxo de trabalho

1. Escolher a próxima tarefa não marcada no `docs/PLANO.md` (por ordem de fase).
2. Escrever/atualizar testes primeiro quando a lógica estiver no `AfinaCore`.
3. Implementar, correr testes, fazer build da app.
4. Marcar a caixa no plano; se uma decisão mudou, atualizar a tabela de decisões técnicas.
5. Commits pequenos, mensagem em português no imperativo (ex.: "Adiciona conversão de frequência para nota").

## Limitações conhecidas do ambiente

O Claude pode trabalhar a partir de um shell Linux sem toolchain da Apple. Nesse caso não consegue compilar nem correr testes: deve dizê-lo explicitamente e pedir ao João que corra os comandos acima no Mac, em vez de dar o código como verificado.
