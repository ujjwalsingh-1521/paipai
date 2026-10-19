// Payment notification samples. Sources noted per entry. All personal data is fake.
//
// "verified: true" means the template was found in a real-world source (URL in
// the comment above the entry). Most verified SMS templates come from the
// PennyWise open-source parser test-suite, whose fixtures are anonymised real
// bank SMS:
//   PW  = https://github.com/sarim2000/pennywiseai-tracker/blob/main/parser-core/src/test/kotlin/
//   PWM = https://github.com/sarim2000/pennywiseai-tracker/blob/main/parser-core/src/main/kotlin/com/pennywiseai/parser/core/bank/
// Names, VPAs, account digits and references were replaced with fake values
// while keeping their shape (12-digit UPI refs, XX1234 tails, etc).
// "verified: false" entries are best-effort reconstructions.

class PaymentSample {
  final String id; // unique snake_case, e.g. 'sbi_upi_debit_1'
  final String app; // Android package that posts the notification
  final String title; // notification title (for SMS: the sender, e.g. 'AX-HDFCBK' or 'HDFC Bank')
  final String text; // notification body
  final bool verified;
  final SampleExpect? expect; // null => app must IGNORE this notification
  const PaymentSample({required this.id, required this.app, required this.title, required this.text, required this.verified, this.expect});
}

class SampleExpect {
  final double amount;
  final String direction; // 'debit' or 'credit'
  final String? payee; // case-insensitive substring the parsed payee/merchant must contain; null = don't check
  final String? reference; // exact digits if the text has a UPI/RRN/UTR ref
  final String? accountTail; // last 3-4 digits if the text shows them (e.g. '1234')
  const SampleExpect({required this.amount, required this.direction, this.payee, this.reference, this.accountTail});
}

const _gMessages = 'com.google.android.apps.messaging';
const _samsungMessages = 'com.samsung.android.messaging';
const _gmail = 'com.google.android.gm';
const _gpay = 'com.google.android.apps.nbu.paisa.user';
const _phonepe = 'com.phonepe.app';
const _paytm = 'net.one97.paytm';
const _cred = 'com.dreamplug.androidapp';
const _amazon = 'in.amazon.mShop.android.shopping';
const _bhim = 'in.org.npci.upiapp';
const _whatsapp = 'com.whatsapp';
const _hdfcApp = 'com.snapwork.hdfc';
const _yono = 'com.sbi.lotusintouch';
const _iMobile = 'com.csam.icici.bank.imobile';
const _kotak811 = 'com.kotak811mobilebankingapp.instantsavingsupiscanandpayrecharge';

