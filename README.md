
# 📊 PortfolioMaster — Multi-Asset Portfolio Tracker & AI Risk Engine

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![RevenueCat](https://img.shields.io/badge/RevenueCat-In--App%20Purchases-E75243)](https://www.revenuecat.com)
[![Google Play](https://img.shields.io/badge/Google%20Play-Live-brightgreen)](https://play.google.com/store/apps/details?id=com.portfoliomaster.app)

> **Official Store Listing**: [Download on Google Play](https://play.google.com/store/apps/details?id=com.portfoliomaster.app)  
> **Built for RevenueCat Shipaton 2026** | Targeting: **HAMM Award**, **RevenueCat Design Award**, & **Next Gen Award**

---

## 📌 Overview
Retail investors hold assets scattered across different brokerages, crypto wallets, and real estate documents, leaving them blind to their true net worth and concentration risk. **PortfolioMaster** unifies these silos into an institutional-grade portfolio dashboard with AI-driven risk diagnostics.

---

## 🚀 Key Features
* **Multi-Asset Portfolio Ledger**: Track stocks, cryptocurrencies, gold, real estate, fixed income, and funds in one unified view.
* **AI Risk & Diversification Diagnostics**: Calculates cross-asset concentration, geographic exposure, and sector risk with actionable recommendations.
* **Interactive Data Visualizations**: Responsive asset allocation pie charts and exposure progress meters powered by `fl_chart`.
* **Single-Tap Live Price Refresh**: Instant re-valuation calculating current market values, total dollar returns, and profit/loss percentages.
* **RevenueCat Monetization**: Pro ($25/mo) and Premium ($35/mo) plans for frequent analyses, plus on-demand Investor Credit Packs ($15 for 10 credits, $40 for 25 credits).

---

## 💳 Judge Reviewer Credentials & Promo Codes
* **Reviewer Account**: `reviewer@portfoliomaster.app` / `Reviewer123!`
* **Google Play / RevenueCat Promo Codes**:
  * 👑 **Premium Subscription**: `PORTFOLIOFREE`
  * ⚡ **10 Analysis Credit Pack**: `BD1DM98HP46MU2ML5ZLF192`

---

## 🛠 Tech Stack & Architecture
* **Frontend**: Flutter / Dart supporting high-density dark & light Material 3 theming
* **Monetization Engine**: RevenueCat SDK (`purchases_flutter`)
* **Backend API**: Python REST API on Azure App Services (`https://inve-dkb4dxbjhzd6d7g6.eastus-01.azurewebsites.net`)
* **Pricing & Analytics**: Real-time market valuation endpoints paired with Gemini risk analytics

---

## 📂 Project Structure
```text
portfoliomaster/
├── android/               # Native Android configuration
├── ios/                   # Native iOS configuration
├── lib/
│   ├── main.dart          # Main application, theme setup, RevenueCat initialize
│   ├── models/            # Investment, AssetType, PortfolioAnalysis, UserSession
│   ├── services/          # ApiService (Price fetching, portfolio analytics, Azure backend)
│   └── screens/           # PortfolioScreen, InvestmentsScreen, AddInvestmentScreen, AnalyticsScreen, UpgradeScreen
├── azure_inve/            # Azure cloud infrastructure
│   ├── app.py             # Flask API
│   ├── portfolio.db       # SQLite database
│   └── requirements.txt   # Python dependencies
└── pubspec.yaml           # Flutter dependencies
```

---

## ⚙️ Getting Started
```bash
git clone https://github.com/Jerryblessed/portfoliomaster.git
cd portfoliomaster
flutter pub get
flutter run
```

---

## 📄 License
This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
