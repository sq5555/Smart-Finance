# Smart Finance App

A comprehensive Flutter-based personal finance management application that helps users track income, expenses, set budgets, and receive AI-powered financial advice.

## Features

- **User Authentication**: Secure login and registration with Firebase Auth
- **Income & Expense Tracking**: Record and categorize your financial transactions
- **Budget Management**: Set monthly budgets and track spending against them
- **Financial Analytics**: Visual charts and reports of your spending patterns
- **AI-Powered Advice**: Get personalized financial advice using Gemini AI
- **Profile Management**: Update user profile and avatar
- **Data Export**: Generate PDF reports of your financial data

## Tech Stack

- **Frontend**: Flutter 3.8.1
- **Backend**: Firebase (Firestore, Auth, Storage)
- **AI Service**: OpenRouter with Gemini 2.5 Flash Lite
- **Charts**: fl_chart
- **PDF Generation**: pdf & printing packages

## Getting Started

### Prerequisites

- Flutter SDK 3.8.1 or higher
- Dart SDK
- Android Studio / VS Code
- Firebase project setup

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd test_app2
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Firebase:
   - Ensure `google-services.json` is in `android/app/`
   - Firebase configuration is already set up in `lib/firebase_options.dart`

4. Configure API Keys (Optional):
   - See [API_SETUP.md](API_SETUP.md) for Gemini AI configuration
   - This is optional for basic functionality

5. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── config/
│   └── api_config.dart      # API configuration
├── services/
│   ├── api_services.dart    # HTTP API services
│   ├── data_service.dart    # Chart data service
│   ├── image_storage_service.dart # Image upload service
│   ├── login_service.dart   # Authentication service
│   └── user_service.dart    # User profile service
├── widgets/
│   ├── base_page.dart       # Base page layout
│   └── side_menu.dart       # Navigation menu
└── [page files]             # Individual page implementations
```

## Configuration

### Environment Variables

The app supports environment variables for configuration:

- `GEMINI_API_KEY`: OpenRouter API key for AI features
- `FLUTTER_ENV`: Environment (development/production)

### Firebase Configuration

Firebase is pre-configured with the following services:
- Authentication
- Firestore Database
- Storage

## Testing

Run the test suite:

```bash
flutter test
```

The app includes tests for:
- App initialization
- Navigation functionality
- API configuration security
- Widget rendering

## Security Features

- API keys are managed securely through environment variables
- Firebase security rules protect user data
- No sensitive information is hardcoded in the source code
- Secure image storage with Firebase Storage

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Check the [API_SETUP.md](API_SETUP.md) for configuration issues
- Review Firebase documentation for backend setup
- Ensure all dependencies are properly installed

## Roadmap

- [ ] Multi-currency support
- [ ] Investment tracking
- [ ] Bill reminders
- [ ] Advanced analytics
- [ ] Mobile notifications
