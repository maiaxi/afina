# Plano de implementação — Afina

> "Afina" é um nome provisório. Muda-se num só sítio (nome do target/bundle) quando houver um definitivo.

App nativa de macOS para músicos: **afinador** e **metrónomo**, a viver na barra de menus, com janela opcional para uso prolongado. Este documento é o roteiro: fases por ordem, cada uma com tarefas e critérios de aceitação. Marca as caixas à medida que avanças.

---

## 1. Decisões técnicas

| Tema | Decisão | Porquê |
|---|---|---|
| Linguagem / UI | Swift 6 + SwiftUI (`MenuBarExtra` + `Window`) | Nativo, leve, sem runtime extra |
| macOS mínimo | macOS 15 (Sequoia) | `Observation`, `Synchronization.Atomic`, APIs SwiftUI recentes |
| Áudio | `AVAudioEngine` (input tap + `AVAudioSourceNode`) | Latência baixa, controlo ao nível da amostra |
| DSP | Accelerate (`vDSP`) | FFT/autocorrelação vetorizadas, sem dependências |
| Deteção de pitch | **MPM (McLeod Pitch Method)**, YIN como alternativa | Estável nas cordas graves; FFT pura falha abaixo de ~100 Hz |
| Estado | `@Observable` + `@MainActor` nos view models | Simples, compatível com Swift 6 strict concurrency |
| Persistência | `UserDefaults`/`@AppStorage` + JSON `Codable` para afinações personalizadas | Pouco estado, não justifica SwiftData |
| Estrutura | Projeto Xcode (app) + Swift Package local `AfinaCore` (lógica) | A lógica testa-se com `swift test`, sem UI nem microfone |
| Projeto Xcode | Gerado com XcodeGen a partir de `project.yml`; o `.xcodeproj` também é versionado | Diffs legíveis, sem conflitos no `project.pbxproj`; abre-se no Xcode sem instalar nada |
| Dependências externas | Nenhuma no MVP | Atalhos globais: avaliar `KeyboardShortcuts` (sindresorhus) na fase 6 |

### Parâmetros iniciais do afinador
- Sample rate: o do dispositivo (normalmente 48 kHz); nada de hardcoded.
- Janela de análise: 4096 amostras (~85 ms a 48 kHz); 8192 no modo baixo (Mi1 = 41,2 Hz).
- Hop: 1024 amostras (~47 atualizações/s).
- Gama útil: 30 Hz – 1500 Hz.
- *Noise gate* por RMS (ajustável) e limiar de *clarity* do MPM ≈ 0,9.
- Suavização: mediana de 5 estimativas + EMA nos cents; histerese na troca de nota.

### Parâmetros iniciais do metrónomo
- 20–300 BPM; compassos simples e compostos (2/4, 3/4, 4/4, 5/4, 6/8, 7/8, 12/8).
- Cliques gerados no render callback do `AVAudioSourceNode`, contados em amostras — **nunca** `Timer`/`DispatchQueue` para tempo.
- Sons sintetizados (seno curto com envelope): acento ~1500 Hz, tempo ~1000 Hz, subdivisão ~800 Hz e mais baixa.
- Alterações de BPM aplicadas no tempo seguinte; o estado partilhado com o thread de áudio vai por atómicos.

---

## 2. Estrutura do repositório (alvo)