const paymentSamples = <PaymentSample>[
  // ───────────────────────────── SBI ─────────────────────────────
  // Source: PWM SBIBankParser.kt ("A/C debited by 20.0 (UPI format)", "trf to Merchant (UPI format)")
  PaymentSample(
    id: 'sbi_upi_debit_1',
    app: _gMessages,
    title: 'JD-SBIUPI-S',
    text: 'Dear UPI user A/C X4821 debited by 20.0 on date 14Sep26 trf to RAMESH KUMAR Refno 625712345678. If not u? call 1800111109. -SBI',
    verified: true,
    expect: SampleExpect(amount: 20.0, direction: 'debit', payee: 'RAMESH', reference: '625712345678', accountTail: '4821'),
  ),
  // Same template as sbi_upi_debit_1 (group: PhonePe + SBI)
  PaymentSample(
    id: 'sbi_upi_debit_anita',
    app: _gMessages,
    title: 'VM-SBIUPI-S',
    text: 'Dear UPI user A/C X4821 debited by 1200.0 on date 02Oct26 trf to ANITA SHARMA Refno 627712340011. If not u? call 1800111109. -SBI',
    verified: true,
    expect: SampleExpect(amount: 1200.0, direction: 'debit', payee: 'ANITA', reference: '627712340011', accountTail: '4821'),
  ),
  // Source: PWM SBIBankParser.kt ("A/c credited by Rs.500 (UPI format)")
  PaymentSample(
    id: 'sbi_upi_credit_1',
    app: _gMessages,
    title: 'AD-SBIUPI-S',
    text: 'Dear SBI UPI User, ur A/cX4821 credited by Rs350 on 02Oct26 by (Ref no 627798765432)',
    verified: true,
    expect: SampleExpect(amount: 350, direction: 'credit', reference: '627798765432', accountTail: '4821'),
  ),
  // Source: PW TestSBIParser.kt
  PaymentSample(
    id: 'sbi_debit_card_pos_1',
    app: _gMessages,
    title: 'AD-ATMSBI-S',
    text: 'Dear Customer, transaction number 4417 for Rs.383.00 by SBI Debit Card 7702 done at BIGBASKET on 13Sep26 at 21:38:26. Your updated available balance is Rs.12,450.10. If not done by you, forward this SMS to 7400165218/ call 1800111109/9449112211 to block card. GOI helpline for cyber fraud 1930.',
    verified: true,
    expect: SampleExpect(amount: 383.00, direction: 'debit', payee: 'BIGBASKET', accountTail: '7702'),
  ),
  // Source: PW TestSBIParser.kt
  PaymentSample(
    id: 'sbi_generic_debit_1',
    app: _samsungMessages,
    title: 'BZ-SBIINB',
    text: 'Rs.500 debited from A/c X4821 on 13Sep26. Avl Bal Rs.11,950.10',
    verified: true,
    expect: SampleExpect(amount: 500, direction: 'debit', accountTail: '4821'),
  ),
  PaymentSample(
    id: 'sbi_atm_withdrawal_1',
    app: _gMessages,
    title: 'AD-ATMSBI-S',
    text: 'Dear Customer, Rs.5000 withdrawn at SBI ATM S1BW000123402 from A/cX4821 on 14Sep26 Transaction Number 3318. Available Balance Rs.6,950.10. If not withdrawn by you, forward this SMS to 7400165218/ call 1800111109/9449112211 to block card. GOI helpline for cyber fraud 1930.',
    verified: false,
    expect: SampleExpect(amount: 5000, direction: 'debit', accountTail: '4821'),
  ),
  PaymentSample(
    id: 'sbi_salary_credit_1',
    app: _gMessages,
    title: 'VM-SBIINB',
    text: 'Dear Customer, Your A/C XXXXX4821 has credit for BY SALARY ACME SOFTWARE of Rs 1,25,000.50 on 30/09/26. Avl Bal Rs 1,31,950.60.-SBI',
    verified: false,
    expect: SampleExpect(amount: 125000.50, direction: 'credit', payee: 'ACME', accountTail: '4821'),
  ),
  // Source: PW TestSBIParser.kt
  PaymentSample(
    id: 'sbi_card_spend_1',
    app: _gMessages,
    title: 'AX-SBICRD-S',
    text: 'Rs.259.00 spent on your SBI Credit Card ending with 3391 on 15Jan26. Your available limit is Rs.41,235.00. If not done by you, call 39 02 02 02.',
    verified: true,
    expect: SampleExpect(amount: 259.00, direction: 'debit', accountTail: '3391'),
  ),
  // Source: PW TestSBIParser.kt
  PaymentSample(
    id: 'sbi_card_spend_merchant',
    app: _gMessages,
    title: 'AX-SBICRD-S',
    text: 'Rs.90.00 spent on your SBI Credit Card ending 3391 at ZEPTO MARKETPLACE on 13/02/26. Trxn. not done by you? Report at https://sbicard.com/Dispute',
    verified: true,
    expect: SampleExpect(amount: 90.00, direction: 'debit', payee: 'ZEPTO', accountTail: '3391'),
  ),
  PaymentSample(
    id: 'yono_app_upi_debit',
    app: _yono,
    title: 'YONO SBI',
    text: 'Your A/c XX4821 is debited with Rs.1,000.00 for UPI transfer to SURESH NAIR. UPI Ref No 627712349999.',
    verified: false,
    expect: SampleExpect(amount: 1000.00, direction: 'debit', payee: 'SURESH', reference: '627712349999', accountTail: '4821'),
  ),

  // ───────────────────────────── HDFC ─────────────────────────────
  // Source: PW TestHDFCBankParser.kt (real SMS has line breaks; same template)
  PaymentSample(
    id: 'hdfc_upi_debit_swiggy',
    app: _gMessages,
    title: 'AX-HDFCBK-S',
    text: 'Sent Rs.450.00\nFrom HDFC Bank A/C *5521\nTo SWIGGY LIMITED\nOn 02/10/26\nRef 627512345601\nNot You?\nCall 18002586161/SMS BLOCK UPI to 7308080808',
    verified: true,
    expect: SampleExpect(amount: 450.00, direction: 'debit', payee: 'SWIGGY', reference: '627512345601', accountTail: '5521'),
  ),
  // Source: PW TestHDFCBankParser.kt
  PaymentSample(
    id: 'hdfc_upi_debit_rs1',
    app: _gMessages,
    title: 'VM-HDFCBK-S',
    text: 'Sent Rs.1.00 From HDFC Bank A/C *5521 To KIRAN TEA STALL On 01/10/26 Ref 627411110000 Not You? Call 18002586161/SMS BLOCK UPI to 7308080808',
    verified: true,
    expect: SampleExpect(amount: 1.00, direction: 'debit', payee: 'KIRAN', reference: '627411110000', accountTail: '5521'),
  ),
  // Source: PW TestHDFCBankParser.kt
  PaymentSample(
    id: 'hdfc_upi_debit_vpa',
    app: _gMessages,
    title: 'JM-HDFCBK',
    text: 'Rs.500.00 debited from A/c XX5521 on 20-Oct-25 to blinkit.payu@hdfcbank (UPI Ref No 529312345678)',
    verified: true,
    expect: SampleExpect(amount: 500.00, direction: 'debit', payee: 'blinkit', reference: '529312345678', accountTail: '5521'),
  ),
  // Source: PWM HDFCBankParser.kt ("from VPA username@provider (UPI reference)")
  PaymentSample(
    id: 'hdfc_upi_credit_priya',
    app: _gMessages,
    title: 'AD-HDFCBK-S',
    text: 'Rs.2500.00 credited to HDFC Bank A/c XX5521 on 02-10-26 from VPA priya.nair@okicici (UPI 627598760001)',
    verified: true,
    expect: SampleExpect(amount: 2500.00, direction: 'credit', payee: 'priya', reference: '627598760001', accountTail: '5521'),
  ),
  // Source: PW TestHDFCBankParser.kt
  PaymentSample(
    id: 'hdfc_neft_salary_credit',
    app: _gMessages,
    title: 'VM-HDFCBK-S',
    text: 'Update! INR 85,000.00 deposited in HDFC Bank A/c XX5521 on 30-SEP-26 for NEFT Cr-CITI0100000-ACME TECHNOLOGIES-RAHUL VERMA-CITIN26273849501.Avl bal INR 92,410.00. Cheque deposits in A/C are subject to clearing',
    verified: true,
    expect: SampleExpect(amount: 85000.00, direction: 'credit', payee: 'ACME', accountTail: '5521'),
  ),
  // Source: PW TestHDFCBankParser.kt
  PaymentSample(
    id: 'hdfc_netbanking_payment',
    app: _gMessages,
    title: 'VK-HDFCBK',
    text: 'Payment Successful! Rs. 3,499.00 from A/c ****5521 to BESCOM via HDFC Bank NetBanking. Not you?Call 18002586161',
    verified: true,
    expect: SampleExpect(amount: 3499.00, direction: 'debit', payee: 'BESCOM', accountTail: '5521'),
  ),
  // Source: PWM HDFCBankParser.kt ("Spent Rs.xxx From HDFC Bank Card xxxx At [MERCHANT] On xxx")
  PaymentSample(
    id: 'hdfc_cc_spend_amazon',
    app: _gMessages,
    title: 'AD-HDFCBK-S',
    text: 'Spent Rs.1,299.00 From HDFC Bank Card x7788 At AMAZON PAY INDIA On 2026-10-01:19:22:10 Bal Rs.45,210.00 Not You? Call 18002586161/SMS BLOCK CC 7788 to 7308080808',
    verified: true,
    expect: SampleExpect(amount: 1299.00, direction: 'debit', payee: 'AMAZON', accountTail: '7788'),
  ),
  // Source: PWM HDFCBankParser.kt ("Txn Rs.X On HDFC Bank Card At [MERCHANT] by UPI")
  PaymentSample(
    id: 'hdfc_cc_upi_txn',
    app: _gMessages,
    title: 'AX-HDFCBK-S',
    text: 'Txn Rs.120.00\nOn HDFC Bank Card 7788\nAt zomato.payu@hdfcbank\nby UPI 627512340987\nOn 01-10\nNot You?\nCall 18002586161/SMS BLOCK CC 7788 to 7308080808',
    verified: true,
    expect: SampleExpect(amount: 120.00, direction: 'debit', payee: 'zomato', reference: '627512340987', accountTail: '7788'),
  ),
  // Source: PW TestHDFCBankParser.kt
  PaymentSample(
    id: 'hdfc_cc_reversal_credit',
    app: _gMessages,
    title: 'AD-HDFCBK-S',
    text: 'Transaction Reversed!On HDFC Bank CREDIT Card xx7788 Amt: Rs.862.16 By AMAZON                000 On 2026-08-21:05:20:26',
    verified: true,
    expect: SampleExpect(amount: 862.16, direction: 'credit', payee: 'AMAZON', accountTail: '7788'),
  ),
  PaymentSample(
    id: 'hdfc_app_upi_debit',
    app: _hdfcApp,
    title: 'HDFC Bank',
    text: 'Rs. 799.00 debited from A/c XX5521 to VPA bookmyshow@icici on 03-10-26. UPI Ref No 627612345111.',
    verified: false,
    expect: SampleExpect(amount: 799.00, direction: 'debit', payee: 'bookmyshow', reference: '627612345111', accountTail: '5521'),
  ),
  PaymentSample(
    id: 'hdfc_email_upi_debit_swiggy',
    app: _gmail,
    title: 'HDFC Bank InstaAlerts',
    text: '❗ You have done a UPI txn. Check details!\nDear Customer, Rs.450.00 has been debited from account 5521 to VPA swiggy@hdfcbank SWIGGY LIMITED on 02-10-26. Your UPI transaction reference number is 627512345601.',
    verified: false,
    expect: SampleExpect(amount: 450.00, direction: 'debit', payee: 'SWIGGY', reference: '627512345601', accountTail: '5521'),
  ),
  PaymentSample(
    id: 'hdfc_email_cc_spend_amazon',
    app: _gmail,
    title: 'HDFC Bank InstaAlerts',
    text: 'Alert : Update on your HDFC Bank Credit Card\nDear Card Member, Thank you for using your HDFC Bank Credit Card ending 7788 for Rs 1299.00 at AMAZON PAY INDIA on 01-10-2026 19:22:10.',
    verified: false,
    expect: SampleExpect(amount: 1299.00, direction: 'debit', payee: 'AMAZON', accountTail: '7788'),
  ),

  // ───────────────────────────── ICICI ─────────────────────────────
  // Source: PW TestICICIBankParser.kt  (debit SMS that also says "<payee> credited")
  PaymentSample(
    id: 'icici_upi_debit_payee_credited',
    app: _gMessages,
    title: 'VM-ICICIT-S',
    text: 'ICICI Bank Acct XX308 debited for Rs 180.00 on 10-Nov-25; HOTEL ANNAPURNA credited. UPI:568012345678. Call 18002662 for dispute. SMS BLOCK 308 to 9215676766. 06:33 PM',
    verified: true,
    expect: SampleExpect(amount: 180.00, direction: 'debit', payee: 'ANNAPURNA', reference: '568012345678', accountTail: '308'),
  ),
  // Source: PW TestICICIBankParser.kt (two accounts; ours is the debited one)
  PaymentSample(
    id: 'icici_imps_debit',
    app: _gMessages,
    title: 'AX-ICICIB',
    text: 'ICICI Bank Acct XX308 debited with Rs 10,000 on 20-Dec-25 & Acct XX456 credited.IMPS:535412345678. Call 18002662 for dispute or SMS BLOCK 308 to 9215676766',
    verified: true,
    expect: SampleExpect(amount: 10000, direction: 'debit', reference: '535412345678', accountTail: '308'),
  ),
  // Source: PW TestICICIBankParser.kt
  PaymentSample(
    id: 'icici_salary_credit',
    app: _gMessages,
    title: 'JD-ICICIT-S',
    text: 'ICICI Bank Account XX308 credited:Rs. 18,832.00 on 28-Feb-26. Info INF*000169831922*ACME SAL FE. Available Balance is Rs. 28,076.14.',
    verified: true,
    expect: SampleExpect(amount: 18832.00, direction: 'credit', accountTail: '308'),
  ),
  // Source: PW TestICICIBankParser.kt
  PaymentSample(
    id: 'icici_neft_credit',
    app: _gMessages,
    title: 'JD-ICICIT-S',
    text: 'ICICI Bank Account XX308 credited:Rs. 6,000.00 on 24-Jun-26. Info NEFT-FDRLN26176543210-SURESH NAIR. Available Balance is Rs. 16,079.44.',
    verified: true,
    expect: SampleExpect(amount: 6000.00, direction: 'credit', payee: 'SURESH', accountTail: '308'),
  ),
  // Source: PW TestICICIBankParser.kt
  PaymentSample(
    id: 'icici_atm_withdrawal',
    app: _gMessages,
    title: 'VM-ICICIB',
    text: 'ICICI Bank Acc XX308 debited Rs. 10,000.00 on 20-Jan-26 NFS*CASH WDL*. Avb Bal Rs. 3,943.84. To dispute Call 18002662 or SMS BLOCK 308 to 9215676766 .',
    verified: true,
    expect: SampleExpect(amount: 10000.00, direction: 'debit', accountTail: '308'),
  ),
  // Source: PW TestICICIBankParser.kt (EMI via NACH/BIL)
  PaymentSample(
    id: 'icici_emi_autodebit',
    app: _gMessages,
    title: 'VM-ICICIB',
    text: 'ICICI Bank Acc XX308 debited Rs. 8,927.00 on 07-Jun-26 InfoBIL*Auto Loan.Avl Bal Rs. 1,248.78.To dispute call 18002662 or SMS BLOCK 308 to 9215676766',
    verified: true,
    expect: SampleExpect(amount: 8927.00, direction: 'debit', accountTail: '308'),
  ),
  // Source: PW TestICICIBankParser.kt (autopay executed)
  PaymentSample(
    id: 'icici_autopay_netflix_executed',
    app: _gMessages,
    title: 'AX-ICICIT-S',
    text: 'Your account has been debited with Rs 649.00 towards Netflix Entertainment Ser for AutoPay MERCHANTMANDATE. RRN 627712345670. Avl Bal Rs 10,000.00-ICICI Bank',
    verified: true,
    expect: SampleExpect(amount: 649.00, direction: 'debit', payee: 'Netflix', reference: '627712345670'),
  ),
  // Source: PW TestICICIBankParser.kt
  PaymentSample(
    id: 'icici_cc_spend_swiggy',
    app: _gMessages,
    title: 'AD-ICICIT-S',
    text: 'INR 500.00 spent using ICICI Bank Card XX5678 on 06-Sep-26 on Swiggy. Avl Limit: INR 1,50,000.00. If not you, call 1800 2662/SMS BLOCK 5678 to 9215676766.',
    verified: true,
    expect: SampleExpect(amount: 500.00, direction: 'debit', payee: 'Swiggy', accountTail: '5678'),
  ),
  PaymentSample(
    id: 'icici_email_cc_spend_swiggy',
    app: _gmail,
    title: 'ICICI Bank',
    text: 'Transaction alert for your ICICI Bank Credit Card\nDear Customer, Your ICICI Bank Credit Card XX5678 has been used for a transaction of INR 500.00 on Sep 06, 2026 at 08:14:22. Info: SWIGGY.',
    verified: false,
    expect: SampleExpect(amount: 500.00, direction: 'debit', payee: 'SWIGGY', accountTail: '5678'),
  ),
  PaymentSample(
    id: 'icici_imobile_upi_credit',
    app: _iMobile,
    title: 'iMobile Pay',
    text: 'You have received ₹1,500.00 from rohit.mehta@okaxis in your ICICI Bank Acct XX308. UPI Ref: 627812340001',
    verified: false,
    expect: SampleExpect(amount: 1500.00, direction: 'credit', payee: 'rohit', reference: '627812340001', accountTail: '308'),
  ),

  // ───────────────────────────── Axis ─────────────────────────────
  // Source: PW TestAxisBankParser.kt (debit card POS)
  PaymentSample(
    id: 'axis_debit_card_pos',
    app: _gMessages,
    title: 'AX-AXISBK-S',
    text: 'INR 209.00 debited from A/c no. XX312225 on BURGRILL 04-12-2025 13:13:27 IST. Avl bal: INR 9,791.00. Not you? SMS BLOCKCARD XX0023 to +919951860002 - Axis Bank',
    verified: true,
    expect: SampleExpect(amount: 209.00, direction: 'debit', payee: 'BURGRILL', accountTail: '2225'),
  ),
  // Source: PW TestAxisBankParser.kt (multi-line credit card spend)
  PaymentSample(
    id: 'axis_cc_spend_multiline',
    app: _gMessages,
    title: 'AX-AXISBK-S',
    text: 'Spent INR 131\nAxis Bank Card no. XX0818\n05-10-25 09:43:27 IST\nSwiggy Limi\nAvl Limit: INR 217162.72\nNot you? SMS BLOCK 0818 to 919951860002',
    verified: true,
    expect: SampleExpect(amount: 131, direction: 'debit', payee: 'Swiggy', accountTail: '0818'),
  ),
  PaymentSample(
    id: 'axis_upi_debit_blinkit',
    app: _gMessages,
    title: 'VM-AXISBK-S',
    text: 'INR 250.00 debited\nA/c no. XX312225\n02-10-26, 13:05:11\nUPI/P2M/627512346789/BLINKIT\nNot you? SMS BLOCKUPI Cust ID to 919951860002\nAxis Bank',
    verified: false,
    expect: SampleExpect(amount: 250.00, direction: 'debit', payee: 'BLINKIT', reference: '627512346789', accountTail: '2225'),
  ),
  PaymentSample(
    id: 'axis_upi_credit',
    app: _gMessages,
    title: 'VM-AXISBK-S',
    text: 'INR 1,000.00 credited\nA/c no. XX312225\n02-10-26, 18:22:40 IST\nUPI/P2A/627598761234/NEHA GUPTA\nNot you? SMS BLOCKUPI Cust ID to 919951860002\nAxis Bank',
    verified: false,
    expect: SampleExpect(amount: 1000.00, direction: 'credit', payee: 'NEHA', reference: '627598761234', accountTail: '2225'),
  ),
  PaymentSample(
    id: 'axis_email_upi_debit_blinkit',
    app: _gmail,
    title: 'Axis Bank Alerts',
    text: 'Debit transaction alert for Axis Bank A/c\nDear Customer, INR 250.00 has been debited from your A/c no. XX2225 on 02-10-2026 at 13:05:11 IST towards UPI/P2M/627512346789/BLINKIT.',
    verified: false,
    expect: SampleExpect(amount: 250.00, direction: 'debit', payee: 'BLINKIT', reference: '627512346789', accountTail: '2225'),
  ),

  // ───────────────────────────── Kotak ─────────────────────────────
  // Source: the user's own phone, 2026-10-05 (Kotak 811 app + Kotak SMS for the
  // same payment; they merge by UPI ref). Shop names, a/c and refs changed.
  PaymentSample(
    id: 'kotak811_app_paid_merchant',
    app: _kotak811,
    title: '₹506.00 paid to Swiggy Ltd',
    text: 'Amount debited from XX5678. Check out details.',
    verified: true,
    expect: SampleExpect(amount: 506.00, direction: 'debit', payee: 'Swiggy', accountTail: '5678'),
  ),
  PaymentSample(
    id: 'kotak811_app_paid_comma_amount',
    app: _kotak811,
    title: '₹4,002.50 paid to AVENUE SUPERMARTS LTD',
    text: 'Amount debited from XX5678. Check out details.',
    verified: true,
    expect: SampleExpect(amount: 4002.50, direction: 'debit', payee: 'Avenue Supermarts', accountTail: '5678'),
  ),
  PaymentSample(
    id: 'kotak811_app_sent_person',
    app: _kotak811,
    title: '₹250.00 sent to RAHUL  VERMA',
    text: 'Amount debited from XX5678. Check out details.',
    verified: true,
    expect: SampleExpect(amount: 250.00, direction: 'debit', payee: 'Rahul', accountTail: '5678'),
  ),
  PaymentSample(
    id: 'kotak_sms_sent_merchant_2026',
    app: _gMessages,
    title: 'VK-KOTAKB-S',
    text: 'Sent Rs.20.00 from Kotak Bank A/c X5678 to Mohan Pan Bhandar on 04-10-26. UPI Ref 627706800001. Not done by you? Tap https://kotak.bank.in/KBANKT/Fraud',
    verified: true,
    expect: SampleExpect(amount: 20.00, direction: 'debit', payee: 'Mohan Pan Bhandar', reference: '627706800001', accountTail: '5678'),
  ),
  // Source: the user's own phone, 2026-10-14: one ₹60 received, seen four times
  // (Kotak SMS, SBI UPI SMS, Google Pay at once; the Kotak 811 app 14 min later,
  // without a reference). Names, a/c and refs changed.
  PaymentSample(
    id: 'kotak_sms_received_person',
    app: _gMessages,
    title: 'AD-KOTAKB-S',
    text: 'Received Rs.60.00 in your Kotak Bank AC 5678 from KARAN MEHTA on 14-10-26.UPI Ref:628703011111',
    verified: true,
    expect: SampleExpect(amount: 60.00, direction: 'credit', payee: 'Karan', reference: '628703011111', accountTail: '5678'),
  ),
  PaymentSample(
    id: 'sbi_upi_credited_transfer_from',
    app: _gMessages,
    title: 'VD-SBIUPI-S',
    text: 'Dear SBI User, your A/c X5678-credited by Rs.60 on 14Oct26 transfer from KARAN MEHTA Ref No 628703011111 -SBI',
    verified: true,
    expect: SampleExpect(amount: 60.00, direction: 'credit', payee: 'Karan', reference: '628703011111', accountTail: '5678'),
  ),
  PaymentSample(
    id: 'gpay_paid_you_via_other_app',
    app: _gpay,
    title: 'KARAN MEHTA paid you ₹60.00',
    text: 'Paid via SuperMoney UPI',
    verified: true,
    expect: SampleExpect(amount: 60.00, direction: 'credit', payee: 'Karan'),
  ),
  PaymentSample(
    id: 'kotak811_app_received_person',
    app: _kotak811,
    title: '₹60.00 received from KARAN MEHTA',
    text: 'Amount credited to XX5678. Check out details.',
    verified: true,
    expect: SampleExpect(amount: 60.00, direction: 'credit', payee: 'Karan', accountTail: '5678'),
  ),
  // Source: the user's own phone, 2026-10-17: one ₹220 payment; the Kotak 811
  // app alert came 14 min after the SMS, without a reference, and its payee
  // has an extra word. Names, a/c and refs changed.
  PaymentSample(
    id: 'kotak_sms_sent_shop_short_name',
    app: _gMessages,
    title: 'JM-KOTAKB-S',
    text: 'Sent Rs.220.00 from Kotak Bank A/c X5678 to Ganesh Vegitable  on 17-10-26. UPI Ref 629067600001. Not done by you? Tap https://kotak.bank.in/KBANKT/Fraud',
    verified: true,
    expect: SampleExpect(amount: 220.00, direction: 'debit', payee: 'Ganesh Vegitable', reference: '629067600001', accountTail: '5678'),
  ),
  PaymentSample(
    id: 'kotak811_app_paid_shop_long_name',
    app: _kotak811,
    title: '₹220.00 paid to Ganesh Vegitable shop',
    text: 'Amount debited from XX5678. Check out details.',
    verified: true,
    expect: SampleExpect(amount: 220.00, direction: 'debit', payee: 'Ganesh Vegitable shop', accountTail: '5678'),
  ),
  // Source: the user's own phone, 2026-10-16: a loan ad that was saved as a
  // ₹5,500 expense. Link changed. Ignored for its -P (promotional) sender...
  PaymentSample(
    id: 'ignore_sms_meesho_loan_promo',
    app: _gMessages,
    title: 'AX-MEESHO-P',
    text: 'Get a personal loan of Rs. 5,500 on Meesho sent directly to your bank account. Check your offer now: https://ltl.sh/abc123',
    verified: true,
  ),
  // ...and for its wording, from a header without the suffix.
  PaymentSample(
    id: 'ignore_sms_loan_promo_no_suffix',
    app: _gMessages,
    title: 'AX-MEESHO',
    text: 'Get a personal loan of Rs. 5,500 on Meesho sent directly to your bank account. Check your offer now: https://ltl.sh/abc123',
    verified: false,
  ),
  // A bank alert forwarded by a friend: from a phone number, so not the user's payment.
  PaymentSample(
    id: 'ignore_sms_forwarded_from_person',
    app: _gMessages,
    title: '+91 98123 45678',
    text: 'Sent Rs.500.00 from Kotak Bank A/c X5678 to RAHUL VERMA on 19-10-26. UPI Ref 629200000001. Not done by you? Tap https://kotak.bank.in/KBANKT/Fraud',
    verified: false,
  ),
  // Source: the user's own phone, 2026-10-05: a promo from the Kotak 811 app.
  PaymentSample(
    id: 'ignore_kotak811_loan_promo',
    app: _kotak811,
    title: 'Bring home the new foldable phone.',
    text: '₹5 lakh Kotak Personal Loan available. Tap to claim. *T&C apply.',
    verified: true,
  ),
  // Source: the user's own phone, 2026-10-05: a GPay promo.
  PaymentSample(
    id: 'ignore_gpay_loan_promo',
    app: _gpay,
    title: "Your low EMI loan is ready 🌴",
    text: 'EMI starts at ₹1,000 per month. Check your loan offer now!',
    verified: true,
  ),
  // Source: the user's own phone, 2026-10-05: a Swiggy (Toing) order receipt
  // email, shortened, address changed. It used to be read as "₹80 paid to
  // issue an invoice directly" (the first amount is a saving, the "to" is
  // fine print). The labelled total is what was paid, and the sender is the
  // shop; the bank alert for the same ₹506 merges with it.
  PaymentSample(
    id: 'swiggy_toing_receipt_email',
    app: _gmail,
    title: 'Toing',
    text: 'Your Toing order was successfully delivered\n\n₹80 saved on this order\n₹80 saved with Promotional Savings\nORDER JOURNEY\nFaasos - Wraps, Rolls & Shawarma\nMG Road, Bengaluru\nOct 5, 12:22 PM\nOrder ID: 250152700000000\nBILL DETAILS\nChipotle Potato Shots Wrap x2\n₹534\nDelivery Fee | 2.9 kms\n₹25\nTaxes\n₹27.20\nPaid Via Bank\n₹506\nDisclaimer: Attached is the invoice for the restaurant services provided by the outlet. For items not covered in the attached invoice, the outlet shall be responsible to issue an invoice directly to you.',
    verified: true,
    expect: SampleExpect(amount: 506, direction: 'debit', payee: 'Toing'),
  ),
  // Source: PW TestKotakBankParser.kt
  PaymentSample(
    id: 'kotak_upi_debit_paytmqr',
    app: _gMessages,
    title: 'AD-KOTAKB-S',
    text: 'Sent Rs.60.00 from Kotak Bank AC X5678 to paytmqr281005050101abcdxyz@paytm on 02-10-26.UPI Ref 528712349876. Not you, https://kotak.com/KBANKT/Fraud',
    verified: true,
    expect: SampleExpect(amount: 60.00, direction: 'debit', payee: 'paytmqr', reference: '528712349876', accountTail: '5678'),
  ),
  // Source: PW TestKotakBankParser.kt (newer template)
  PaymentSample(
    id: 'kotak_upi_debit_newformat',
    app: _gMessages,
    title: 'JM-KOTAKD-S',
    text: 'Sent Rs.90.00 from XXXXXX5678 to RAMESH on 25/05/2026. UPI ref no. 653114200001. Not you? Tap https://kotk.in/KOTAKD/Ab12Cd to report -Kotak',
    verified: true,
    expect: SampleExpect(amount: 90.00, direction: 'debit', payee: 'RAMESH', reference: '653114200001', accountTail: '5678'),
  ),
  // Source: PW TestKotakBankParser.kt
  PaymentSample(
    id: 'kotak_upi_credit',
    app: _gMessages,
    title: 'AD-KOTAKB-S',
    text: 'Received Rs.250.00 in your Kotak Bank AC X5678 from rohit.m@oksbi on 14-10-25.UPI Ref 528798761234. Not you, https://kotak.com/KBANKT/Fraud',
    verified: true,
    expect: SampleExpect(amount: 250.00, direction: 'credit', payee: 'rohit', reference: '528798761234', accountTail: '5678'),
  ),
  // Source: PW TestKotakBankParser.kt
  PaymentSample(
    id: 'kotak_imps_credit',
    app: _gMessages,
    title: 'VM-KOTAKB',
    text: 'Received Rs. 329.00 on 15-04-26 in your Kotak Bank A/C x5678 by an A/C linked to mobile x111. IMPS Ref no 610511412340.',
    verified: true,
    expect: SampleExpect(amount: 329.00, direction: 'credit', reference: '610511412340', accountTail: '5678'),
  ),
  // Source: PW TestKotakBankParser.kt (cashback credited => credit)
  PaymentSample(
    id: 'kotak_cashback_credit',
    app: _gMessages,
    title: 'AD-KOTAKB-S',
    text: 'Cashback of Rs.50.00 has been sent to your Kotak Bank A/c x5678. Credited on 14-10-25. UPI Ref 528711112222',
    verified: true,
    expect: SampleExpect(amount: 50.00, direction: 'credit', reference: '528711112222', accountTail: '5678'),
  ),
  // Source: PW TestKotakBankParser.kt (refund => credit)
  PaymentSample(
    id: 'kotak_cc_refund',
    app: _gMessages,
    title: 'VM-KOTAKB-S',
    text: 'INR 1,499 from MYNTRA refunded to your Kotak Credit Card x8848 on 17-Jul-2026. Opted for EMI? Please call 18602662666 to cancel.',
    verified: true,
    expect: SampleExpect(amount: 1499, direction: 'credit', payee: 'MYNTRA', accountTail: '8848'),
  ),
  // Source: PW TestKotakBankParser.kt (UPI spend on credit card)
  PaymentSample(
    id: 'kotak_cc_upi_spend',
    app: _gMessages,
    title: 'VM-KOTAKB-S',
    text: 'INR 20 spent on Kotak Credit Card x8848 on 23-JAN-2026 at UPI-638903921672-CORN. Avl limit INR 73733.02 Fraud? https://www.kotak.bank.in/KBANKT/querytxn',
    verified: true,
    expect: SampleExpect(amount: 20, direction: 'debit', reference: '638903921672', accountTail: '8848'),
  ),

  // ───────────────────────────── PNB ─────────────────────────────
  // Source: PW PNBBankParserTest.kt
  PaymentSample(
    id: 'pnb_upi_credit',
    app: _gMessages,
    title: 'BP-PNBSMS',
    text: 'Ac XX7582 Credited with Rs.4750.00 11-07-2026 08:53:21 thru UPI . Aval Bal Rs.82431.67 CR. (UPI Ref ID:714628300001) Helpline 18001800/18002021-PNB',
    verified: true,
    expect: SampleExpect(amount: 4750.00, direction: 'credit', reference: '714628300001', accountTail: '7582'),
  ),
  // Source: PW PNBBankParserTest.kt (debited + "a/c XX291 credited")
  PaymentSample(
    id: 'pnb_imps_debit',
    app: _gMessages,
    title: 'BP-PNBSMS',
    text: 'Your a/c no XX847 is debited for Rs 3200 on 11-07-26 03:14:52 and a/c XX291 credited (IMPS Ref no 712845930000) .If not done by you, pl. forward this SMS from registered mobile to 9264092640 to report unauthorized txn & block IBS/MBS. Download PNB ONE.-PNB',
    verified: true,
    expect: SampleExpect(amount: 3200, direction: 'debit', reference: '712845930000', accountTail: '847'),
  ),
  // Source: PW PNBBankParserTest.kt
  PaymentSample(
    id: 'pnb_atm_withdrawal',
    app: _gMessages,
    title: 'BP-PNBSMS',
    text: 'A/c XX7582 debited with Rs.5000.00,21-11-2025 13:23:22 thru card XX9239  . Out of 5 free txn on PNB ATM, you utilized 1 txn. Chrgs applicable as per policy. Bal 27000.00 CR. If not done, fwd SMS to 9264192641 to block card/call 18001800/18002021-PNB',
    verified: true,
    expect: SampleExpect(amount: 5000.00, direction: 'debit', accountTail: '7582'),
  ),

  // ───────────────────────────── Bank of Baroda ─────────────────────────────
  // Source: PW TestBankOfBarodaParser.kt
  PaymentSample(
    id: 'bob_debit',
    app: _gMessages,
    title: 'VM-BOBSMS',
    text: 'Rs.80.00 Dr. from A/c XX123456 on 12-11-2024. AvlBal:Rs1234.56. Ref:522110123456 -Bank of Baroda',
    verified: true,
    expect: SampleExpect(amount: 80.00, direction: 'debit', reference: '522110123456', accountTail: '3456'),
  ),
  // Source: PW TestBankOfBarodaParser.kt
  PaymentSample(
    id: 'bob_imps_credit',
    app: _gMessages,
    title: 'VM-BOBSMS',
    text: 'Rs.2500.00 credited to A/c XX456789 via IMPS/518233445566 by VIKAS YADAV. AvlBal:Rs25000.00 -Bank of Baroda',
    verified: true,
    expect: SampleExpect(amount: 2500.00, direction: 'credit', payee: 'VIKAS', reference: '518233445566', accountTail: '6789'),
  ),
  // Source: PW TestBankOfBarodaParser.kt
  PaymentSample(
    id: 'bob_transfer_debit',
    app: _gMessages,
    title: 'VM-BOBTXN',
    text: 'Rs.1500.00 transferred from A/c ...1234 to:Pooja Iyer. Total Bal:Rs.15000.00CR. Avlbl Amt:Rs.15000.00(10-11-2025 10:30:00) - Bank of Baroda',
    verified: true,
    expect: SampleExpect(amount: 1500.00, direction: 'debit', payee: 'Pooja', accountTail: '1234'),
  ),
  // Source: PW TestBankOfBarodaParser.kt
  PaymentSample(
    id: 'bob_card_spend',
    app: _gMessages,
    title: 'VM-BOBCRD',
    text: 'ALERT: INR 250.50 spent on your BOBCARD ending 5678 at SWIGGY on 26-11-2024. -Bank of Baroda',
    verified: true,
    expect: SampleExpect(amount: 250.50, direction: 'debit', payee: 'SWIGGY', accountTail: '5678'),
  ),

  // ───────────────────────────── Canara ─────────────────────────────
  // Source: PW com/pennywiseai/parser/core/bank/CanaraBankParserTest.kt
  PaymentSample(
    id: 'canara_upi_debit_ramesh',
    app: _gMessages,
    title: 'AD-CANBNK-S',
    text: 'Dear Customer, Acct XXX123 Dr. INR 100.00 on 02/10/26 to RAMESH KUMAR; UPI: 627712345999; Bal INR 12,345.67.Not you? SMS BLOCKUPI to 9901771222-CanaraBank',
    verified: true,
    expect: SampleExpect(amount: 100.00, direction: 'debit', payee: 'RAMESH', reference: '627712345999', accountTail: '123'),
  ),
  // Source: PW com/pennywiseai/parser/core/bank/CanaraBankParserTest.kt (₹ symbol variant)
  PaymentSample(
    id: 'canara_upi_debit_rupee_symbol',
    app: _gMessages,
    title: 'AD-CANBNK-S',
    text: 'Dear Customer, Acct XXX789 Dr. ₹41.00 on 08/07/26 to METRO TRANSIT; UPI: 456789012345; Bal INR 8,765.43.Not you? SMS BLOCKUPI to 9901771222-CanaraBank',
    verified: true,
    expect: SampleExpect(amount: 41.00, direction: 'debit', payee: 'METRO', reference: '456789012345', accountTail: '789'),
  ),
  // Source: PW com/pennywiseai/parser/core/bank/CanaraBankParserTest.kt (RTGS, Indian lakh grouping)
  PaymentSample(
    id: 'canara_rtgs_credit',
    app: _gMessages,
    title: 'VM-CANBNK',
    text: 'An amount of INR 13,30,614.75 has been credited to XXXX6785 on 02/12/2025 towards RTGS by Sender AXIS MUTUAL FUND REDEMPTION PO, IFSC UTIB0000004, Sender A/c XXXX9108, AXIS BANK, MUMBAI BRANCH, UTR UTIBR72025120200011461, Total Avail. Bal INR 2679815.88- Canara Bank',
    verified: true,
    expect: SampleExpect(amount: 1330614.75, direction: 'credit', payee: 'AXIS MUTUAL FUND', accountTail: '6785'),
  ),

  // ───────────────────────────── Union Bank ─────────────────────────────
  // Source: PWM UnionBankParser.kt (doc comment)
  PaymentSample(
    id: 'union_debit_mobile_banking',
    app: _gMessages,
    title: 'AX-UNIONB',
    text: 'A/c *4410 Debited for Rs:100.00 on 11-08-2026 18:28:02 by Mob Bk ref no 622312345678 Avl Bal Rs:12345.67',
    verified: true,
    expect: SampleExpect(amount: 100.00, direction: 'debit', reference: '622312345678', accountTail: '4410'),
  ),
  PaymentSample(
    id: 'union_upi_credit',
    app: _gMessages,
    title: 'AX-UNIONB',
    text: 'A/c *4410 Credited for Rs:2,000.00 on 02-10-2026 10:15:44 by UPI ref no 627512398765 Avl Bal Rs:14,345.67',
    verified: false,
    expect: SampleExpect(amount: 2000.00, direction: 'credit', reference: '627512398765', accountTail: '4410'),
  ),

  // ───────────────────────────── IDFC First ─────────────────────────────
  // Source: PW TestIDFCFirstBankParser.kt
  PaymentSample(
    id: 'idfc_upi_debit_redbus',
    app: _gMessages,
    title: 'JM-IDFCFB-S',
    text: 'Your A/c XX4614 debited by Rs. 1,172.06 on 15/01/26; REDBUS credited. RRN 606412345678. Available balance Rs. 9,134.15. Team IDFC FIRST Bank',
    verified: true,
    expect: SampleExpect(amount: 1172.06, direction: 'debit', payee: 'REDBUS', reference: '606412345678', accountTail: '4614'),
  ),
  // Source: PW TestIDFCFirstBankParser.kt
  PaymentSample(
    id: 'idfc_credit',
    app: _gMessages,
    title: 'JM-IDFCFB-S',
    text: 'Your A/C XXXXXXX4614 is credited by INR 500.00 on 06/08/26 17:36. New Bal :INR 10000.00',
    verified: true,
    expect: SampleExpect(amount: 500.00, direction: 'credit', accountTail: '4614'),
  ),

  // ───────────────────────────── Yes Bank ─────────────────────────────
  // Source: PW TestYesBankParser.kt (UPI on credit card, payee after "@UPI_")
  PaymentSample(
    id: 'yes_cc_upi_spend',
    app: _gMessages,
    title: 'VM-YESBNK-S',
    text: 'INR 250.00 spent on YES BANK Card X3349 @UPI_SURAKSHAA HEALTHCA 23-08-2025 10:02:59 am. Avl Lmt INR 212,036.60. SMS BLKCC 3349 to 9840909000 if not you',
    verified: true,
    expect: SampleExpect(amount: 250.00, direction: 'debit', payee: 'SURAKSHAA', accountTail: '3349'),
  ),
  PaymentSample(
    id: 'yes_savings_upi_debit',
    app: _gMessages,
    title: 'VM-YESBNK-S',
    text: 'Your A/c XX7766 has been debited with INR 1,250.00 on 02-10-2026 towards UPI/627512340001/DMART READY. Avl Bal INR 20,110.45. Not you? Call 18001200',
    verified: false,
    expect: SampleExpect(amount: 1250.00, direction: 'debit', payee: 'DMART', reference: '627512340001', accountTail: '7766'),
  ),

  // ───────────────────────────── IndusInd ─────────────────────────────
  // Source: PW TestIndusIndBankParser.kt
  PaymentSample(
    id: 'indusind_upi_credit',
    app: _gMessages,
    title: 'AD-INDUSB',
    text: 'A/C *XX1234 credited by Rs 25000.00 from karan.malhotra@ybl. RRN:510048500001. Avl Bal:105502.12. Not you? Call 18602677777 - IndusInd bank.',
    verified: true,
    expect: SampleExpect(amount: 25000.00, direction: 'credit', payee: 'karan', reference: '510048500001', accountTail: '1234'),
  ),
  // Source: PW TestIndusIndBankParser.kt
  PaymentSample(
    id: 'indusind_upi_debit',
    app: _gMessages,
    title: 'AD-INDUSB',
    text: 'A/c *XX1234 debited by Rs 1234.00 towards meera.k@icici. RRN: 510048500002. Not You? call 18602677777- IndusInd Bank.',
    verified: true,
    expect: SampleExpect(amount: 1234.00, direction: 'debit', payee: 'meera', reference: '510048500002', accountTail: '1234'),
  ),
  // Source: PW TestIndusIndBankParser.kt (NACH/ACH mandate debit, executed)
  PaymentSample(
    id: 'indusind_ach_debit',
    app: _gMessages,
    title: 'AD-INDUSB',
    text: 'IndusInd A/C  Debited; INR 4,500.00 Ref-ACH DR INW PAY/0000WD2CEFDT2Z58B2202320321456/Grow.Bal INR 141,999.93.Dispute-Call 18602677777-IndusInd Bank.',
    verified: true,
    expect: SampleExpect(amount: 4500.00, direction: 'debit', payee: 'Grow'),
  ),
  // Source: PW TestIndusIndBankParser.kt
  PaymentSample(
    id: 'indusind_imps_debit',
    app: _gMessages,
    title: 'AD-INDUSB',
    text: 'Your IndusInd Account 20XXXXX1234 has been debited for INR 6440 towards IMPS/627512340099. Call 18602677777 to report issue-IndusInd Bank.',
    verified: true,
    expect: SampleExpect(amount: 6440, direction: 'debit', reference: '627512340099', accountTail: '1234'),
  ),
  // Source: PW TestIndusIndBankParser.kt (card refund => credit)
  PaymentSample(
    id: 'indusind_cc_refund',
    app: _gMessages,
    title: 'AD-INDUSB',
    text: 'Dear Customer, refund of INR 499 from Zomato has been credited to your IndusInd Bank Credit Card XXXX5678 on 11-Jun-26 and the refund amount has been adjusted against the outstanding on your card account - IndusInd Bank',
    verified: true,
    expect: SampleExpect(amount: 499, direction: 'credit', payee: 'Zomato', accountTail: '5678'),
  ),

  // ───────────────────────────── AU Small Finance ─────────────────────────────
  // Source: PW TestAUBankParser.kt
  PaymentSample(
    id: 'au_upi_debit',
    app: _gMessages,
    title: 'VM-AUBANK-S',
    text: 'Debited INR 165.00 from A/c X7013 on 01-MAR-2026\nUPI/DR/651122780001/UK FOOD/UTIB/9180201\nBal INR 9,000.00\nNot you? Call 180012001200 & dial 0\n-AU Bank',
    verified: true,
    expect: SampleExpect(amount: 165.00, direction: 'debit', payee: 'UK FOOD', reference: '651122780001', accountTail: '7013'),
  ),
  // Source: PW TestAUBankParser.kt (credit SMS that says "to A/c")
  PaymentSample(
    id: 'au_upi_credit',
    app: _gMessages,
    title: 'VM-AUBANK-S',
    text: 'Cr INR 5,000.00 to A/c X4541 12-MAY-2026\nUPI/CR/424941000001/DEEPA RAO/Y\nBal INR 23,838.10\n-AU Bank',
    verified: true,
    expect: SampleExpect(amount: 5000.00, direction: 'credit', payee: 'DEEPA', reference: '424941000001', accountTail: '4541'),
  ),
  // Source: PW TestAUBankParser.kt
  PaymentSample(
    id: 'au_cc_spend',
    app: _gMessages,
    title: 'VM-AUBANK-S',
    text: 'INR 259.90 spent at TELEGRAM PREMIUM on AU Bank Credit Card x1234 21-03-2026 05:49:40 PM. Not you? Call 180012001500 or SMS PBLOCK 1234 to 5676767',
    verified: true,
    expect: SampleExpect(amount: 259.90, direction: 'debit', payee: 'TELEGRAM', accountTail: '1234'),
  ),

  // ───────────────────────────── Federal ─────────────────────────────
  // Source: PW TestFederalBankParser.kt
  PaymentSample(
    id: 'federal_upi_debit',
    app: _gMessages,
    title: 'AD-FEDBNK',
    text: 'Rs 450.75 debited via UPI on 16-08-2026 14:22:10 to VPA swiggy.food@paytm.Ref No 876543210987.Small txns?Use UPI Lite!-Federal Bank',
    verified: true,
    expect: SampleExpect(amount: 450.75, direction: 'debit', payee: 'swiggy', reference: '876543210987'),
  ),
  // Source: PW TestFederalBankParser.kt
  PaymentSample(
    id: 'federal_imps_credit',
    app: _gMessages,
    title: 'AD-FEDBNK',
    text: 'Rs 15000.00 credited to your A/c XX7890 via IMPS on 19AUG2026 16:20:15 IMPS Ref no 543210987654 Bal:Rs 42500.80 -Federal Bank',
    verified: true,
    expect: SampleExpect(amount: 15000.00, direction: 'credit', reference: '543210987654', accountTail: '7890'),
  ),
  // Source: PW TestFederalBankParser.kt
  PaymentSample(
    id: 'federal_neft_debit',
    app: _gMessages,
    title: 'AD-FEDBNK',
    text: 'Debited Rs 6000 from a/c XX3343 on 24JUN2026 21:35 via NEFT to Jerry.Ref FDRLM4175007432.Bal Rs 76.82.Not you?Call 18004251199 -Federal Bank',
    verified: true,
    expect: SampleExpect(amount: 6000, direction: 'debit', payee: 'Jerry', accountTail: '3343'),
  ),
  // Source: PW TestFederalBankParser.kt (e-mandate executed)
  PaymentSample(
    id: 'federal_emandate_spotify',
    app: _gMessages,
    title: 'AD-FEDBNK',
    text: 'Hi, payment of INR 119.00 for Spotify via e-mandate ID: SP456DEF123 on Federal Bank Debit Card 7890 is processed successfully. To manage, visit: https://www.sihub.in/managesi/federal T&CA - Federal Bank',
    verified: true,
    expect: SampleExpect(amount: 119.00, direction: 'debit', payee: 'Spotify', accountTail: '7890'),
  ),
  // Source: PW TestFederalBankParser.kt
  PaymentSample(
    id: 'federal_received_credit',
    app: _gMessages,
    title: 'AD-FEDBNK',
    text: "Arjun, you've received INR 10,509.09 in your Account XXXXXXXX1896. Woohoo! It was sent by LAKSHMI TRADERS on March 19, 2026. -Federal Bank",
    verified: true,
    expect: SampleExpect(amount: 10509.09, direction: 'credit', payee: 'LAKSHMI', accountTail: '1896'),
  ),
  // Source: PW TestFederalBankParser.kt
  PaymentSample(
    id: 'federal_atm_withdrawal',
    app: _gMessages,
    title: 'AD-FEDBNK',
    text: 'Rs 1500 withdrawn@ YBL CHAN on 21JAN26 17:59 Bal Rs 7517.94 Ref 602117126490. Not you? Call 18004251199/ SMS NO 3683 to 9895088888 -Federal Bank',
    verified: true,
    expect: SampleExpect(amount: 1500, direction: 'debit', reference: '602117126490'),
  ),
  // Source: PW TestFederalBankParser.kt (generic "spent on card ending ... at MERCHANT")
  PaymentSample(
    id: 'federal_cc_spend',
    app: _gMessages,
    title: 'AD-FEDBNK',
    text: 'INR 1200.00 spent on your credit card ending with 5678 at AMAZON on 09-05-2026 15:30:15. Available limit Rs.38000.00 -Federal Bank',
    verified: true,
    expect: SampleExpect(amount: 1200.00, direction: 'debit', payee: 'AMAZON', accountTail: '5678'),
  ),

  // ───────────────────────────── IDBI ─────────────────────────────
  // Template prefix from PWM IDBIBankParser.kt ("IDBI Bank Acct XX1234 debited for Rs 1040.00"); rest reconstructed
  PaymentSample(
    id: 'idbi_upi_debit',
    app: _gMessages,
    title: 'VM-IDBIBK',
    text: 'IDBI Bank Acct XX7711 debited for Rs 1040.00 on 01-Oct-26; RAJU STORES credited. UPI:627512345555. Call 18002094324 for dispute.',
    verified: false,
    expect: SampleExpect(amount: 1040.00, direction: 'debit', payee: 'RAJU', reference: '627512345555', accountTail: '7711'),
  ),
  PaymentSample(
    id: 'idbi_debit_inr_suffix',
    app: _gMessages,
    title: 'VM-IDBIBK',
    text: 'Your IDBI Bank A/c XX7711 is debited for 250.00 INR on 02-10-2026 towards POS ECOM PURCHASE at FLIPKART. Avl Bal 4,321.00 INR.',
    verified: false,
    expect: SampleExpect(amount: 250.00, direction: 'debit', payee: 'FLIPKART', accountTail: '7711'),
  ),

  // ───────────────────────────── Amex ─────────────────────────────
  // Source: https://technofino.in/community/goto/post?id=232882 (Amex supplementary card alert)
  // Amex prints 5 digits ("**51004"); the expected tail is the last 4.
  PaymentSample(
    id: 'amex_spend',
    app: _gMessages,
    title: 'AD-AMEXIN',
    text: "Alert: You've spent INR 1,187.00 on your AMEX card **51004 at CROMA RETAIL on 2 October, 2026 at 05:23 PM IST. Call 18004190691 if this was not made by you.",
    verified: true,
    expect: SampleExpect(amount: 1187.00, direction: 'debit', payee: 'CROMA', accountTail: '1004'),
  ),

  // ───────────────────────────── UPI apps ─────────────────────────────
  PaymentSample(
    id: 'gpay_paid_swiggy',
    app: _gpay,
    title: '₹450 paid to Swiggy Limited',
    text: 'HDFC Bank ••5521 · UPI transaction ID: 627512345601',
    verified: false,
    expect: SampleExpect(amount: 450, direction: 'debit', payee: 'Swiggy', reference: '627512345601', accountTail: '5521'),
  ),
  PaymentSample(
    id: 'gpay_received_priya',
    app: _gpay,
    title: 'Priya Nair paid you ₹2,500',
    text: 'Received in HDFC Bank ••5521',
    verified: false,
    expect: SampleExpect(amount: 2500, direction: 'credit', payee: 'Priya', accountTail: '5521'),
  ),
  PaymentSample(
    id: 'phonepe_paid_anita',
    app: _phonepe,
    title: 'Payment Successful',
    text: '₹1,200 paid to Anita Sharma from SBI ••4821. UPI Ref: 627712340011',
    verified: false,
    expect: SampleExpect(amount: 1200, direction: 'debit', payee: 'Anita', reference: '627712340011', accountTail: '4821'),
  ),
  PaymentSample(
    id: 'phonepe_received_vikram',
    app: _phonepe,
    title: 'Received ₹350',
    text: 'Vikram Singh sent you ₹350 in State Bank of India ••4821',
    verified: false,
    expect: SampleExpect(amount: 350, direction: 'credit', payee: 'Vikram', accountTail: '4821'),
  ),
  PaymentSample(
    id: 'paytm_paid_tea_stall',
    app: _paytm,
    title: 'Paid Successfully',
    text: '₹60 paid to Sharma Tea Stall from Kotak Bank a/c XX5678. UPI Ref No: 528712349876',
    verified: false,
    expect: SampleExpect(amount: 60, direction: 'debit', payee: 'Sharma Tea', reference: '528712349876', accountTail: '5678'),
  ),
  PaymentSample(
    id: 'paytm_received',
    app: _paytm,
    title: 'Received ₹1,000.00',
    text: 'from Neha Gupta in Kotak Bank a/c XX5678. UPI Ref No: 528799990000',
    verified: false,
    expect: SampleExpect(amount: 1000.00, direction: 'credit', payee: 'Neha', reference: '528799990000', accountTail: '5678'),
  ),
  PaymentSample(
    id: 'paytm_wallet_cashback_credited',
    app: _paytm,
    title: 'Cashback Received',
    text: 'Yay! Cashback of ₹25 has been credited to your Paytm Wallet for your recharge.',
    verified: false,
    expect: SampleExpect(amount: 25, direction: 'credit'),
  ),
  PaymentSample(
    id: 'cred_upi_paid',
    app: _cred,
    title: 'payment successful',
    text: 'you paid ₹120.00 to Chai Point via CRED UPI from ICICI Bank ••308. UPI ref: 627912340005',
    verified: false,
    expect: SampleExpect(amount: 120.00, direction: 'debit', payee: 'Chai Point', reference: '627912340005', accountTail: '308'),
  ),
  PaymentSample(
    id: 'amazon_pay_recharge',
    app: _amazon,
    title: 'Payment successful',
    text: 'Your payment of ₹349.00 to Airtel Prepaid for 98xxxxxx21 was successful. Paid using Amazon Pay UPI.',
    verified: false,
    expect: SampleExpect(amount: 349.00, direction: 'debit', payee: 'Airtel'),
  ),
  PaymentSample(
    id: 'amazon_pay_refund',
    app: _amazon,
    title: 'Refund processed',
    text: 'Refund of ₹799.00 for your order of boAt Airdopes has been credited to your Amazon Pay balance.',
    verified: false,
    expect: SampleExpect(amount: 799.00, direction: 'credit'),
  ),
  PaymentSample(
    id: 'bhim_sent_ramesh',
    app: _bhim,
    title: 'BHIM',
    text: 'Transaction successful. ₹100.00 sent to RAMESH KUMAR from Canara Bank XXX123. UPI Ref No: 627712345999',
    verified: false,
    expect: SampleExpect(amount: 100.00, direction: 'debit', payee: 'RAMESH', reference: '627712345999', accountTail: '123'),
  ),
  PaymentSample(
    id: 'bhim_received',
    app: _bhim,
    title: 'BHIM',
    text: 'You have received ₹750.00 from sunita.devi@upi. UPI Ref No: 627712340777',
    verified: false,
    expect: SampleExpect(amount: 750.00, direction: 'credit', payee: 'sunita', reference: '627712340777'),
  ),
  PaymentSample(
    id: 'whatsapp_pay_sent',
    app: _whatsapp,
    title: 'Rohit Mehta',
    text: '💳 You sent ₹200 to Rohit Mehta. UPI Ref No: 627812340200',
    verified: false,
    expect: SampleExpect(amount: 200, direction: 'debit', payee: 'Rohit', reference: '627812340200'),
  ),
  PaymentSample(
    id: 'whatsapp_pay_received',
    app: _whatsapp,
    title: 'Ankit Jain',
    text: '💳 Payment received: ₹500 from Ankit Jain',
    verified: false,
    // Deliberately ignored: from WhatsApp this is indistinguishable from a
    // chat message saying the same. The bank SMS for it is still captured.
    expect: null,
  ),

  // ═════════════════════════ MUST-IGNORE (expect: null) ═════════════════════════
  // Source: PW TestHDFCBankParser.kt (bill due)
  PaymentSample(
    id: 'ignore_hdfc_bill_due',
    app: _gMessages,
    title: 'CP-HDFCBK-S',
    text: 'New Bill Alert:\nYour XUBA00000TST1A Bill 1234567890 of Rs.1500.00 is due on 15-Jan-2026. To pay, login to HDFC Bank Net/Mobile Banking>BillPay\nT&C. Ignore if paid',
    verified: true,
  ),
  // Source: PW TestHDFCBankParser.kt (NACH mandate received, not executed)
  PaymentSample(
    id: 'ignore_hdfc_nach_mandate_received',
    app: _gMessages,
    title: 'VM-HDFCBK',
    text: 'Auto Pay HDFC Bank NACH Mandate : Rs. 100000.00 UMRN:HDFC7031703260000001 To:NationalSecuritiesClearin Freq ADHO received today for processing.',
    verified: true,
  ),
  // Source: PW TestHDFCMandateParsing.kt (future-dated e-mandate notice)
  PaymentSample(
    id: 'ignore_hdfc_emandate_future',
    app: _gMessages,
    title: 'VM-HDFCBK-S',
    text: 'E-Mandate!\nRs.3821.00 will be deducted on 02/03/26, 00:00:00\nFor Rentomojo mandate\nUMN 6cc417efb7894c0593866a09c8710000@ybl\nMaintain Balance\n-HDFC Bank',
    verified: true,
  ),
  // Source: PW TestICICIBankParser.kt
  PaymentSample(
    id: 'ignore_icici_autopay_future',
    app: _gMessages,
    title: 'AX-ICICIT-S',
    text: 'Your account will be debited with Rs 649.00 on 03-Oct-26 towards Netflix Entertainment Ser for AutoPay MERCHANTMANDATE, RRN 627712345670-ICICI Bank.',
    verified: true,
  ),
  PaymentSample(
    id: 'ignore_icici_emi_future',
    app: _gMessages,
    title: 'AX-ICICIB',
    text: 'Rs. 8,927.00 will be debited from your account XX308 on 05-Oct-26 for EMI payment of Loan A/c XX4433. Please maintain sufficient balance.',
    verified: false,
  ),
  // Source: PW SmsReportRegressionTest.kt (Axis future auto-debit notice)
  PaymentSample(
    id: 'ignore_axis_autodebit_future',
    app: _gMessages,
    title: 'AX-AXISBK-S',
    text: 'INR 587.64 for Airtel Payments Bank Limited will be auto-debited via Axis Bank Card no. XX0818 by 27-07-26. Please ensure sufficient limit/balance on your card/account to process the auto-debit. To deactivate the AutoPay facility for ID 7Hk2Lm9P, visit https://www.sihub.in/managesi/axisbank. TnC apply.',
    verified: true,
  ),
  // Source: PW PNBBankParserTest.kt (mandate created, not executed)
  PaymentSample(
    id: 'ignore_pnb_upi_mandate_created',
    app: _gMessages,
    title: 'BP-PNBSMS',
    text: 'Your UPI-Mandate is successfully created towards Google for Rs.1500.00 from A/c No.XXXXXX4356. UMN:1d478c77808c410281f435aaa5bbbbb6@ybl-PNB',
    verified: true,
  ),
  PaymentSample(
    id: 'ignore_sbi_autopay_registered',
    app: _gMessages,
    title: 'VM-SBIUPI-S',
    text: 'Dear SBI UPI User, your mandate for Rs.199.00 towards Spotify India is successfully registered. Frequency: Monthly. UMN: a1b2c3d4e5f6@sbi. -SBI',
    verified: false,
  ),
  // Source: PW com/pennywiseai/parser/core/bank/CanaraBankParserTest.kt
  PaymentSample(
    id: 'ignore_canara_otp_amount',
    app: _gMessages,
    title: 'AD-CANBNK-S',
    text: '482913 is your OTP for a Dr. INR 500.00 transaction on your Canara Bank card. Do not share it with anyone.-Canara Bank',
    verified: true,
  ),
  PaymentSample(
    id: 'ignore_sbi_otp_purchase',
    app: _gMessages,
    title: 'AD-SBIOTP',
    text: 'OTP for online purchase of Rs. 2499.00 at AMAZON thru State Bank Debit Card ending 7702 is 582014. Do not share this with anyone.',
    verified: false,
  ),
  PaymentSample(
    id: 'ignore_hdfc_otp_card',
    app: _gMessages,
    title: 'AX-HDFCBK-S',
    text: 'OTP is 731904 for txn of INR 1,299.00 at AMAZON PAY INDIA on HDFC Bank card ending 7788. Valid till 19:25. Do not share OTP for security reasons',
    verified: false,
  ),
  // Source: PW SmsReportRegressionTest.kt (Amex SafeKey OTP)
  PaymentSample(
    id: 'ignore_amex_safekey_otp',
    app: _gMessages,
    title: 'AD-AMEXIN',
    text: 'Your Amex SafeKey One-Time Password for INR 213.50, at X CORP- PAID FEATURES is 000000. Valid for 10 mins for Card ending  51004. Do not disclose it to anyone.',
    verified: true,
  ),
  // Source: PW com/pennywiseai/parser/core/bank/CanaraBankParserTest.kt
  PaymentSample(
    id: 'ignore_canara_atm_free_txn_info',
    app: _gMessages,
    title: 'AD-CANBNK-S',
    text: 'Card ending 4321: Dear Customer, you have done 02 out of 06 free transactions at Canara ATMs in this month. Charges applicable beyond free transactions.-Canara Bank',
    verified: true,
  ),
  // Source: PW TestFederalBankParser.kt
  PaymentSample(
    id: 'ignore_federal_emandate_declined',
    app: _gMessages,
    title: 'AD-FEDBNK',
    text: 'Hi, payment of INR 199.00 via e-mandate declined for ID: NX789XYZABC on Federal Bank Debit Card 3456. To manage, visit: https://www.sihub.in/managesi/federal T&CA - Federal Bank',
    verified: true,
  ),
  // Source: PW TestFederalBankParser.kt
  PaymentSample(
    id: 'ignore_federal_failed_insufficient',
    app: _gMessages,
    title: 'AD-FEDBNK',
    text: 'Hi, txn of Rs. 1500.00 using card XX**3456 failed due to insufficient funds. Current Bal: Rs.250.75. Call 18004251199 if txn not initiated by you -Federal Bank',
    verified: true,
  ),
  PaymentSample(
    id: 'ignore_sbi_upi_failed',
    app: _gMessages,
    title: 'VM-SBIUPI-S',
    text: 'Dear UPI user, your transaction of Rs.500.00 to RAMESH KUMAR on 02Oct26 has failed. Amount, if debited, will be reversed within 2 working days. Ref no 627712341111 -SBI',
    verified: false,
  ),
  PaymentSample(
    id: 'ignore_gpay_payment_failed',
    app: _gpay,
    title: 'Payment failed',
    text: '₹250 to Swiggy Limited could not be completed. Any money debited will be refunded within 3-5 working days.',
    verified: false,
  ),
  PaymentSample(
    id: 'ignore_phonepe_declined',
    app: _phonepe,
    title: 'Payment Declined',
    text: 'Your payment of ₹1,500 to Big Bazaar was declined by your bank. Please try again.',
    verified: false,
  ),
  // Source: PW TestFederalBankParser.kt
  PaymentSample(
    id: 'ignore_federal_vkyc',
    app: _gMessages,
    title: 'AD-FEDBNK',
    text: 'Hi, your Federal Bank Savings Account is currently debit frozen due to incomplete Video KYC. Please complete the VKYC by 30/09/2026 to avoid account closure.',
    verified: true,
  ),
  PaymentSample(
    id: 'ignore_sbi_kyc_update',
    app: _gMessages,
    title: 'VM-SBIBNK',
    text: 'Dear Customer, KYC updation for your A/c XX4821 is due. Please visit your home branch or update via YONO to avoid restrictions on transactions above Rs.10,000. -SBI',
    verified: false,
  ),
  // Source: PW TestIndusIndBankParser.kt (balance-only)
  PaymentSample(
    id: 'ignore_indusind_balance_only',
    app: _gMessages,
    title: 'AD-INDUSB',
    text: 'Your A/C 2134***12345 has Avl BAL of INR 1,234.56 as on 05/10/26 04:10 AM. Download IndusMobile from PlayStore - IndusInd Bank',
    verified: true,
  ),
  PaymentSample(
    id: 'ignore_kotak_balance_enquiry',
    app: _gMessages,
    title: 'AD-KOTAKB-S',
    text: 'Avl Bal in your Kotak Bank A/c X5678 as on 02-10-26 is Rs.12,450.00. Download Kotak811 app for more.',
    verified: false,
  ),
  // Source: PW TestYesBankParser.kt
  PaymentSample(
    id: 'ignore_yes_payment_request',
    app: _gMessages,
    title: 'VM-YESBNK-S',
    text: 'Payment request of INR 500.00 from merchant@upi. Ignore if already paid.',
    verified: false,
  ),
  // Source: PW com/pennywiseai/parser/core/bank/SliceParserTest.kt (collect request)
  PaymentSample(
    id: 'ignore_slice_collect_request',
    app: _gMessages,
    title: 'JD-SLICEIT',
    text: 'You have received a collect request of Rs. 500 from someone@slc on slice. Approve or decline in the app. - slice',
    verified: true,
  ),
  PaymentSample(
    id: 'ignore_gpay_request',
    app: _gpay,
    title: 'Rohit Mehta requested ₹500',
    text: 'For: dinner split. Tap to pay or decline',
    verified: false,
  ),
  PaymentSample(
    id: 'ignore_phonepe_collect_request',
    app: _phonepe,
    title: 'Payment Request',
    text: 'Zomato has requested ₹349.00. Approve the request before it expires in 10 mins.',
    verified: false,
  ),
  PaymentSample(
    id: 'ignore_bhim_collect_request',
    app: _bhim,
    title: 'BHIM',
    text: 'You have a collect request of ₹1,000.00 from vendor.store@upi. Approve or decline.',
    verified: false,
  ),
  // Source: PW TestYesBankParser.kt
  PaymentSample(
    id: 'ignore_yes_cc_due',
    app: _gMessages,
    title: 'VM-YESBNK-S',
    text: 'Your Yes Bank Credit Card payment of INR 10,000 is due by 25-10-2026',
    verified: false,
  ),
  PaymentSample(
    id: 'ignore_icici_cc_min_due',
    app: _gMessages,
    title: 'AD-ICICIT-S',
    text: 'Payment of Rs 4,520.00 is due on your ICICI Bank Credit Card XX5678 by 12-Oct-26. Minimum amount due is Rs 230.00. Pay now to avoid late fee.',
    verified: false,
  ),
  PaymentSample(
    id: 'ignore_sbi_card_statement',
    app: _gMessages,
    title: 'AX-SBICRD-S',
    text: 'E-statement of SBI Credit Card ending 3391 dated 02/10/26 has been mailed. Total Amt Due Rs 12,450; Min Amt Due Rs 625; payable by 22/10/26.',
    verified: false,
  ),
  PaymentSample(
    id: 'ignore_hdfc_email_statement',
    app: _gmail,
    title: 'HDFC Bank',
    text: 'Your HDFC Bank Credit Card Statement for September 2026\nDear Customer, your statement is ready. Total Amount Due: Rs. 18,240.00. Minimum Amount Due: Rs. 912.00. Payment Due Date: 20-10-2026.',
    verified: false,
  ),
  // Source: PW TestIDFCFirstBankParser.kt
  PaymentSample(
    id: 'ignore_idfc_promo_cashback',
    app: _gMessages,
    title: 'VM-IDFCFB-P',
    text: 'IDFC First Bank: Get 10% cashback offer on all online purchases!',
    verified: false,
  ),
  PaymentSample(
    id: 'ignore_paytm_cashback_upto',
    app: _paytm,
    title: 'Recharge & win!',
    text: 'Get cashback up to ₹100 on your next mobile recharge of ₹299 or more. Use code RECH100.',
    verified: false,
  ),
  PaymentSample(
    id: 'ignore_phonepe_offer',
    app: _phonepe,
    title: 'Flat ₹50 off on electricity bill',
    text: 'Pay your electricity bill of ₹500 or more on PhonePe and get flat ₹50 cashback. T&C apply.',
    verified: false,
  ),
  PaymentSample(
    id: 'ignore_loan_offer',
    app: _gMessages,
    title: 'VM-BAJAJF-P',
    text: 'Pre-approved Personal Loan of Rs 5,00,000 ready for you! Get money credited in your account in 30 mins. Apply now: bjfl.in/abc123',
    verified: false,
  ),
  PaymentSample(
    id: 'ignore_cc_limit_increase_offer',
    app: _gMessages,
    title: 'AD-HDFCBK-P',
    text: 'Congratulations! Your HDFC Bank Credit Card x7788 is eligible for a limit increase to Rs.3,00,000. Reply YES to 5676712.',
    verified: false,
  ),
  PaymentSample(
    id: 'ignore_lic_premium_reminder',
    app: _gMessages,
    title: 'VM-LICIND',
    text: 'Premium of Rs.12,345.00 for policy no 912345678 is due on 15/10/2026. Pay via LIC Pay Direct or UPI to keep your policy in force. -LIC',
    verified: false,
  ),
  PaymentSample(
    id: 'ignore_jio_recharge_reminder',
    app: _gMessages,
    title: 'JM-JIOPAY',
    text: 'Your Jio plan expires on 05-Oct-26. Recharge now with Rs 299 to continue enjoying unlimited benefits.',
    verified: false,
  ),
  PaymentSample(
    id: 'ignore_amazon_order_email',
    app: _gmail,
    title: 'Amazon.in',
    text: 'Your Amazon.in order #403-1234567-1234567 of 1 item\nOrder Total: ₹1,299.00. Arriving Saturday.',
    verified: false,
  ),
  PaymentSample(
    id: 'ignore_whatsapp_chat_send_me',
    app: _whatsapp,
    title: 'Ankit Jain',
    text: 'bhai send me 500 rs for the cab, will return tomorrow',
    verified: false,
  ),
  PaymentSample(
    id: 'ignore_whatsapp_chat_split',
    app: _whatsapp,
    title: 'Goa Trip 🏖️',
    text: 'Rohit: Paid ₹2,000 for dinner, your share is ₹500. Debited from my card already',
    verified: false,
  ),
];

