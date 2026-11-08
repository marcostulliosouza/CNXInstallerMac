# CNX Installer para macOS

**Prepare um cartão SD para Nintendo Switch usando o pacote CNX com uma interface simples no macOS.**

> **Versão beta:** utilize inicialmente com um cartão de testes. **Formatar apaga todos os dados do disco selecionado**, inclusive partições e eventuais dados de emuMMC. Faça backup antes de continuar.

## Download

**[Baixar a versão mais recente (GitHub Releases)](../../releases)**

Na página de Releases, abra a versão desejada e baixe o arquivo `.dmg` em **Assets**. Não é necessário baixar o código-fonte para instalar o aplicativo.

## Recursos

- Interface nativa em português, desenvolvida com **SwiftUI**.
- Identificação de unidades físicas externas/removíveis compatíveis.
- Confirmação da unidade antes da operação destrutiva.
- Download do **CNX 23.0.1-1** a partir da publicação oficial do projeto.
- Verificação SHA-256 do arquivo baixado antes da formatação.
- Formatação do cartão em **FAT32/MBR** e cópia dos arquivos para a raiz.
- Solicitação de autorização administrativa do macOS quando necessária.

**O que o aplicativo não faz:** não instala modchip, não cria emuMMC, não desbloqueia o console por si só e não modifica seu firmware diretamente.

## Requisitos

- macOS **13 (Ventura)** ou superior.
- Mac com processador **Apple Silicon (arm64)** ou **Intel (x86_64)**, usando o DMG universal.
- Cartão SD e leitor de cartões identificado pelo macOS como unidade física externa/removível.
- Internet para baixar o pacote CNX.
- Permissão de administrador para a formatação.

## Como instalar

1. Acesse **[Releases](../../releases)** e baixe o `.dmg`.
2. Abra o arquivo baixado.
3. Arraste **CNX Installer.app** para **Aplicativos**.
4. Abra o aplicativo e conecte o cartão SD.
5. Selecione o cartão correto, confira nome e capacidade e confirme a operação.
6. Aguarde o download, a validação e a cópia dos arquivos antes de retirar o cartão.

> **Aviso do macOS:** builds sem assinatura Developer ID e notarização podem exibir alertas de segurança. As instruções oficiais da Apple sobre abrir aplicativos de desenvolvedores não identificados estão disponíveis em [Apple Support](https://support.apple.com/pt-br/guide/mac-help/mh40616/mac). Não desative o Gatekeeper globalmente.

## Atenção: dados do cartão

O modo de instalação limpa **apaga todo o cartão selecionado**. Isso pode excluir jogos, saves, arquivos pessoais, partições e dados de emuMMC. Não selecione discos com informações que você precise preservar. A verificação do pacote ocorre antes da formatação, mas falhas de energia, retirada do cartão ou outros erros durante a operação podem resultar em cartão incompleto.

## Compilar o projeto

É necessário um Mac com Xcode Command Line Tools instalado. Clone o repositório e execute:

```bash
xcode-select --install
bash build-dmg.sh
```

O DMG é produzido na pasta `dist/`. A compilação também pode ser executada pelo workflow disponível na aba **Actions** deste repositório. Consulte `LEIA-ME.md` para informações técnicas, assinatura e notarização.

## Pacote e créditos

O instalador utiliza o pacote **CNX**, criado e distribuído por **[CostelaCNX](https://github.com/CostelaCNX/CNX)**. Pacote utilizado nesta versão: [CNX 23.0.1-1](https://github.com/CostelaCNX/CNX/releases/tag/23.0.1-1).

O **CNX Installer para macOS é um projeto independente e não oficial**. Não há afiliação com a equipe CNX ou com a Nintendo. Marcas e nomes citados pertencem a seus respectivos titulares. A licença deste repositório **não altera nem substitui** licenças, direitos autorais ou condições de redistribuição de componentes de terceiros baixados pelo aplicativo.

## Problemas e sugestões

Encontrou um problema? Abra uma [Issue](../../issues) informando versão do macOS, modelo do Mac, capacidade e modelo do cartão e descrição do erro. **Não publique dados pessoais, backups ou arquivos privados.**

## Licença

O código-fonte original deste instalador é disponibilizado sob a **[Licença MIT](LICENSE)**. Componentes externos, incluindo o pacote CNX, permanecem sujeitos às suas respectivas licenças.
