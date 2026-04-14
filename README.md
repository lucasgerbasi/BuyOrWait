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
graph TD
    %% Componentes Principais
    UI[Flutter App UI]
    Background[Background Worker\nWorkmanager]
    
    %% Firebase
    Auth[Firebase Auth\nAnonymous]
    DB[(Cloud Firestore)]
    
    %% APIs
    Steam[Steam Public APIs\nSearch & Images]
    GGDeals[GG.deals API\nPrices & History]
    
    %% OS
    OS[Android OS\nLocal Notifications]

    %% Relações da UI
    UI -->|Autenticação| Auth
    UI <-->|Leitura/Escrita da Wishlist| DB
    UI -->|Busca pelo Título| Steam
    UI -->|Busca de Preços| GGDeals
    
    %% Relações do Background
    Background <-->|Checagem Diária| DB
    Background -->|Verifica Novos Preços| GGDeals
    Background -->|Dispara Alerta| OS```
	
## ⚙️ Como Instalar e Executar

Siga os passos abaixo para rodar o projeto localmente:

1.  **Clone o repositório:**

    ```bash
    git clone [https://github.com/SEU_USUARIO/SEU_REPOSITORIO.git](https://github.com/SEU_USUARIO/SEU_REPOSITORIO.git)
    cd SEU_REPOSITORIO
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

\<div align="center"\>
\<img src="LINK\_DA\_SUA\_IMAGEM\_AQUI\_1.png" width="250" alt="Tela Principal"\>
\<img src="LINK\_DA\_SUA\_IMAGEM\_AQUI\_2.png" width="250" alt="Busca de Jogo"\>
\<img src="LINK\_DA\_SUA\_IMAGEM\_AQUI\_3.png" width="250" alt="Notificação"\>
\</div\>

## 📦 Download do APK

Você pode baixar a versão final compilada do aplicativo (.apk) para testar diretamente em um dispositivo Android:

📥 **[Baixar Buy or Wait APK (v1.0.0)](link)**