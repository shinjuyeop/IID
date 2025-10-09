# W5 Flutter Application

This is the W5 Flutter application, designed to interface with IoT devices and display sensor data in real-time. The application provides a user-friendly dashboard for monitoring device statuses and historical data.

## Project Structure

- **lib/**: Contains the main application code.
  - **main.dart**: Entry point of the application.
  - **app.dart**: Application configuration and routing.
  - **core/**: Core functionalities including configuration, constants, and routing.
  - **models/**: Data models for device status and sensor readings.
  - **services/**: Services for API communication and data management.
  - **state/**: State management using Cubit for app and device states.
  - **ui/**: User interface components including pages and widgets.
  
- **assets/**: Contains assets such as fonts and icons.

- **test/**: Contains unit and widget tests for the application.

- **android/**, **ios/**, **web/**, **linux/**, **macos/**, **windows/**: Platform-specific directories for building the application.

## Getting Started

1. Clone the repository:
   ```
   git clone <repository-url>
   ```

2. Navigate to the project directory:
   ```
   cd w5_flutter_app
   ```

3. Install dependencies:
   ```
   flutter pub get
   ```

4. Run the application:
   ```
   flutter run
   ```

## Features

- Real-time monitoring of IoT devices.
- Historical data visualization.
- User-friendly interface with responsive design.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request for any enhancements or bug fixes.

## License

This project is licensed under the MIT License. See the LICENSE file for details.