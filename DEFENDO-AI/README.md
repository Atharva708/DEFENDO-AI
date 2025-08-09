# SecureNow iOS App

A comprehensive AI-powered security platform that connects users with security services including guards and drone patrols.

## Features

### 👤 User-Side Features

#### 1. User Onboarding & Authentication
- Welcome screen with app pitch
- Sign up via phone/email or social
- OTP verification
- Role selection (User vs Provider)
- Guest access for anonymous SOS

#### 2. User Dashboard (Home)
- Floating SOS button (fixed at bottom right)
- Safety score tracking
- Quick action cards:
  - Track My Location
  - My Bookings
  - My Alerts
  - Emergency Contacts
- Mini live heatmap preview
- Daily AI tips

#### 3. SOS Trigger Screen
- Red glowing central button
- Voice trigger indicator
- Safe word input option
- Slide-to-cancel safety mechanism
- Panic chain timer (5-minute countdown)

#### 4. Booking Flow (Guard or Drone)
- 4-step booking wizard:
  1. Select Service: [Guard] or [Drone]
  2. Choose Date & Time
  3. Select Duration & Location
  4. Confirm & Pay
- Quick rebooking options for past bookings

#### 5. Marketplace Explorer
- Toggle between: [Drones], [Guards], [Studios], [Agencies]
- Filters: Tags, Rating, Verified Only, Pricing
- Provider cards with detailed information
- Book Now functionality

#### 6. Safety Score Map
- Color-coded zones (Red/Yellow/Green)
- Toggle: [Live Alerts], [Nearby Guards], [Available Drones]
- Tap for safety score details
- AI predicted crime likelihood

#### 7. My Bookings Page
- Filters: Type, Date, Provider
- Status indicators (Pending, Confirmed, Completed)
- CTA: [Rebook], [View Details]

#### 8. User Profile
- Basic info management
- Notification settings
- Emergency contact manager
- Language selector
- Booking preferences

### 🧑‍💼 Provider-Side Features

#### 9. Provider Dashboard
- Stats: Total Bookings, Earnings, Reviews
- Quick Actions: [Add Drone], [Add Guard], [Manage Portfolio]
- Availability Toggle
- Upcoming bookings list

#### 10. Analytics Dashboard
- Bookings per month
- Income graphs
- Top-performing staff/drones
- Cancelation rate
- Peak hours heatmap

#### 11. Booking Manager
- Table view to manage incoming bookings
- Filters: Type, Date, Status
- Actions: Accept / Decline / Chat / Mark as Done
- Auto-response toggle

### 🛠️ Admin Features

#### 12. Admin Dashboard
- Platform analytics overview
- Bookings trend chart
- Active providers
- Active SOS alerts
- Revenue chart
- Alert center

#### 13. User/Provider Verification Panel
- List of pending verifications (KYC, License, Drones)
- Approve / Reject buttons
- Badge manager (Blue/Green/Studio Pro)
- Searchable/filterable list

#### 14. Dispute Management Panel
- Case resolution screen
- Reported incident summary
- Chat transcript preview
- Attachments viewer
- Actions: Warn, Suspend, Resolve

## Technical Architecture

### App Structure
```
DEFENDO-AI/
├── DEFENDO_AIApp.swift          # Main app entry point
├── ContentView.swift            # Root view with navigation
├── SOSView.swift               # Emergency SOS functionality
├── BookingFlowView.swift       # 4-step booking wizard
├── MarketplaceView.swift       # Provider marketplace
├── BookingsView.swift          # User bookings management
├── ProfileView.swift           # User profile and settings
├── ProviderDashboardView.swift # Provider dashboard
├── AdminDashboardView.swift    # Admin dashboard
└── README.md                  # This documentation
```

### Key Components

#### AppState
Central state management for the entire app including:
- User authentication status
- Current user data
- User role (user, provider, admin, guest)
- Current screen navigation
- Mock data initialization

