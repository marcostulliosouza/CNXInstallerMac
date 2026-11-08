# CNX Installer para macOS — projeto v0.2

Aplicativo SwiftUI para preparar cartões SD externos/removíveis com o pacote CNX **23.0.1-1**. macOS 13 ou superior, Intel e Apple Silicon. Requer **testes reais** antes de distribuir a terceiros.

## Gerar o instalador DMG no seu Mac

1. Extraia o ZIP do projeto.
2. Instale as ferramentas de compilação se necessário: `xcode-select --install`.
3. No Terminal, entre na pasta `CNXInstallerMac`.
4. Execute `bash build-dmg.sh`.
5. O arquivo gerado estará em `dist/CNX-Installer-macOS-universal-v0.2.dmg`.
6. Abra o DMG e arraste **CNX Installer.app** para a pasta **Applications**.

A compilação usa `swiftc`, SDK do macOS e `hdiutil`. O instalador DMG permite arrastar o app para Aplicativos; o usuário final **não precisa** do Xcode. O DMG tem uma soma SHA-256 em arquivo separado.

## Alternativa: compilar no GitHub Actions

Crie um repositório no GitHub e envie **todo o conteúdo desta pasta**, incluindo `.github/workflows/build-macos.yml`. Na aba **Actions**, abra **Compilar DMG do CNX Installer (macOS)**, clique **Run workflow** e baixe o artefato após finalizar. O runner `macos-15` compila o app usando um Mac hospedado pelo GitHub. Pode haver requisitos de conta/cota do GitHub. O workflow não publica automaticamente uma release.

## Assinatura e distribuição

Por padrão, `build-dmg.sh` faz assinatura **ad hoc**, útil para testes. Isso **não** substitui a assinatura Apple Developer ID e a notarização: um DMG não notarizado pode gerar alertas ou bloqueios do Gatekeeper. Para distribuição pública, use o certificado Developer ID e configure:

```
APPLE_SIGN_IDENTITY='Developer ID Application: SUA EMPRESA (TEAMID)' bash build-dmg.sh
```

Para notarização, configure previamente um perfil do `notarytool` e utilize `APPLE_NOTARY_PROFILE=nome-do-perfil` juntamente com `APPLE_SIGN_IDENTITY`. É necessário ter acesso apropriado ao Apple Developer Program.

## Segurança do cartão SD

- **Instalação limpa**: apaga todos os dados do cartão, inclusive emuMMC, Nintendo, saves e backups. Faça cópia de segurança antes.
- Seleciona apenas unidades físicas removíveis externas. Confirma identificação e tamanho antes da formatação.
- Baixa o ZIP oficial no GitHub **antes de formatar**. Confere SHA-256 (`7e9972b03e837c0d49aeeecb8b80a79d5d1cb0bda9609c8d0ac8147015e6180a`).
- Formata FAT32/MBR usando `diskutil` com autorização do macOS e copia conteúdo para a raiz do cartão.
- Não instala modchip, não cria emuMMC e não modifica o console.

**Status:** fonte não compilada ou testada em macOS neste ambiente Linux. Teste inicialmente em cartão sem dados importantes. Falha após início da formatação pode deixar o cartão vazio ou parcialmente preparado.

Código independente, sem afiliação com CostelaCNX. Pacote: https://github.com/CostelaCNX/CNX/releases/tag/23.0.1-1. Respeite licenças e direitos de terceiros.
