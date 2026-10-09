/// What kind of app posted a notification; decides how much evidence a
/// message needs before it counts as a payment.
enum AppKind { sms, email, payment, chat, other }

class AppKinds {
  static const ownPackage = 'com.expense.expense_tracker';

  static const _sms = {
    'com.google.android.apps.messaging',
    'com.samsung.android.messaging',
    'com.android.mms',
    'com.android.messaging',
    'com.oneplus.mms',
    'com.motorola.messaging',
    'com.truecaller',
    'com.textra',
  };

  static const _email = {
    'com.google.android.gm',
    'com.microsoft.office.outlook',
    'com.yahoo.mobile.client.android.mail',
    'ch.protonmail.android',
    'com.samsung.android.email.provider',
  };

  // UPI apps, wallets and well-known bank apps. Any package containing
  // "bank" is treated the same way (see [of]).
  static const _payment = {
    'com.google.android.apps.nbu.paisa.user', // Google Pay
    'com.phonepe.app',
    'net.one97.paytm',
    'com.dreamplug.androidapp', // CRED
    'in.amazon.mShop.android.shopping',
    'in.org.npci.upiapp', // BHIM
    'com.mobikwik_new',
    'com.freecharge.android',
    'com.myairtelapp',
    'money.jupiter',
    'com.epifi.paisa', // Fi
    'indwin.c3.shareapp', // slice
    'com.naviapp',
    'com.enstage.wibmo.hdfc', // PayZapp
    'com.sbi.lotusintouch', // YONO SBI
    'com.sbi.SBIFreedomPlus',
    'com.csam.icici.bank.imobile',
    'com.snapwork.hdfc',
    'com.axis.mobile',
    'com.msf.kbank.mobile', // Kotak
    'com.google.android.apps.walletnfcrel',
  };

  static const _chat = {
    'com.whatsapp',
    'com.whatsapp.w4b',
    'org.telegram.messenger',
    'com.instagram.android',
    'com.facebook.orca',
    'org.thoughtcrime.securesms',
    'com.snapchat.android',
    'com.discord',
    'com.Slack',
    'com.microsoft.teams',
    'com.google.android.apps.dynamite',
    'jp.naver.line.android',
  };

  static AppKind of(String package) {
    if (_sms.contains(package)) return AppKind.sms;
    if (_email.contains(package)) return AppKind.email;
    if (_chat.contains(package)) return AppKind.chat;
    if (_payment.contains(package) || package.toLowerCase().contains('bank')) {
      return AppKind.payment;
    }
    return AppKind.other;
  }

  /// A readable name for where an alert came from.
  static String label(String? package) => _labels[package] ?? switch (of(package ?? '')) {
        AppKind.sms => 'SMS',
        AppKind.email => 'Email',
        AppKind.payment => 'Bank or payment app',
        _ => package ?? 'Unknown app',
      };

  static const _labels = {
    'com.google.android.apps.messaging': 'Messages (SMS)',
    'com.samsung.android.messaging': 'Samsung Messages (SMS)',
    'com.truecaller': 'Truecaller (SMS)',
    'com.google.android.gm': 'Gmail',
    'com.microsoft.office.outlook': 'Outlook',
    'com.google.android.apps.nbu.paisa.user': 'Google Pay',
    'com.phonepe.app': 'PhonePe',
    'net.one97.paytm': 'Paytm',
    'com.dreamplug.androidapp': 'CRED',
    'in.amazon.mShop.android.shopping': 'Amazon Pay',
    'in.org.npci.upiapp': 'BHIM',
    'money.jupiter': 'Jupiter',
    'com.epifi.paisa': 'Fi',
    'indwin.c3.shareapp': 'slice',
    'com.naviapp': 'Navi',
    'com.enstage.wibmo.hdfc': 'PayZapp',
    'com.sbi.lotusintouch': 'YONO SBI',
    'com.csam.icici.bank.imobile': 'iMobile (ICICI)',
    'com.snapwork.hdfc': 'HDFC Bank',
    'com.axis.mobile': 'Axis Mobile',
    'com.msf.kbank.mobile': 'Kotak',
    'com.kotak811mobilebankingapp.instantsavingsupiscanandpayrecharge': 'Kotak 811',
    'com.google.android.apps.walletnfcrel': 'Google Wallet',
    'com.android.shell': 'Test (adb)',
  };

  /// Our own alerts must never be parsed back in.
  static bool isIgnored(String package) => package == ownPackage;
}