/// Groups of sample ids that are the SAME real payment arriving through different channels
/// (e.g. bank SMS + UPI app + email). The app must merge each group into one transaction.
const samePaymentGroups = <List<String>>[
  // ₹450 to Swiggy, ref 627512345601: HDFC SMS + Google Pay + HDFC email
  ['hdfc_upi_debit_swiggy', 'gpay_paid_swiggy', 'hdfc_email_upi_debit_swiggy'],
  // ₹1,200 to Anita, ref 627712340011: PhonePe + SBI SMS
  ['phonepe_paid_anita', 'sbi_upi_debit_anita'],
  // ₹350 from Vikram into SBI: PhonePe received + SBI credit SMS (no ref in PhonePe)
  ['phonepe_received_vikram', 'sbi_upi_credit_1'],
  // ₹2,500 from Priya into HDFC: HDFC credit SMS + Google Pay received
  ['hdfc_upi_credit_priya', 'gpay_received_priya'],
  // ₹500 Swiggy on ICICI card XX5678: card SMS + email
  ['icici_cc_spend_swiggy', 'icici_email_cc_spend_swiggy'],
  // ₹1,299 Amazon on HDFC card x7788: card SMS + email
  ['hdfc_cc_spend_amazon', 'hdfc_email_cc_spend_amazon'],
  // ₹60 tea stall, ref 528712349876: Kotak SMS + Paytm
  ['kotak_upi_debit_paytmqr', 'paytm_paid_tea_stall'],
  // ₹250 Blinkit, ref 627512346789: Axis SMS + Axis email
  ['axis_upi_debit_blinkit', 'axis_email_upi_debit_blinkit'],
  // ₹100 to Ramesh, ref 627712345999: BHIM + Canara SMS
  ['bhim_sent_ramesh', 'canara_upi_debit_ramesh'],
  // ₹60 from Karan, ref 628703011111: Kotak SMS + SBI SMS + Google Pay + Kotak 811 (no ref)
  ['kotak_sms_received_person', 'sbi_upi_credited_transfer_from', 'gpay_paid_you_via_other_app', 'kotak811_app_received_person'],
];
