# 🎮 Buy or Wait: Steam Deals Tracker

Um aplicativo móvel desenvolvido em **Flutter** que ajuda os usuários a rastrear preços de jogos da Steam, identificando as mínimas históricas e enviando notificações quando os preços caem. O aplicativo consome dados de múltiplas APIs e utiliza o ecossistema do Firebase para armazenamento em nuvem e autenticação.

## 🚀 Funcionalidades

* **Busca Integrada:** Consome a API pública da Steam para buscar jogos pelo título em tempo real com auto-completar.
* **Rastreamento de Preços:** Consome a API do GG.deals para obter o preço atual nas lojas oficiais e comparar com a mínima histórica absoluta.
* **Conversão de Moedas:** Suporte dinâmico para múltiplas regiões e moedas (USD, GBP, EUR, BRL).
* **Wishlist em Nuvem:** Os jogos salvos são armazenados no **Firebase Cloud Firestore**, permitindo persistência de dados vinculada à sessão do usuário via **Firebase Anonymous Authentication**.
* **Trabalho em Segundo Plano (Background Worker):** Utiliza o `workmanager` para rodar tarefas em segundo plano a cada 24 horas, checando os preços das APIs de forma invisível.
* **Notificações Locais:** Alertas nativos via `flutter_local_notifications` caso o worker detecte uma queda de preço abaixo do valor salvo no banco de dados.

## 🛠️ Tecnologias Utilizadas

* **Frontend:** Flutter & Dart
* **Backend as a Service (BaaS):** Firebase (Authentication & Cloud Firestore)
* **APIs Consumidas:**
  * [Steam Store Search API](https://store.steampowered.com/api/storesearch) (Busca de IDs)
  * [Steam AppDetails API](https://store.steampowered.com/api/appdetails) (Busca de imagens/capas)
  * [GG.deals API](https://gg.deals/) (Precificação e Histórico)
* **Pacotes Principais:** `http`, `shared_preferences`, `workmanager`, `flutter_local_notifications`, `url_launcher`.

## 🏗️ Arquitetura da Aplicação

Abaixo está o desenho da arquitetura do sistema, detalhando o fluxo de dados entre o aplicativo, o Firebase e as APIs externas.

```mermaid
graph LR
    subgraph App ["Aplicativo (Flutter)"]
        UI["Interface do Usuário (UI)"]
        Worker["Background Worker"]
    end

    subgraph Nuvem ["Firebase"]
        Auth["Autenticação Anônima"]
        DB[("Cloud Firestore")]
    end

    subgraph APIs ["Serviços Externos"]
        Steam["Steam Public API"]
        GGDeals["GG.deals API"]
        OS["Sistema Operacional\n(Notificações)"]
    end

    %% Conexões da UI (Linhas sólidas)
    UI -->|"1. Autentica"| Auth
    UI -->|"2. Gerencia Wishlist"| DB
    UI -->|"3. Busca Jogos"| Steam
    UI -->|"4. Consulta Preços"| GGDeals

    %% Conexões do Worker (Linhas pontilhadas)
    Worker -.->|"A. Lê dados a cada 24h"| DB
    Worker -.->|"B. Compara Mínimas"| GGDeals
    Worker -.->|"C. Dispara Alerta"| OS
```
	
## ⚙️ Como Instalar e Executar

Siga os passos abaixo para rodar o projeto localmente:

1.  **Clone o repositório:**

    ```bash
    git clone https://github.com/lucasgerbasi/BuyOrWait/
    cd BuyOrWait
    ```

2.  **Instale as dependências do Flutter:**

    ```bash
    flutter clean
    flutter pub get
    ```

3.  **Configuração do Firebase (Android):**

      * Certifique-se de ter um projeto criado no [Firebase Console](https://console.firebase.google.com/).
      * Ative o banco de dados **Firestore** e o provedor de login **Anônimo** no Authentication.
      * Adicione o arquivo `google-services.json` no diretório `android/app/`.

4.  **Execute a aplicação:**

      * Certifique-se de ter um emulador rodando ou um dispositivo físico conectado.

    <!-- end list -->

    ```bash
    flutter run
    ```

    *Nota: Se encontrar erros de compilação relacionados ao Android, este projeto exige o NDK versão `27.0.12077973` e `minSdkVersion 23`.*

## 📱 Prints da Aplicação

<div align="center">
  <img src="assets/buyorwait1.PNG" width="250" alt="Tela Principal">
  <img src="assets/buyorwait2.PNG" width="250" alt="Busca de Jogo">
  <img src="assets/buyorwait3.PNG" width="250" alt="Tela com Jogos">
</div>

## ⚠️ Segurança

Seguindo as boas práticas de segurança, o arquivo com a chave da API do GG.deals (`keys.env`) foi incluído no `.gitignore` e não está no repositório público. 
 
**Para testar o aplicativo:**
1. **Opção Mais Fácil:** Baixe e instale o `.apk` fornecido na aba *Releases*. O APK já contém as chaves compiladas e está 100% funcional.
2. **Para rodar o código-fonte:** Você precisará criar um arquivo chamado `keys.env` dentro da pasta `assets/` contendo a sua própria chave da API:
`GG_DEALS_API_KEY=sua_chave_aqui`

## 📦 Download do APK

Você pode baixar a versão final compilada do aplicativo (.apk) para testar diretamente em um dispositivo Android:

📥 **[Baixar Buy or Wait APK (v1.0.0)](https://github.com/lucasgerbasi/BuyOrWait/releases/tag/1.0)**
