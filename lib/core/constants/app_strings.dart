class AppStrings {
  static const String appName = 'TruckCab';

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String ordersCollection = 'orders';
  static const String notificationsCollection = 'notifications';

  // Authentication
  static const String loginTitle = 'Login';
  static const String signupTitle = 'Sign Up';
  static const String emailLabel = 'Email';
  static const String passwordLabel = 'Password';
  static const String roleLabel = 'Select Role';

  // Roles
  static const String sellerRole = 'seller';
  static const String driverRole = 'driver';

  // Order Status
  static const String statusOpen = 'OPEN';
  static const String statusAccepted = 'ACCEPTED';
  static const String statusPickedUp = 'PICKED_UP';
  static const String statusOnTheWay = 'ON_THE_WAY';
  static const String statusDelivered = 'DELIVERED';

  // Notifications
  static const String notificationAccepted = 'Driver accepted your order';
  static const String notificationPickedUp = 'Driver picked up your package';
  static const String notificationOnTheWay = 'Driver is on the way';
  static const String notificationDelivered = 'Package delivered';
}