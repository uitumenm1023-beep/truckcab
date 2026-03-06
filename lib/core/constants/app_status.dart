class AppStatus {
  static const String open = 'OPEN';
  static const String accepted = 'ACCEPTED';
  static const String pickedUp = 'PICKED_UP';
  static const String onTheWay = 'ON_THE_WAY';
  static const String delivered = 'DELIVERED';

  static const List<String> allStatuses = [
    open,
    accepted,
    pickedUp,
    onTheWay,
    delivered,
  ];
}