#### Navigation System
The app uses a centralized navigation system with `AppScreen` enum:
- `onboarding`: Initial app setup
- `dashboard`: Main user dashboard
- `sos`: Emergency SOS screen
- `booking`: Booking flow wizard
- `marketplace`: Provider marketplace
- `profile`: User profile management
- `providerDashboard`: Provider interface
- `adminDashboard`: Admin interface

#### Data Models
Comprehensive data models for all app entities:
- `User`: User profile and preferences
- `Booking`: Service bookings
- `Provider`: Service providers
- `EmergencyContact`: Emergency contacts
- `SOSAlert`: Emergency alerts
- `SafetyZone`: Safety mapping
- `ChatMessage`: Messaging system
- `AnalyticsData`: Analytics and reporting
- `IncidentReport`: Incident reporting

## UI/UX Design

### Design Principles
- **Mobile-first**: Optimized for iOS devices
- **Safety-focused**: Emergency features prominently displayed
- **Intuitive navigation**: Clear, accessible interface
- **Real-time updates**: Live data and status indicators
- **Accessibility**: Support for various user needs

### Color Scheme
- **Primary Blue**: #007AFF (iOS system blue)
- **Safety Red**: #FF3B30 (Emergency features)
- **Success Green**: #34C759 (Positive actions)
- **Warning Orange**: #FF9500 (Cautions)
- **Neutral Gray**: System gray colors

### Key UI Components
- **Floating SOS Button**: Always accessible emergency trigger
- **Progress Indicators**: Multi-step booking flow
- **Status Badges**: Clear status communication
- **Card-based Layout**: Organized information display
- **Tab Navigation**: Easy switching between sections

## Features Implementation

### Emergency SOS System
- One-tap emergency activation
- 5-minute countdown timer
- Safe word cancellation
- Slide-to-cancel mechanism
- Voice trigger support
- Automatic emergency services notification

### Booking System
- 4-step wizard process
- Service selection (Guard/Drone)
- Date and time picker
- Duration selection
- Location input
- Payment integration
- Provider matching

### Safety Features
- Real-time location tracking
- Safety score calculation
- Heat map visualization
- AI-powered risk assessment
- Emergency contact management
- Incident reporting

### Provider Management
- Service listing creation
- Availability management
- Booking acceptance/rejection
- Analytics and reporting
- Payment processing
- Verification system

## Future Enhancements

### Planned Features
1. **Live Drone Viewer**: Real-time drone feed viewing
2. **Community SOS Alerts**: Social-style emergency feed
3. **Chat System**: In-app secure messaging
4. **Advanced Analytics**: AI-powered insights
5. **Multi-language Support**: Internationalization
6. **Push Notifications**: Real-time alerts
7. **Payment Integration**: Secure payment processing
8. **Map Integration**: Advanced location services

### Technical Improvements
1. **Backend Integration**: API connectivity
2. **Real-time Data**: WebSocket connections
3. **Offline Support**: Local data caching
4. **Performance Optimization**: App performance tuning
5. **Security Enhancements**: Advanced security measures
6. **Testing Suite**: Comprehensive testing
7. **CI/CD Pipeline**: Automated deployment

## Getting Started

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0 or later
- Swift 5.9 or later

### Installation
1. Clone the repository
2. Open `DEFENDO-AI.xcodeproj` in Xcode
3. Select your target device or simulator
4. Build and run the project

### Development Setup
1. Ensure all Swift files are properly imported
2. Check that all dependencies are resolved
3. Verify app state initialization
4. Test navigation flow

## Contributing

### Code Style
- Follow Swift style guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Maintain consistent formatting

### Testing
- Test all user flows
- Verify emergency features
- Check provider functionality
- Validate admin features

## License

This project is proprietary software for SecureNow platform.

## Support

For technical support or feature requests, please contact the development team.

---

**SecureNow** - Your AI-powered security companion