```
guitar-app/
├── project.yml               # especificação XcodeGen (fonte de verdade do projeto)
├── Afina.xcodeproj           # gerado: `xcodegen generate`
├── Afina/                      # target da app (só UI e integração)
│   ├── AfinaApp.swift          # @main, MenuBarExtra + Window + Settings
│   ├── Tuner/                  # views e view model do afinador
│   ├── Metronome/              # views e view model do metrónomo
│   ├── Settings/
│   ├── Resources/              # Assets, Localizable.xcstrings (pt-PT, en)
│   ├── Info.plist
│   └── Afina.entitlements
├── Packages/AfinaCore/         # lógica pura, testável
│   ├── Package.swift
│   ├── Sources/AfinaCore/
│   │   ├── Audio/              # AudioInput, gestão de dispositivos, ring buffer
│   │   ├── Pitch/              # MPM, YIN, suavização
│   │   ├── Music/              # Note, Pitch→nota/cents, Instrument, Tuning
│   │   └── Metronome/          # MetronomeEngine, ClickSynth, TapTempo
│   └── Tests/AfinaCoreTests/
├── docs/PLANO.md
├── CLAUDE.md
└── README.md
```

---

## 3. Fases

### Fase 0 — Esqueleto do projeto
- [x] Criar projeto Xcode "Afina" (macOS App, SwiftUI, Swift 6, deployment target 15.0)
- [x] Criar package local `Packages/AfinaCore` e ligá-lo ao target
- [x] `MenuBarExtra` com estilo `.window` e um placeholder; `LSUIElement = YES` (sem ícone na Dock por defeito)
- [x] `Info.plist`: `NSMicrophoneUsageDescription` em pt-PT
- [x] Entitlements: App Sandbox + `com.apple.security.device.audio-input`
- [x] `git init`, `.gitignore` para Xcode/SwiftPM
- [x] `swift test --package-path Packages/AfinaCore` corre (mesmo com um teste vazio)

**Aceitação:** a app arranca, aparece um ícone na barra de menus, e abre um popover vazio.

### Fase 1 — Modelo musical (`AfinaCore/Music`)
- [x] `Note` (classe de altura + oitava, nomes em notação latina e anglo-saxónica: Dó/C, Ré/D…)
- [x] Conversões: frequência ↔ número MIDI ↔ nota + desvio em cents, com Lá de referência configurável (415–466 Hz)
- [x] `Instrument` e `Tuning` (`Codable`, `Identifiable`), com afinações pré-definidas:
  - Guitarra: Standard (E A D G B E), Drop D, Meio tom abaixo, Tom abaixo, DADGAD, Open G, Open D, Open E
  - Baixo 4 e 5 cordas: Standard, Drop D (no de 5 cordas: B D A D G — mantém o Si grave, porque o Lá0 fica abaixo dos 30 Hz)
  - Ukulele: Standard (G C E A), Baritono (D G B E)
  - Cavaquinho: Standard (D G B D)
  - Guitarra portuguesa: Lisboa (D A B E A B), Coimbra (C G A D G A) — uma nota por ordem, da 6.ª para a 1.ª: Lisboa D3 A3 B3 E4 A4 B4; nas ordens 4–6 (pares à oitava) usa-se a corda mais grave
- [x] Capotraste: transpõe as notas alvo N meios-tons
- [x] Deteção da corda mais próxima numa afinação
- [x] Testes unitários para tudo acima

**Notas de implementação:** notação científica (C4 = MIDI 60); alterações sempre em sustenido; os nomes das afinações/instrumentos pré-definidos são chaves de localização pt-PT, a traduzir no `Localizable.xcstrings` da app quando forem mostrados (fase 4).

**Aceitação:** `440 Hz → A4 +0¢`, `82,41 Hz → E2 ±0,1¢`, `A4=432 → 432 Hz é A4 +0¢`; afinações serializam/desserializam sem perdas.

### Fase 2 — Captura de áudio (`AfinaCore/Audio`)
- [x] Pedido de permissão do microfone (`AVCaptureDevice.requestAccess(for: .audio)`), com ecrã de erro e botão para Definições do Sistema
- [x] `AudioInput`: `AVAudioEngine.inputNode.installTap`, mono, sample rate nativo
- [x] Ring buffer lock-free (single producer / single consumer) entre o tap e a análise
- [x] Listar dispositivos de entrada (Core Audio) e trocar de dispositivo em runtime
- [x] Reagir a mudanças de configuração (`AVAudioEngineConfigurationChange`, ligar/desligar interface USB, auscultadores)
- [x] Medidor de nível (RMS/dBFS) para debug e para o noise gate

