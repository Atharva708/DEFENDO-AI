# Mobile Number Authentication Setup Guide

## Overview
This guide explains how to set up and use mobile number authentication in the DEFENDO-AI app using Supabase.

## Prerequisites

### 1. Supabase Project Configuration
Before using mobile authentication, you need to configure your Supabase project:

1. **Enable Phone Authentication Provider:**
   - Go to your Supabase Dashboard
   - Navigate to Authentication > Providers
   - Enable the "Phone" provider

2. **Configure SMS Provider:**
   - Go to Authentication > Settings
   - Configure one of the supported SMS providers:
     - Twilio
     - MessageBird
     - Vonage
     - TextLocal
   - Add your API credentials

3. **Set up Phone Authentication Settings:**
   - Configure phone number validation rules
   - Set OTP expiration time (default: 60 seconds)
   - Configure SMS template if needed

### 2. App Configuration
Ensure your `Info.plist` contains the required Supabase configuration:

```xml
<key>SUPABASE_URL</key>
<string>https://your-project.supabase.co</string>
<key>SUPABASE_ANON_KEY</key>
<string>your-anon-key</string>
```

## Implementation Details

### Core Components

#### 1. SupabaseService.swift
- **`startOTP(for phoneNumber: String)`**: Sends OTP to the provided phone number
- **`verifyOTP(phoneNumber: String, code: String)`**: Verifies the OTP and creates/updates user profile
- **`ensureUserProfileExists(userId: String, phone: String)`**: Ensures user profile exists in the users table

#### 2. AuthService.swift
- Implements `PhoneOTPAuthenticating` protocol
- Handles authentication state management
- Updates user session after successful OTP verification

#### 3. AuthViewModel.swift
- Manages OTP flow UI state
- Handles phone number normalization
- Provides clean interface for OTP operations

#### 4. PhoneOTPLoginView.swift
- Complete UI for phone authentication
- Supports international phone numbers
- Handles OTP input and verification

### Phone Number Format Support

The implementation supports various phone number formats:

- **International format**: `+1 555 123 4567`
- **Indian numbers**: `9876543210` (automatically converted to `+919876543210`)
- **E.164 format**: `+15551234567`

### Usage Examples

#### Basic OTP Flow
```swift
// Send OTP
let authViewModel = AuthViewModel()
authViewModel.phoneNumber = "+15551234567"
await authViewModel.startOTP()

// Verify OTP
authViewModel.otpCode = "123456"
await authViewModel.verifyOTP()
```

#### Using AuthService Directly
```swift
let authService = AuthService()

// Send OTP
try await authService.requestOTP(phone: "+15551234567")

// Verify OTP
try await authService.verifyOTP(phone: "+15551234567", code: "123456")
```

#### Using SupabaseService Directly
```swift
let service = SupabaseService.shared

// Send OTP
try await service.startOTP(for: "+15551234567")

// Verify OTP
if let userId = try await service.verifyOTP(phoneNumber: "+15551234567", code: "123456") {
    print("User authenticated: \(userId)")
}
```

## UI Components

### PhoneOTPLoginView
A complete authentication view that includes:
- Phone number input with international support
- OTP input field
- Error and success message display
- Loading states
- Resend OTP functionality

### MobileAuthView
A simpler view with overlay OTP input:
- Basic phone number input
- OTP overlay modal
- Clean, minimal design

## Testing

### Test View
Use `MobileAuthTestView` to test the authentication flow:
- Test OTP sending
- Test OTP verification
- Test AuthService integration
- View detailed test results

### Test Phone Numbers
For development/testing, you can use:
- `+15551234567` (US test number)
- `+919876543210` (Indian test number)
- Any valid E.164 formatted number

## Security Considerations

1. **Phone Number Validation**: Always validate phone numbers on both client and server
2. **OTP Expiration**: OTPs expire after 60 seconds by default
3. **Rate Limiting**: Supabase provides built-in rate limiting for OTP requests
4. **SIM Swap Protection**: Consider additional verification for high-security applications

## Error Handling

The implementation includes comprehensive error handling for:
- Invalid phone number formats
- Network connectivity issues
- Supabase service errors
- OTP verification failures

## Database Schema

Ensure your Supabase database has a `users` table with the following structure:

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email TEXT,
    full_name TEXT,
    phone TEXT UNIQUE,
    role TEXT DEFAULT 'user',
    safety_score INTEGER DEFAULT 85,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Troubleshooting

### Common Issues

1. **OTP Not Received**: Check SMS provider configuration and phone number format
2. **Verification Failed**: Ensure OTP is entered within expiration time
3. **User Profile Not Created**: Check database permissions and table structure
4. **Authentication State Not Updated**: Verify AuthService state management

### Debug Mode
Enable detailed logging by setting:
```swift
AppConfig.Features.enableDetailedLogging = true
```

This will provide detailed logs for:
- OTP sending attempts
- Verification results
- User profile creation
- Session management

## Production Considerations

1. **SMS Costs**: Monitor SMS usage and costs
2. **User Experience**: Implement proper loading states and error messages
3. **Fallback Methods**: Consider email authentication as fallback
4. **Analytics**: Track authentication success rates and user behavior
5. **Compliance**: Ensure compliance with local privacy laws (GDPR, CCPA, etc.)

## Support

For issues or questions:
1. Check Supabase documentation
2. Review error logs with detailed logging enabled
3. Test with the provided test view
4. Verify Supabase project configuration