**Notas de implementação:** o tap usa só o primeiro canal; cada arranque cria um `AVAudioEngine` novo (troca de dispositivo via `auAudioUnit.setDeviceID`); o dispositivo escolhido guarda-se pelo UID e, se estiver desligado, usa-se a entrada por defeito até voltar; ring buffer de 65 536 amostras que descarta áudio novo quando cheio.

**Aceitação:** o nível do microfone mexe na UI; trocar de dispositivo não crasha nem deixa o motor parado.

### Fase 3 — Deteção de pitch (`AfinaCore/Pitch`)
- [x] Protocolo `PitchDetector { func detect(_ samples: UnsafeBufferPointer<Float>, sampleRate: Double) -> PitchEstimate? }`
- [x] Implementação MPM com NSDF calculada via FFT (`vDSP`), *peak picking* e interpolação parabólica
- [x] Implementação YIN (para comparar e como fallback)
- [x] Pré-processamento: remoção de DC, janela, noise gate
- [x] Suavização (mediana + EMA) e histerese de nota
- [x] Testes com sinais sintéticos: senos puros, senos com harmónicos fortes (fundamental fraca), ruído branco (deve devolver `nil`), 41 Hz a 1500 Hz
- [x] Benchmark: análise de uma janela de 4096 em < 2 ms num Mac Apple Silicon

**Notas de implementação:**
- Sem janela (Hann, etc.): a normalização da NSDF já trata as pontas; o pré-processamento é remoção de DC nos detetores e noise gate (RMS da janela, −55 dBFS com 6 dB de histerese) no `PitchAnalyzer`.
- Refinamento pelo maior múltiplo do período que cabe na janela (MPM e YIN): o erro da interpolação parabólica divide-se pelo nº de períodos. Com ruído a ~22 dB de SNR passou de ~3¢ para < 1,5¢ numa só janela.
- Tempo por janela de 4096 (MPM): ~14 µs em release, ~0,2 ms em debug.
- Por agora a análise corre no `MainActor`, no ciclo de ~30 Hz do `TunerViewModel`; passar para um thread próprio se o custo subir.
- O popover mostra uma linha de debug (nota, cents, Hz) para validar com uma corda real antes da UI da fase 4.

**Aceitação:** erro < 1 cent em senos sintéticos de 40–1500 Hz; sem erros de oitava nos testes com harmónicos; estável (< ±2¢ de jitter) numa corda real sustentada.

### Fase 4 — UI do afinador (MVP)
- [x] `TunerViewModel` (`@Observable @MainActor`) que consome estimativas a ~30 fps
- [x] Vista principal: nota grande, oitava, frequência, agulha/barra de cents (±50¢), cor verde dentro de ±3¢ (tolerância configurável)
- [x] Modo cromático vs. modo instrumento (mostra as cordas, destaca a mais próxima, marca as já afinadas)
- [x] Seletores: instrumento, afinação, Lá de referência, capotraste
- [x] Estado "à espera de som" quando o gate está fechado
- [x] O motor só corre com o popover/janela abertos (poupar bateria e privacidade — indicador laranja do microfone)

**Notas de implementação:** a lógica de modo/corda alvo (`TunerTarget`) e de cordas afinadas (`TuningProgress`: marca após 10 leituras seguidas dentro da tolerância, desmarca após 10 acima do dobro) está no `AfinaCore`. A tolerância (3¢) e a notação (C/Dó) já são propriedades do view model; os controlos ficam para as Definições (fase 6). Escolhas ainda não persistem (fase 6).

**Aceitação:** afinar uma guitarra real do início ao fim só com a app, no popover da barra de menus.

### Fase 5 — Metrónomo (MVP)
- [ ] `MetronomeEngine` em `AfinaCore`: `AVAudioSourceNode` com contador de amostras, cliques pré-sintetizados, acentos, subdivisões (colcheias, tercinas, semicolcheias)
- [ ] Estado partilhado com o thread de áudio via `Atomic` (BPM, compasso, a tocar/parado); o callback publica o índice do tempo atual para a UI
- [ ] `TapTempo`: média dos últimos 4–6 toques, reset após 2 s sem toques
- [ ] UI: BPM (slider + campo + ±1/±5), botão tap, compasso, subdivisão, volume, indicador visual por tempo (acento destacado)
- [ ] Afinador e metrónomo podem coexistir (input e output no mesmo motor ou em motores separados — decidir na implementação)
- [ ] Teste: renderizar 60 s offline a 120 BPM e confirmar que os cliques caem na amostra exata (deriva = 0)

**Aceitação:** sem deriva audível ao fim de 10 minutos; mudar o BPM a meio não provoca cliques fora de tempo.

### Fase 6 — Polimento do MVP
- [ ] Persistir as últimas escolhas (instrumento, afinação, A4, BPM, compasso…)
- [ ] Editor de afinações personalizadas (criar, renomear, apagar)
- [ ] Janela "destacável" (`Window`) para quem quer a app sempre visível
- [ ] Definições: dispositivo de entrada, tolerância, notação (Dó/C), som do clique, mostrar na Dock
- [ ] Atalhos de teclado globais (ligar/desligar metrónomo, tap tempo, abrir afinador)
- [ ] Localização pt-PT e en
- [ ] Ícone da app e ícone da barra de menus (SF Symbol ou template próprio)
- [ ] Acessibilidade: VoiceOver na agulha ("Mi, 5 cents abaixo"), contraste, Reduce Motion

**Aceitação:** a app é utilizável no dia a dia sem nada "por fazer" visível.

### Fase 7 — Funcionalidades v2
- [ ] **Speed trainer**: BPM inicial, final, incremento a cada N compassos
- [ ] **Drone**: nota contínua (seno/onda mais rica) com escolha de nota e oitava
- [ ] **Nota de referência**: tocar a nota da corda selecionada para afinar de ouvido
- [ ] **Modo strobe** para afinação fina
- [ ] Ficheiros de som alternativos para o metrónomo (madeira, cowbell, voz a contar)
- [ ] Contagem antes de começar (count-in)

### Fase 8 — Extras (avaliar depois da v2)
- [ ] Registo de prática: tempo por dia, exercícios, BPM máximo por exercício (SwiftData aqui já faz sentido)
- [ ] Gravador rápido com reprodução
- [ ] Detetor de acordes (chromagram + templates)
- [ ] Widget de macOS / Control Center

### Fase 9 — Distribuição
- [ ] Assinatura com Developer ID e notarização (`notarytool`)
- [ ] DMG para download direto; Sparkle para atualizações **ou** Mac App Store (decidir)
- [ ] Página simples (pode ser um README bem feito + GitHub Releases)

---

## 4. Riscos e notas

- **Erros de oitava** são o problema clássico dos afinadores: harmónicos fortes nas cordas graves. Mitigação: MPM com limiar de pico relativo, testes com sinais ricos em harmónicos, e fallback para YIN.
- **Thread de áudio**: nada de alocações, locks, `print`, Swift `Array` com cópia, nem `async` no render callback/tap. Ver regras no `CLAUDE.md`.
- **Sandbox + Core Audio**: listar e trocar dispositivos funciona com sandbox, mas testar cedo com uma interface USB.
- **Bluetooth**: microfones Bluetooth baixam o sample rate (16–24 kHz) e aumentam a latência; avisar o utilizador.
- **Bateria/privacidade**: o microfone só fica ativo enquanto o afinador está visível.

## 5. Próximo passo

Fase 0 → Fase 1. O modelo musical e os testes não precisam de áudio e dão uma base sólida para o resto.
