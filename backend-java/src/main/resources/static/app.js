(function () {
'use strict';

/* ============================================================
   Tiny DOM diff/patch engine (keeps input focus across re-render)
   ============================================================ */
function morph(oldNode, newNode) {
  if (oldNode.nodeType !== newNode.nodeType || oldNode.nodeName !== newNode.nodeName) {
    oldNode.replaceWith(newNode);
    return newNode;
  }
  if (oldNode.nodeType === 3 || oldNode.nodeType === 8) {
    if (oldNode.nodeValue !== newNode.nodeValue) oldNode.nodeValue = newNode.nodeValue;
    return oldNode;
  }
  if (oldNode.nodeType === 1) {
    syncAttrs(oldNode, newNode);
    syncFormValue(oldNode, newNode);
    var oc = Array.prototype.slice.call(oldNode.childNodes);
    var nc = Array.prototype.slice.call(newNode.childNodes);
    var max = Math.max(oc.length, nc.length);
    for (var i = 0; i < max; i++) {
      if (i >= nc.length) { oc[i].remove(); continue; }
      if (i >= oc.length) { oldNode.appendChild(nc[i]); continue; }
      morph(oc[i], nc[i]);
    }
  }
  return oldNode;
}

function syncAttrs(oldEl, newEl) {
  var oldAttrs = oldEl.attributes, newAttrs = newEl.attributes, i, name;
  for (i = oldAttrs.length - 1; i >= 0; i--) {
    name = oldAttrs[i].name;
    if (!newEl.hasAttribute(name)) oldEl.removeAttribute(name);
  }
  for (i = 0; i < newAttrs.length; i++) {
    var a = newAttrs[i];
    if (oldEl.getAttribute(a.name) !== a.value) oldEl.setAttribute(a.name, a.value);
  }
}

function syncFormValue(oldEl, newEl) {
  var tag = oldEl.tagName;
  if (tag === 'INPUT') {
    if (oldEl.type === 'file') return;
    var desired = newEl.getAttribute('value');
    if (desired === null) desired = '';
    if (document.activeElement !== oldEl && oldEl.value !== desired) oldEl.value = desired;
  } else if (tag === 'TEXTAREA') {
    var desired2 = newEl.textContent || '';
    if (document.activeElement !== oldEl && oldEl.value !== desired2) oldEl.value = desired2;
  } else if (tag === 'SELECT') {
    var dv = newEl.getAttribute('data-value');
    if (dv !== null && oldEl.value !== dv) oldEl.value = dv;
  }
}

function buildDom(html) {
  var wrap = document.createElement('div');
  wrap.innerHTML = html;
  return wrap;
}

function esc(s) {
  if (s === null || s === undefined) return '';
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
function fmtYen(n) { return '¥' + Math.round(Number(n) || 0).toLocaleString('ja-JP'); }

/* ---- event registry: rebuilt fresh every render() call ---- */
var REG = { click: {}, change: {} };
var _uid = 0;
function onClick(fn) { var id = 'c' + (++_uid); REG.click[id] = fn; return id; }
function onChange(fn) { var id = 'h' + (++_uid); REG.change[id] = fn; return id; }

/* ============================================================
   Data model
   ============================================================ */
var LOAN_RATE = 0.025;
var LOAN_AVAIL = 3000000;
var REPAY_FEE = 550;
var TRANSFER_FEE = 110;
var RATE_BY_TYPE = { '普通': 0.20, '当座': 0.05, '積立': 0.30, '定期': 0.35 };

var STORES = [
  { code: '001', name: '東京営業部' }, { code: '100', name: '丸の内支店' }, { code: '200', name: '新宿支店' },
  { code: '305', name: '渋谷支店' }, { code: '040', name: '横浜支店' }, { code: '210', name: '大阪支店' },
  { code: '500', name: '名古屋支店' }, { code: '088', name: '札幌支店' }, { code: '060', name: '福岡支店' },
  { code: '700', name: '仙台支店' }
];
var BRANCHES2 = [
  { code: '001', name: '東京営業部' }, { code: '100', name: '丸の内支店' }, { code: '200', name: '新宿支店' },
  { code: '305', name: '渋谷支店' }, { code: '040', name: '横浜支店' }, { code: '210', name: '大阪支店' },
  { code: '500', name: '名古屋支店' }, { code: '088', name: '札幌支店' }, { code: '060', name: '福岡支店' },
  { code: '700', name: '仙台支店' }
];
var BANKS = ['KS銀行', 'みずほ銀行', '三菱UFJ銀行', '三井住友銀行', 'ゆうちょ銀行', 'りそな銀行', '楽天銀行', 'PayPay銀行', '住信SBIネット銀行', 'イオン銀行'];
var BANK_META = {
  'KS銀行': { c: '#ffcc00', t: '#1a3a6b', m: 'KS' }, 'みずほ銀行': { c: '#1a3f7a', t: '#fff', m: 'み' },
  '三菱UFJ銀行': { c: '#d0021b', t: '#fff', m: '三' }, '三井住友銀行': { c: '#00913a', t: '#fff', m: 'SM' },
  'ゆうちょ銀行': { c: '#e60012', t: '#fff', m: 'ゆ' }, 'りそな銀行': { c: '#f08300', t: '#fff', m: 'り' },
  '楽天銀行': { c: '#bf0000', t: '#fff', m: 'R' }, 'PayPay銀行': { c: '#ff0033', t: '#fff', m: 'PP' },
  '住信SBIネット銀行': { c: '#0068b7', t: '#fff', m: 'SBI' }, 'イオン銀行': { c: '#e5007f', t: '#fff', m: 'イ' }
};

function buildAccounts() {
  return [];  // 하드코딩 계좌 제거: 로그인 시 /api/login 응답으로 DB에서 채운다
}
function buildJournal() {
  return [];  // 가짜 거래이력 제거: 명세는 /api/meisai 로 DB에서 로드한다
}

function dict() {
  return {
    ja: {
      bankName: 'KS銀行', bankSub: 'インターネットバンキング', sama: '様', lastLogin: '最終ログイン', logout: 'ログアウト',
      balanceLabel: '残高', showBal: '残高を表示', hideBal: '残高を非表示', oshirase: 'お知らせ',
      ic_meisai: '明細照会', ic_soukin: '振込', ic_loan: 'ローン',
      meisaiTitle: '明細照会', th_date: 'お取引日', th_type: 'お取引内容', th_out: 'お支払金額', th_in: 'お預り金額',
      fr_title: '振込', trStep1: '振込先入力', trStep2: '内容確認', trStep3: '完了',
      l_branch: '支店名', l_accno: '口座番号', l_amount: '振込金額', l_amount2: '金額', yen: '円',
      confirmBtn: '確認する', backBtn: '戻る', executeBtn: '振込を実行する', confirmLead: '以下の内容でお手続きします。よろしければお進みください。',
      feeLabel: '振込手数料', totalLabel: 'お引落し合計', fromLabel: '振込元口座', toLabel: '振込先',
      tr_selBank: '振込先の金融機関を選択', tr_searchBank: '金融機関名で検索', tr_selBranch: '支店を選択', tr_searchBranch: '支店番号・支店名で検索（部分一致）', tr_noResult: '該当する候補がありません',
      receiptLabel: '受付番号', dtLabel: '取扱日時', afterBal: 'お取引後残高', doneMsgTr: '振込を受け付けました', toHome: 'ホームへ戻る',
      note_fee: '※ 振込手数料として110円を振込元口座より引き落とします。', note_atomic: '※ 振込金額と手数料は一括処理され、残高不足・口座凍結の場合はお取引を承れません。',
      err_amount: '正しい金額をご入力ください。', err_accno: '振込先口座番号をご入力ください。', err_insuf: '残高が不足しています。', err_frozen: 'お客様の口座は現在ご利用いただけません。', err_insuf_wdr: '残高が不足しているため出金できません。',
      loan_title: 'ローン', loan_step1: '借入内容入力', loan_step2: '内容確認', loan_step3: '申込完了',
      loan_totalBorrow: '借入総額', loan_remainPay: '残りの返済額', loan_availLeft: 'お借入可能額 残り', loan_amt: '借入金額', loan_term: '返済期間', loan_years: '年', loan_rate: '適用金利（年）',
      loan_monthly: '月々返済額', loan_total: '総返済額', loan_sim: '返済シミュレーション', loan_apply: 'この内容で申し込む', loan_none: '現在ご利用中のローンはありません。', loan_apply_btn: 'お申し込み', loan_bal: '借入残高', loan_done: 'お申し込みを受け付けました', loan_err_over: '借入可能額を超えています。',
      loan_method: '返済方式', loan_mA: '元利均等返済', loan_mB: '元金均等返済', loan_mC: '満期一括返済', loan_interest: '総利息',
      loan_capA: '毎月の返済額が一定', loan_capB: '毎月の元金が一定・返済額は逓減', loan_capC: '利息のみ返済・元本は満期に一括',
      loan_repay_btn: 'ご返済', repay_title: 'ローンご返済', repay_bal: '現在の借入残高', repay_all: '全額返済', repay_exec: '返済する', repay_done: 'ご返済を受け付けました', repay_err_over: '返済元金が借入残高を超えています。', repay_err_bal: '口座残高が不足しています。',
      repay_principal: '返済元金', repay_interest: '経過利息', repay_fee: '中途返済手数料', repay_total: 'お引落し合計', loan_acct: 'お受取口座',
      login_title: 'ログイン', login_branch: '店番', login_acct: '口座番号', login_pw: 'パスワード', login_btn: 'ログイン', login_err: '店番・口座番号・パスワードが正しくありません。', login_fmt: '店番3桁・口座番号7桁を正しく入力してください。', login_hint: 'デモ用：店番 001 / 口座 1000123 / ks1234', login_note: '※ 本サイトはデモンストレーション用です。暗証番号・パスワードをメールでお尋ねすることはありません。',
      login_signup: '新規口座開設', su_title: '新規口座開設', su_step1: 'お客さま情報入力', su_step2: '入力内容確認', su_step3: '開設完了',
      su_name: 'お名前（漢字）', su_kana: 'お名前（カナ）', su_birth: '生年月日', su_sex: '性別', su_sex_m: '男性', su_sex_f: '女性', su_sex_o: 'その他', su_zip: '郵便番号', su_addr: '住所', su_phone: '電話番号', su_email: 'メールアドレス', su_job: 'ご職業', su_type: '口座種別', su_store: '取引店舗', su_pw: 'パスワード', su_pw2: 'パスワード（確認）', su_agree: '利用規約に同意する（必須）', su_terms: '利用規約・個人情報の取扱いに同意の上、お進みください。',
      su_next: '確認へ進む', su_submit: 'この内容で開設する', su_done: '口座開設が完了しました', su_done_msg: '以下の口座を発行しました。この店番・口座番号・パスワードでログインできます。', su_toLogin: 'ログイン画面へ', su_result_store: '店番・店舗', su_result_no: '口座番号', su_result_type: '口座種別',
      su_err_req: '必須項目をすべてご入力ください。', su_err_pw: 'パスワードが一致しません。', su_err_agree: '利用規約に同意が必要です。', digits3: '3桁', digits7: '7桁', acct_futsu: '普通預金', acct_toza: '当座預金',
      us_title: '設定', us_lang: '表示言語', us_member: '会員情報', us_holdings: '保有口座', us_newacct: '追加口座開設', us_holdings_hint: '※ 口座種別・店舗・口座番号は「保有口座」でご確認いただけます。',
      tr_resv: '振込予約日', tr_resv_today: '本日中', dl_title: '明細ダウンロード', dl_btn: 'ダウンロード', tr_err_live: '残高が不足しています',
      mf_kind: '区分', mf_from: '期間（自）', mf_to: '期間（至）', mf_clear: 'クリア', mf_none: '該当する取引がありません。',
      hold_title: '保有口座', hold_rate: '適用金利（年）', hold_note: '※ 金利は口座種別ごとのデモ固定値です。', rep_label: '代表口座', set_rep: '代表に設定',
      na_title: '追加口座開設', na_step1: '口座情報入力', na_step2: '内容確認', na_step3: '開設完了', na_fixed_note: 'お名前・生年月日・性別はご登録情報を引き継ぎます。', na_term: '期間', na_months: 'ヶ月', na_monthly: '月々積立額', na_deposit: '預入金額', na_proj: '満期予想額', na_principal: '元金合計', na_interest: '利息（税引前）', na_maturity: '満期受取予想額', na_submit: 'この内容で開設する', na_done: '口座開設が完了しました', na_done_msg: '以下の口座を発行しました。',
      loan_cmp3: function (a, b, c) { return '総利息の比較 → 元金均等 ' + b + ' ＜ 元利均等 ' + a + ' ＜ 満期一括 ' + c + '（同条件では満期一括が最大）'; },
      nc_title: '新規お知らせ作成', nc_f_title: 'タイトル', nc_f_body: '本文', nc_f_file: 'ファイル添付', nc_submit: '登録する', nc_tag: '新着', nc_note: '※ 登録するとお知らせ一覧の先頭に即時反映されます（本デモではメモリ上のみ保持）。',
      typeMap: { '普通': '普通預金', '当座': '当座預金', '積立': '積立定期', '定期': '定期預金' },
      txnMap: { '入金': '入金', '出金': '出金', '振込': '振込', '手数料': '振込手数料', '融資実行': 'ローン入金', '融資返済': 'ローン返済' },
      typeAll: 'すべて',
      notices: [
        { date: '2026/07/01', tag: 'メンテナンス', title: 'システムメンテナンスのお知らせ（7/15 2:00〜5:00 は一時ご利用いただけません）' },
        { date: '2026/06/28', tag: '重要', title: '振込手数料改定に関するご案内（2026年8月1日〜）' },
        { date: '2026/06/20', tag: 'セキュリティ', title: 'フィッシング詐欺にご注意ください。当行が暗証番号をメールでお尋ねすることはありません。' }
      ],
      ft_sec1: 'セキュリティについて', ft_sec2: 'フィッシング対策'
    },
    ko: {
      bankName: 'KS은행', bankSub: '인터넷뱅킹', sama: '님', lastLogin: '최종 로그인', logout: '로그아웃',
      balanceLabel: '잔액', showBal: '잔액 표시', hideBal: '잔액 숨김', oshirase: '공지사항',
      ic_meisai: '명세조회', ic_soukin: '이체', ic_loan: '대출',
      meisaiTitle: '명세조회', th_date: '거래일', th_type: '거래 내용', th_out: '출금액', th_in: '입금액',
      fr_title: '이체', trStep1: '입금처 입력', trStep2: '내용 확인', trStep3: '완료',
      l_branch: '지점명', l_accno: '계좌번호', l_amount: '이체 금액', l_amount2: '금액', yen: '엔',
      confirmBtn: '확인', backBtn: '뒤로', executeBtn: '이체 실행', confirmLead: '아래 내용으로 진행합니다. 문제가 없으면 진행해 주세요.',
      feeLabel: '이체 수수료', totalLabel: '총 출금액', fromLabel: '출금 계좌', toLabel: '입금처',
      tr_selBank: '입금처 금융기관 선택', tr_searchBank: '금융기관명 검색', tr_selBranch: '지점 선택', tr_searchBranch: '지점번호·지점명 검색(부분 일치)', tr_noResult: '해당하는 항목이 없습니다',
      receiptLabel: '접수번호', dtLabel: '처리일시', afterBal: '거래 후 잔액', doneMsgTr: '이체를 접수했습니다', toHome: '홈으로',
      note_fee: '※ 이체 수수료 110엔을 출금 계좌에서 인출합니다.', note_atomic: '※ 이체액과 수수료는 일괄 처리되며, 잔액부족·계좌동결 시 거래를 승인할 수 없습니다.',
      err_amount: '올바른 금액을 입력하세요.', err_accno: '입금처 계좌번호를 입력하세요.', err_insuf: '잔액이 부족합니다.', err_frozen: '고객님의 계좌는 현재 이용하실 수 없습니다.', err_insuf_wdr: '잔액이 부족하여 출금할 수 없습니다.',
      loan_title: '대출', loan_step1: '대출내용 입력', loan_step2: '내용 확인', loan_step3: '신청 완료',
      loan_totalBorrow: '대출 총액', loan_remainPay: '남은 상환액', loan_availLeft: '남은 대출 가능액', loan_amt: '대출 금액', loan_term: '상환 기간', loan_years: '년', loan_rate: '적용 금리(연)',
      loan_monthly: '월 상환액', loan_total: '총 상환액', loan_sim: '상환 시뮬레이션', loan_apply: '이 내용으로 신청', loan_none: '현재 이용 중인 대출이 없습니다.', loan_apply_btn: '신청하기', loan_bal: '대출 잔액', loan_done: '대출 신청을 접수했습니다', loan_err_over: '대출 가능액을 초과했습니다.',
      loan_method: '상환 방식', loan_mA: '원리금균등상환', loan_mB: '원금균등상환', loan_mC: '만기일시상환', loan_interest: '총 이자',
      loan_capA: '매월 상환액이 일정', loan_capB: '매월 원금이 일정·상환액은 점감', loan_capC: '이자만 상환·원금은 만기에 일시',
      loan_repay_btn: '상환하기', repay_title: '대출 상환', repay_bal: '현재 대출 잔액', repay_all: '전액 상환', repay_exec: '상환하기', repay_done: '상환을 접수했습니다', repay_err_over: '상환액이 대출 잔액을 초과했습니다.', repay_err_bal: '계좌 잔액이 부족합니다.',
      repay_principal: '상환 원금', repay_interest: '경과 이자', repay_fee: '중도상환 수수료', repay_total: '총 출금액', loan_acct: '수령 계좌',
      loan_cmp3: function (a, b, c) { return '총 이자 비교 → 원금균등 ' + b + ' ＜ 원리금균등 ' + a + ' ＜ 만기일시 ' + c + '(동일 조건에서 만기일시가 최대)'; },
      login_title: '로그인', login_branch: '점번', login_acct: '계좌번호', login_pw: '비밀번호', login_btn: '로그인', login_err: '점번·계좌번호·비밀번호가 올바르지 않습니다.', login_fmt: '점번 3자리·계좌번호 7자리를 정확히 입력하세요.', login_hint: '데모용：점번 001 / 계좌 1000123 / ks1234', login_note: '※ 본 사이트는 데모용입니다. 비밀번호를 메일로 묻는 일은 없습니다.',
      login_signup: '신규 계좌 개설', su_title: '신규 계좌 개설', su_step1: '고객 정보 입력', su_step2: '입력 내용 확인', su_step3: '개설 완료',
      su_name: '이름(한자)', su_kana: '이름(가나)', su_birth: '생년월일', su_sex: '성별', su_sex_m: '남성', su_sex_f: '여성', su_sex_o: '기타', su_zip: '우편번호', su_addr: '주소', su_phone: '전화번호', su_email: '이메일', su_job: '직업', su_type: '계좌 종별', su_store: '거래 점포', su_pw: '비밀번호', su_pw2: '비밀번호(확인)', su_agree: '이용약관에 동의(필수)', su_terms: '이용약관·개인정보 처리에 동의 후 진행해 주세요.',
      su_next: '확인으로', su_submit: '이 내용으로 개설', su_done: '계좌 개설이 완료되었습니다', su_done_msg: '아래 계좌를 발급했습니다. 이 점번·계좌번호·비밀번호로 로그인할 수 있습니다.', su_toLogin: '로그인 화면으로', su_result_store: '점번·점포', su_result_no: '계좌번호', su_result_type: '계좌 종별',
      su_err_req: '필수 항목을 모두 입력해 주세요.', su_err_pw: '비밀번호가 일치하지 않습니다.', su_err_agree: '이용약관 동의가 필요합니다.', digits3: '3자리', digits7: '7자리', acct_futsu: '보통예금', acct_toza: '당좌예금',
      us_title: '설정', us_lang: '표시 언어', us_member: '회원정보', us_holdings: '보유계좌', us_newacct: '추가계좌 개설', us_holdings_hint: '※ 계좌종별·점포·계좌번호는 「보유계좌」에서 확인하실 수 있습니다.',
      tr_resv: '이체 예약일', tr_resv_today: '당일 중', dl_title: '명세 다운로드', dl_btn: '다운로드', tr_err_live: '잔액이 부족합니다',
      mf_kind: '구분', mf_from: '기간(시작)', mf_to: '기간(종료)', mf_clear: '초기화', mf_none: '해당하는 거래가 없습니다.',
      hold_title: '보유계좌', hold_rate: '적용 금리(연)', hold_note: '※ 금리는 계좌종별별 데모 고정값입니다.', rep_label: '대표계좌', set_rep: '대표로 설정',
      na_title: '추가계좌 개설', na_step1: '계좌 정보 입력', na_step2: '내용 확인', na_step3: '개설 완료', na_fixed_note: '이름·생년월일·성별은 기존 등록정보를 이어받습니다.', na_term: '기간', na_months: '개월', na_monthly: '월 적립액', na_deposit: '예치 금액', na_proj: '만기 예상액', na_principal: '원금 합계', na_interest: '이자(세전)', na_maturity: '만기 수령 예상액', na_submit: '이 내용으로 개설', na_done: '계좌 개설이 완료되었습니다', na_done_msg: '아래 계좌를 발급했습니다.',
      nc_title: '공지사항 작성', nc_f_title: '제목', nc_f_body: '본문', nc_f_file: '파일 첨부', nc_submit: '등록', nc_tag: '신규', nc_note: '※ 등록하면 공지 목록 맨 위에 즉시 반영됩니다(본 데모는 메모리에만 보관).',
      typeMap: { '普通': '보통예금', '当座': '당좌예금', '積立': '적금', '定期': '정기예금' },
      txnMap: { '入金': '입금', '出金': '출금', '振込': '이체', '手数料': '이체 수수료', '融資実行': '대출입금', '融資返済': '대출상환' },
      typeAll: '전체',
      notices: [
        { date: '2026/07/01', tag: '점검', title: '시스템 점검 안내 (7/15 2:00〜5:00 일시 이용 불가)' },
        { date: '2026/06/28', tag: '중요', title: '이체 수수료 개정 안내 (2026년 8월 1일〜)' },
        { date: '2026/06/20', tag: '보안', title: '피싱 사기에 주의하세요. 당행이 비밀번호를 메일로 묻는 일은 없습니다.' }
      ],
      ft_sec1: '보안 안내', ft_sec2: '피싱 대책'
    }
  };
}

/* ============================================================
   App state + core helpers
   ============================================================ */
var App = { state: null };

App.initialState = function () {
  return {
    lang: 'ja',
    page: 'home', pageStack: [],
    balHidden: false,
    accounts: buildAccounts(), journal: buildJournal(),
    me: '1000123',
    trStep: 1, trStage: 'bank', trBank: '', trBankQuery: '', trBranchQuery: '', trBranch: '', trBcode: '', trTo: '', trAmt: '', trErr: null, trReceipt: null, trResvDate: 'today',
    loanStep: 0, loanAmt: '', loanTermY: '5', loanMethod: 'A', loanErr: null, loanReceipt: null, loans: [], loanHistory: [], loanAcct: '1000123', loanDetailIdx: null, repayIdx: null, repayAmt: '', repayErr: null, repayReceipt: null,
    isLoggedIn: false, loginBranch: '', loginAcct: '', loginPw: '', loginErr: null,
    authPage: 'login', suStep: 1, suErr: null, suResult: null,
    suName: '', suKana: '', suBirth: '', suSex: '男性', suZip: '', suAddr: '', suPhone: '', suEmail: '', suJob: '', suType: '普通', suStore: '001', suPw: '', suPw2: '', suAgree: false, suSaveTerm: '6', suSaveMonthly: '30000',
    showUserSettings: false,
    dlFormat: 'csv',
    meisaiAcct: null, meisaiType: 'all', meisaiFrom: '', meisaiTo: '', meisaiPickOpen: false,
    repAcct: '1000123', ownNos: ['1000123'], homeView: '1000123',
    naStep: 1, naType: '普通', naStore: '001', naPw: '', naErr: null, naResult: null, naSaveTerm: '6', naSaveMonthly: '30000',
    extraNotices: [], dbNotices: [], ncTitle: '', ncBody: '', ncFiles: [], selNotice: null, hiddenBase: [],
    rSeq: 10247
  };
};
App.state = App.initialState();

App.setState = function (patch) {
  var p = (typeof patch === 'function') ? patch(App.state) : patch;
  Object.assign(App.state, p);
  render();
};

App.T = function () { return dict()[App.state.lang]; };
App.rateOf = function (type) { var r = RATE_BY_TYPE[type]; return r == null ? 0 : r; };
App._f = function (n) { return fmtYen(n); };
App._amt = function (v) { var n = parseInt(String(v || '').replace(/[^0-9]/g, ''), 10); return isNaN(n) ? 0 : n; };
App._find = function (no) { return App.state.accounts.find(function (a) { return a.no === no; }); };
App._upd = function (no, delta) { return App.state.accounts.map(function (a) { return a.no === no ? Object.assign({}, a, { balance: a.balance + delta }) : a; }); };
App._now = function () { var d = new Date(), p = function (n) { return String(n).padStart(2, '0'); }; return d.getFullYear() + '/' + p(d.getMonth() + 1) + '/' + p(d.getDate()) + ' ' + p(d.getHours()) + ':' + p(d.getMinutes()); };
App._today = function () { return App._now().slice(0, 10).replace(/\//g, '-'); };
App._receipt = function (pre) { var s = String(App.state.rSeq).padStart(4, '0'); var d = new Date(), p = function (n) { return String(n).padStart(2, '0'); }; return pre + d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) + '-' + s; };
App.me = function () { return App._find(App.state.me); };
App._saveProject = function (type, principalOrMonthly, months) {
  var rate = App.rateOf(type) / 100, principal, interest;
  if (type === '積立') { var m = principalOrMonthly; principal = m * months; var avg = m * (months + 1) / 2; interest = Math.floor(avg * rate * months / 12); }
  else { principal = principalOrMonthly; interest = Math.floor(principal * rate * months / 12); }
  return { principal: principal, interest: interest, maturity: principal + interest };
};

/* ============================================================
   Navigation
   ============================================================ */
App._resetFlows = function () {
  return {
    trStep: 1, trStage: 'bank', trBank: '', trBankQuery: '', trBranchQuery: '', trErr: null, trReceipt: null, trAmt: '', trTo: '', trBranch: '', trBcode: '', trResvDate: 'today',
    loanStep: 0, loanErr: null, loanReceipt: null, loanAmt: '', loanMethod: 'A',
    repayIdx: null, repayReceipt: null, repayErr: null, repayAmt: '', loanDetailIdx: null
  };
};
App.goTo = function (p) { return function () { App.setState(function (s) { return Object.assign({ page: p, pageStack: s.pageStack.concat([s.page]) }, App._resetFlows()); }); }; };
App.back = function () { App.setState(function (s) { var st = s.pageStack.slice(); var prev = st.length ? st.pop() : 'home'; return Object.assign({ page: prev, pageStack: st }, App._resetFlows()); }); };
App.goHome = function () { App.setState(Object.assign({ page: 'home', pageStack: [] }, App._resetFlows())); };
App.goSoukin = App.goTo('transfer');
App.loadLoans = function (kouza) {
  kouza = String(kouza || ''); if (!kouza) return;
  fetch('/api/loan?kouza=' + encodeURIComponent(kouza))
    .then(function (r) { return r.json(); })
    .then(function (d) {
      if (!d || !d.ok || !d.loans) return;
      App.setState({ loans: d.loans.map(function (l) { return { loanId: l.loanId, amt: Number(l.principal), bal: Number(l.balance), method: l.method, years: l.years, date: '', acct: kouza }; }) });
    }).catch(function () {});
};
App.goLoan = function () { var me = App.me(); App.loadLoans(me && me.no); App.goTo('loan')(); };
App.goMeisai = function () { var a = App._meisaiAcct(); App.loadMeisai(a && a.no); App.goTo('meisai')(); };

/* ============================================================
   Header / settings / language
   ============================================================ */
App.onToggleBal = function () { App.setState(function (s) { return { balHidden: !s.balHidden }; }); };
App.chg = function (key) { return function (e) { App.setState((function () { var o = {}; o[key] = e.target.value; return o; })()); }; };
App.onToggleUserSettings = function () { App.setState(function (s) { return { showUserSettings: !s.showUserSettings }; }); };
App.onLangSelect = function (e) { App.setState({ lang: e.target.value }); };
App.goMember = function () { App.setState(function (s) { return { page: 'member', pageStack: s.pageStack.concat([s.page]), showUserSettings: false }; }); };
App.goHoldings = function () { App.setState(function (s) { return { page: 'holdings', pageStack: s.pageStack.concat([s.page]), showUserSettings: false }; }); };

/* ============================================================
   Login / signup
   ============================================================ */
App.onLoginBranch = function (e) { App.setState({ loginBranch: (e.target.value || '').replace(/[^0-9]/g, '').slice(0, 3) }); };
App.onLoginAcct = function (e) { App.setState({ loginAcct: (e.target.value || '').replace(/[^0-9]/g, '').slice(0, 7) }); };
App.onLoginPw = function (e) { App.setState({ loginPw: e.target.value }); };
App.doLogin = function () {
  var T = App.T(), s = App.state;
  var b = (s.loginBranch || '').replace(/[^0-9]/g, ''), a = (s.loginAcct || '').replace(/[^0-9]/g, ''), p = s.loginPw || '';
  if (b.length !== 3 || a.length !== 7) return App.setState({ loginErr: T.login_fmt });
  App.setState({ loginErr: null });
  // 実COBOLバックエンド(LOGIN.cbl / CGI)へ: 店番3桁 + 口座7桁 + PW を検証
  var body = 'branch=' + encodeURIComponent(b) + '&acct=' + encodeURIComponent(a) + '&pw=' + encodeURIComponent(p);
  fetch('/api/login', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: body })
    .then(function (r) { return r.json(); })
    .then(function (d) {
      if (!d || !d.ok) return App.setState({ loginErr: T.login_err });
      if (String(d.joutai) === '9') return App.setState({ loginErr: T.err_frozen || T.login_err });
      var accts = App.state.accounts.slice();
      var idx = accts.findIndex(function (x) { return x.no === a; });
      var base = idx >= 0 ? accts[idx] : { no: a, kana: '', branch: '', bcode: b, pw: p };
      // DBを正とし、残高・名義・種別・状態をログインの都度同期する
      var acc = Object.assign({}, base, {
        kanji: d.meigiKanji || base.kanji || '', type: d.type || base.type || '普通',
        balance: Number(d.zandaka) || 0, bcode: b, pw: p,
        status: (String(d.joutai) === '9' ? '凍結' : '正常')
      });
      if (idx >= 0) accts[idx] = acc; else accts.push(acc);
      App.setState({ accounts: accts, isLoggedIn: true, me: acc.no, page: 'home', pageStack: [], loginErr: null, loginPw: '', repAcct: acc.no, ownNos: [acc.no], homeView: acc.no, meisaiAcct: null });
      App.loadNotices();
    })
    .catch(function () { App.setState({ loginErr: T.login_err }); });
};
App.doLogout = function () { App.setState({ isLoggedIn: false, page: 'home', pageStack: [], loginBranch: '', loginAcct: '', loginPw: '', loginErr: null, showUserSettings: false, authPage: 'login' }); };
App.goSignup = function () { App.setState({ authPage: 'signup', suStep: 1, suErr: null, suResult: null }); };
App.goLoginPage = function () { App.setState({ authPage: 'login', suErr: null }); };
App.suChg = function (key) { return function (e) { App.setState((function () { var o = {}; o[key] = e.target.value; return o; })()); }; };
App.suZipChg = function (e) { App.setState({ suZip: (e.target.value || '').replace(/[^0-9]/g, '').slice(0, 7) }); };
App.suPhoneChg = function (e) { App.setState({ suPhone: (e.target.value || '').replace(/[^0-9-]/g, '').slice(0, 13) }); };
App.suAgreeToggle = function () { App.setState(function (s) { return { suAgree: !s.suAgree }; }); };
App.suConfirm = function () {
  var T = App.T(), s = App.state;
  if (!s.suName.trim() || !s.suKana.trim() || !s.suBirth.trim() || !s.suAddr.trim() || !s.suPhone.trim() || !s.suEmail.trim() || !s.suPw || !s.suPw2) return App.setState({ suErr: T.su_err_req });
  if (s.suPw !== s.suPw2) return App.setState({ suErr: T.su_err_pw });
  if (!s.suAgree) return App.setState({ suErr: T.su_err_agree });
  App.setState({ suErr: null, suStep: 2 });
};
App.suBack = function () { App.setState({ suStep: 1, suErr: null }); };
App.suExecute = function () {
  var s = App.state, store = STORES.find(function (x) { return x.code === s.suStore; }) || STORES[0];
  // 実COBOLバックエンド(SIGNUP.cbl / CGI)で口座開設。口座番号はDB採番(SEQ_KOUZA_DYN 9000001~)。
  var body = 'kanji=' + encodeURIComponent(s.suName.trim()) + '&kana=' + encodeURIComponent(s.suKana.trim()) +
    '&type=' + encodeURIComponent(s.suType) + '&branch=' + encodeURIComponent(store.code) + '&pw=' + encodeURIComponent(s.suPw) +
    '&birth=' + encodeURIComponent(s.suBirth) + '&sex=' + encodeURIComponent(s.suSex) + '&zip=' + encodeURIComponent(s.suZip) +
    '&addr=' + encodeURIComponent(s.suAddr) + '&phone=' + encodeURIComponent(s.suPhone) + '&email=' + encodeURIComponent(s.suEmail) + '&job=' + encodeURIComponent(s.suJob);
  fetch('/api/signup', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: body })
    .then(function (r) { return r.json(); })
    .then(function (d) {
      if (!d || !d.ok || !d.kouza) return App.setState({ suErr: App.T().su_err_req });
      var no = String(d.kouza);
      var acc = { no: no, kanji: s.suName.trim(), kana: s.suKana.trim(), type: s.suType, balance: 0, status: '正常', branch: store.name, bcode: store.code, pw: s.suPw, prof: { birth: s.suBirth, sex: s.suSex, zip: s.suZip, addr: s.suAddr, phone: s.suPhone, email: s.suEmail, job: s.suJob } };
      App.setState({ accounts: App.state.accounts.concat([acc]), suResult: { tenban: store.code, store: store.name, no: no, type: s.suType }, suStep: 3 });
    })
    .catch(function () { App.setState({ suErr: App.T().su_err_req }); });
};
App.suToLogin = function () {
  var r = App.state.suResult;
  App.setState({
    authPage: 'login', loginBranch: r ? r.tenban : '', loginAcct: r ? r.no : '', loginPw: '', loginErr: null,
    suStep: 1, suName: '', suKana: '', suBirth: '', suSex: '男性', suZip: '', suAddr: '', suPhone: '', suEmail: '', suJob: '', suType: '普通', suStore: '001', suPw: '', suPw2: '', suAgree: false
  });
};

/* ============================================================
   Home carousel / representative account
   ============================================================ */
App.homeCar = function (dir) { return function () { var s = App.state; var n = s.ownNos.length; if (n <= 1) return; var i = s.ownNos.indexOf(s.homeView); if (i < 0) i = 0; i = (i + dir + n) % n; App.setState({ homeView: s.ownNos[i] }); }; };
App.setRep = function (no) { return function (e) { if (e && e.stopPropagation) e.stopPropagation(); App.setState({ repAcct: no, me: no, meisaiAcct: null }); }; };


/* ============================================================
   Transfer (振込・イ체)
   ============================================================ */
App.onTrBankQuery = function (e) { App.setState({ trBankQuery: e.target.value }); };
App.onTrBranchQuery = function (e) { App.setState({ trBranchQuery: e.target.value }); };
App.trPickBank = function (name) { App.setState({ trBank: name, trStage: 'branch', trBranchQuery: '', trBcode: '', trBranch: '' }); };
App.trPickBranch = function (b) { App.setState({ trBcode: b.code, trBranch: b.name, trStage: 'account' }); };
App.trStageBack = function () {
  var s = App.state;
  if (s.trStep === 1 && s.trStage === 'account') return App.setState({ trStage: 'branch', trErr: null });
  if (s.trStep === 1 && s.trStage === 'branch') return App.setState({ trStage: 'bank', trErr: null });
  App.back();
};
App.onTrResv = function (e) { App.setState({ trResvDate: e.target.value }); };
App.trConfirm = function () {
  var T = App.T(), me = App.me(), s = App.state;
  if (me.status === '凍結') return App.setState({ trErr: T.err_frozen });
  if (!s.trTo || s.trTo.replace(/[^0-9]/g, '').length === 0) return App.setState({ trErr: T.err_accno });
  var amt = App._amt(s.trAmt);
  if (amt <= 0) return App.setState({ trErr: T.err_amount });
  var total = amt + TRANSFER_FEE;
  if (total > me.balance) return App.setState({ trErr: T.err_insuf + '（' + T.balanceLabel + ' ' + App._f(me.balance) + ' ／ ' + T.totalLabel + ' ' + App._f(total) + '）' });
  App.setState({ trErr: null, trStep: 2 });
};
App.trBack = function () { App.setState({ trStep: 1, trErr: null }); };
App.trExecute = function () {
  var s = App.state, me = App._find(s.me), amt = App._amt(s.trAmt), fee = TRANSFER_FEE;
  var toNo = s.trTo.replace(/[^0-9]/g, '').padStart(7, '0');
  // 実COBOLバックエンド(FURIKOMI.cbl / CGI)へ振込(原子的処理)。残高はDB確定値。
  var body = 'kouza=' + encodeURIComponent(me.no) + '&aite=' + encodeURIComponent(toNo) + '&kingaku=' + amt;
  fetch('/api/furikomi', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: body })
    .then(function (r) { return r.json(); })
    .then(function (d) {
      if (!d || !d.ok) {
        var T = App.T();
        return App.setState({ trStep: 1, trErr: (d && d.error === 'frozen') ? T.err_frozen : T.err_insuf });
      }
      if (d.fee != null) fee = Number(d.fee);
      var to = App._find(toNo);
      var accts = App.state.accounts.map(function (x) { return x.no === me.no ? Object.assign({}, x, { balance: Number(d.afterBal) }) : x; });
      if (to) accts = accts.map(function (x) { return x.no === to.no ? Object.assign({}, x, { balance: x.balance + amt }) : x; });
      var j = App.state.journal.concat([
        { date: App._today(), no: me.no, type: '振込', amt: amt, memoJa: (s.trBranch || '') + '宛 振込', memoKo: (s.trBranch || '') + ' 이체' },
        { date: App._today(), no: me.no, type: '手数料', amt: fee, memoJa: '振込手数料', memoKo: '이체 수수료' }
      ]);
      if (to) j = j.concat([{ date: App._today(), no: to.no, type: '入金', amt: amt, memoJa: me.kanji + 'より振込入金', memoKo: me.kanji + '로부터 이체 입금' }]);
      App.setState({ accounts: accts, journal: j, trReceipt: { no: (d.receipt || App._receipt('WEB')), dt: App._now() }, rSeq: App.state.rSeq + 1, trStep: 3 });
    })
    .catch(function () { App.setState({ trStep: 1, trErr: App.T().err_insuf }); });
};

/* ============================================================
   Loan
   ============================================================ */
App.onLoanAmt = function (e) { App.setState({ loanAmt: e.target.value }); };
App.onLoanTerm = function (e) { App.setState({ loanTermY: e.target.value }); };
App.onLoanAcct = function (e) { App.setState({ loanAcct: e.target.value }); };
App.loanCalc = function () {
  var P = App._amt(App.state.loanAmt), years = parseInt(App.state.loanTermY, 10) || 0, n = years * 12, r = LOAN_RATE / 12;
  var z = { monthly: 0, total: 0, interest: 0 };
  if (P <= 0 || n <= 0) return { A: Object.assign({}, z), B: Object.assign({}, z), C: Object.assign({}, z) };
  var fin = function (sched) { var total = sched.reduce(function (s, x) { return s + x.pay; }, 0); return { monthly: sched[0].pay, total: total, interest: total - P }; };
  var mA = Math.round(P * r / (1 - Math.pow(1 + r, -n)));
  var bal = P, sa = [];
  for (var i = 1; i <= n; i++) { var interest = Math.round(bal * r), principal = mA - interest, pay = mA; if (i === n) { principal = bal; pay = principal + interest; } bal = Math.max(0, bal - principal); sa.push({ i: i, pay: pay, interest: interest, principal: principal, bal: bal }); }
  var base = Math.floor(P / n); bal = P; var sb = [];
  for (i = 1; i <= n; i++) { interest = Math.round(bal * r); principal = (i === n ? bal : base); pay = principal + interest; bal = Math.max(0, bal - principal); sb.push({ i: i, pay: pay, interest: interest, principal: principal, bal: bal }); }
  bal = P; var sc = [];
  for (i = 1; i <= n; i++) { interest = Math.round(P * r); principal = (i === n ? P : 0); pay = interest + principal; if (i === n) bal = 0; sc.push({ i: i, pay: pay, interest: interest, principal: principal, bal: bal }); }
  return { A: fin(sa), B: fin(sb), C: fin(sc) };
};
App.setLoanA = function () { App.setState({ loanMethod: 'A' }); };
App.setLoanB = function () { App.setState({ loanMethod: 'B' }); };
App.setLoanC = function () { App.setState({ loanMethod: 'C' }); };
App.loanConfirm = function () {
  var T = App.T(), p = App._amt(App.state.loanAmt);
  var remain = LOAN_AVAIL - App.state.loans.reduce(function (s, l) { return s + l.bal; }, 0);
  if (p <= 0) return App.setState({ loanErr: T.err_amount });
  if (p > remain) return App.setState({ loanErr: T.loan_err_over + '（' + T.loan_availLeft + ' ' + App._f(remain) + '）' });
  App.setState({ loanErr: null, loanStep: 2 });
};
App.loanApply = function () {
  var remain = LOAN_AVAIL - App.state.loans.reduce(function (s, l) { return s + l.bal; }, 0);
  if (remain <= 0) { window.alert(App.state.lang === 'ko' ? '대출 가능액이 부족합니다.' : 'お借入可能額が不足しています。'); return; }
  App.setState({ loanStep: 1, loanErr: null });
};
App.loanStepBack = function () {
  if (App.state.loanStep === 2) return App.setState({ loanStep: 1, loanErr: null });
  App.setState({ loanStep: 0, loanErr: null });
};
App.loanExecute = function () {
  var s = App.state, me = App._find(s.me), P = App._amt(s.loanAmt), acctNo = s.loanAcct || me.no;
  // 実COBOLバックエンド(LOAN.cbl / CGI)で融資実行。LOAN_ASIS登録 + acctNoへ元金入金 + TORIHIKI記録。
  var body = 'kouza=' + encodeURIComponent(acctNo) + '&amt=' + P + '&method=' + encodeURIComponent(s.loanMethod) + '&years=' + encodeURIComponent(s.loanTermY);
  fetch('/api/loan', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: body })
    .then(function (r) { return r.json(); })
    .then(function (d) {
      if (!d || !d.ok) return App.setState({ loanErr: App.T().err_amount });
      var accts = App.state.accounts.map(function (a) { return a.no === acctNo ? Object.assign({}, a, { balance: a.balance + P }) : a; });
      var newLoan = { loanId: d.loanId, amt: P, bal: P, method: s.loanMethod, years: s.loanTermY, date: App._today(), acct: acctNo };
      App.setState({ accounts: accts, loans: App.state.loans.concat([newLoan]), loanReceipt: { no: App._receipt('LOAN'), dt: App._now() }, rSeq: App.state.rSeq + 1, loanStep: 3 });
    })
    .catch(function () { App.setState({ loanErr: App.T().err_amount }); });
};
App.loanOpenDetail = function (i) { return function () { App.setState({ loanDetailIdx: i }); }; };
App.loanCloseDetail = function () { App.setState({ loanDetailIdx: null }); };
App.loanRepayStart = function (i) { return function (e) { if (e && e.stopPropagation) e.stopPropagation(); App.setState({ repayIdx: i, repayAmt: '', repayErr: null, repayReceipt: null, loanDetailIdx: null }); }; };
App.loanRepayCancel = function () { App.setState({ repayIdx: null, repayReceipt: null, repayErr: null, loanDetailIdx: null }); };
App.onRepayAmt = function (e) { App.setState({ repayAmt: e.target.value }); };
App.loanRepayAll = function () { var l = App.state.loans[App.state.repayIdx]; if (l) App.setState({ repayAmt: String(l.bal), repayErr: null }); };
App.loanRepayExecute = function () {
  var T = App.T(), s = App.state, me = App._find(s.me), idx = s.repayIdx, l = s.loans[idx], principal = App._amt(s.repayAmt);
  if (principal <= 0) return App.setState({ repayErr: T.err_amount });
  if (principal > l.bal) return App.setState({ repayErr: T.repay_err_over });
  // 実COBOLバックエンド(REPAY.cbl / CGI)で返済。利息・手数料550・残高更新はDB確定値。
  var body = 'loanId=' + encodeURIComponent(l.loanId) + '&principal=' + principal;
  fetch('/api/repay', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: body })
    .then(function (r) { return r.json(); })
    .then(function (d) {
      if (!d || !d.ok) return App.setState({ repayErr: T.repay_err_bal });
      var interest = Number(d.interest), fee = Number(d.fee), total = Number(d.total), newBal = Number(d.loanBalance), completed = !!d.closed;
      var accts = App.state.accounts.map(function (a) { return a.no === me.no ? Object.assign({}, a, { balance: a.balance - total }) : a; });
      var loans = App.state.loans.slice(), history = App.state.loanHistory;
      if (completed) { history = history.concat([Object.assign({}, loans[idx], { bal: 0, closedDate: App._today() })]); loans = loans.filter(function (_, i) { return i !== idx; }); }
      else { loans = loans.map(function (x, i) { return i === idx ? Object.assign({}, x, { bal: newBal }) : x; }); }
      var label = (s.lang === 'ko' ? '대출계약 No.' : 'ローン契約 No.') + (idx + 1);
      App.setState({ accounts: accts, loans: loans, loanHistory: history, repayReceipt: { no: App._receipt('REPAY'), dt: App._now(), principal: principal, interest: interest, fee: fee, total: total, afterBal: Math.max(0, newBal), completed: completed, label: label }, repayIdx: completed ? null : idx, rSeq: App.state.rSeq + 1 });
    })
    .catch(function () { App.setState({ repayErr: T.repay_err_bal }); });
};

/* ============================================================
   Notices
   ============================================================ */
App.loadNotices = function () {
  fetch('/api/notice')
    .then(function (r) { return r.json(); })
    .then(function (d) { if (d && d.ok && d.notices) App.setState({ dbNotices: d.notices }); })
    .catch(function () {});
};
App.goNoticeNew = function () { App.setState(function (s) { return { page: 'notice_new', pageStack: s.pageStack.concat([s.page]) }; }); };
App.openNotice = function (n) { App.setState(function (s) { return { page: 'notice_detail', pageStack: s.pageStack.concat([s.page]), selNotice: n }; }); };
App.onNcTitle = function (e) { App.setState({ ncTitle: e.target.value }); };
App.onNcBody = function (e) { App.setState({ ncBody: e.target.value }); };
App.onNcFile = function (e) { var names = Array.prototype.slice.call(e.target.files || []).map(function (f) { return f.name; }); App.setState({ ncFiles: names }); };
App.submitNotice = function () {
  var T = App.T(), title = (App.state.ncTitle || '').trim();
  if (!title) return;
  // 実COBOLバックエンド(NOTICE.cbl / CGI)へ登録 → DBから再読込
  var body = 'title=' + encodeURIComponent(title) + '&body=' + encodeURIComponent((App.state.ncBody || '').trim()) + '&tag=' + encodeURIComponent(T.nc_tag);
  fetch('/api/notice', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: body })
    .then(function (r) { return r.json(); })
    .then(function () { App.loadNotices(); App.setState({ page: 'home', pageStack: [], ncTitle: '', ncBody: '', ncFiles: [] }); })
    .catch(function () { App.setState({ page: 'home', pageStack: [], ncTitle: '', ncBody: '', ncFiles: [] }); });
};
App.deleteNotice = function (kind, idx) {
  if (!window.confirm(App.state.lang === 'ko' ? '이 공지를 삭제하시겠습니까?' : 'このお知らせを削除しますか？')) return;
  if (kind === 'extra') { var arr = App.state.extraNotices.slice(); arr.splice(idx, 1); App.setState({ extraNotices: arr }); }
  else { App.setState({ hiddenBase: App.state.hiddenBase.concat([idx]) }); }
};

/* ============================================================
   Meisai (transaction history)
   ============================================================ */
App._meisaiAcct = function () { return App._find(App.state.meisaiAcct || App.state.repAcct || App.state.me) || App.me(); };
// 実COBOLバックエンド(MEISAI.cbl / CGI)から明細を取得し、当該口座のjournalをDB正本で置換する
App.loadMeisai = function (kouza) {
  kouza = String(kouza || '');
  if (!kouza) return;
  fetch('/api/meisai?kouza=' + encodeURIComponent(kouza))
    .then(function (r) { return r.json(); })
    .then(function (d) {
      if (!d || !d.ok || !d.rows) return;
      var kmap = { '1': '入金', '2': '出金', '3': '振込' };
      var mapped = d.rows.slice().reverse().map(function (row) {
        var kbn = String(row.kbn), aite = Number(row.aite || 0), mj, mk;
        if (row.memo) { mj = row.memo; mk = row.memo; }               // DB(TEKIYOU)에 원본 적요가 있으면 그대로
        else if (kbn === '3') { mj = (aite ? aite + '宛 ' : '') + '振込'; mk = (aite ? aite + '로 ' : '') + '이체'; }
        else if (kbn === '2') { mj = '出金'; mk = '출금'; }
        else if (kbn === '1' && aite) { mj = aite + 'より振込入金'; mk = aite + '로부터 이체입금'; }
        else { mj = '入金'; mk = '입금'; }
        return { date: row.date, no: kouza, type: (kmap[kbn] || '入金'),
                 amt: Number(row.kingaku), memoJa: mj, memoKo: mk, _dbAfter: Number(row.afterBal) };
      });
      var other = App.state.journal.filter(function (j) { return j.no !== kouza; });
      App.setState({ journal: other.concat(mapped) });
    })
    .catch(function () {});
};
App._meisaiRaw = function () {
  var T = App.T(), me = App._meisaiAcct(), ko = App.state.lang === 'ko';
  var tx = App.state.journal.filter(function (j) { return j.no === me.no; });
  var sign = function (t) { return (t.type === '入金' || t.type === '融資実行') ? 1 : -1; };
  var totalDelta = tx.reduce(function (s, t) { return s + sign(t) * t.amt; }, 0);
  var run = me.balance - totalDelta;
  var withBal = tx.map(function (t) {
    if (t._dbAfter != null) return Object.assign({}, t, { _after: t._dbAfter }); // DB(TORIHIKI)由来はafterBalをそのまま採用(手数料込みの確定残高)
    run += sign(t) * t.amt; return Object.assign({}, t, { _after: run });
  });
  var f = App.state.meisaiType;
  if (f !== 'all') withBal = withBal.filter(function (t) { return t.type === f; });
  if (App.state.meisaiFrom) withBal = withBal.filter(function (t) { return t.date >= App.state.meisaiFrom; });
  if (App.state.meisaiTo) withBal = withBal.filter(function (t) { return t.date <= App.state.meisaiTo; });
  var rows = withBal.map(function (t) {
    var isIn = sign(t) > 0, memo = (ko ? t.memoKo : t.memoJa) || '';
    return [t.date, memo || (T.txnMap[t.type] || t.type), isIn ? '' : t.amt, isIn ? t.amt : '', t._after, t.type];
  });
  return { head: [T.th_date, T.th_type, T.th_out, T.th_in, T.afterBal], rows: rows.slice().reverse(), me: me };
};
App._download = function (filename, text, mime) {
  var blob = new Blob([text], { type: mime }), url = URL.createObjectURL(blob), a = document.createElement('a');
  a.href = url; a.download = filename; document.body.appendChild(a); a.click();
  setTimeout(function () { document.body.removeChild(a); URL.revokeObjectURL(url); }, 100);
};
App.dlCsv = function () {
  var r = App._meisaiRaw();
  var esc2 = function (v) { var s = String(v); return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };
  var csv = '﻿' + [r.head].concat(r.rows).map(function (row) { return row.map(esc2).join(','); }).join('\r\n');
  App._download('meisai_' + App.state.me + '.csv', csv, 'text/csv');
};
App.dlTxt = function () {
  var r = App._meisaiRaw();
  var fmt = function (n) { return n === '' ? '' : String(n); };
  var pad = function (s, n) { s = String(s); while (s.length < n) s += ' '; return s; };
  var padL = function (s, n) { s = String(s); while (s.length < n) s = ' ' + s; return s; };
  var t = App.T().meisaiTitle + '  ' + r.me.branch + ' ' + r.me.no + '\n' + '='.repeat(64) + '\n';
  t += pad(r.head[0], 12) + pad(r.head[1], 20) + padL(r.head[2], 11) + padL(r.head[3], 11) + padL(r.head[4], 13) + '\n' + '-'.repeat(67) + '\n';
  r.rows.forEach(function (row) { t += pad(row[0], 12) + pad(String(row[1]).slice(0, 18), 20) + padL(fmt(row[2]), 11) + padL(fmt(row[3]), 11) + padL(fmt(row[4]), 13) + '\n'; });
  App._download('meisai_' + App.state.me + '.txt', t, 'text/plain');
};
App.dlPdf = function () {
  var T = App.T(), r = App._meisaiRaw(), fmt = function (n) { return n === '' ? '' : '¥' + Number(n).toLocaleString('ja-JP'); };
  var h = '<html><head><meta charset="utf-8"><title>' + T.meisaiTitle + '</title><style>body{font-family:sans-serif;padding:24px;color:#1a1a1a}h1{font-size:17px}table{border-collapse:collapse;width:100%;font-size:12px;margin-top:12px}th,td{border:1px solid #ccc;padding:6px 10px}th{background:#fff3c4;text-align:left}td.n{text-align:right;font-variant-numeric:tabular-nums;font-family:monospace}</style></head><body><h1>' + T.meisaiTitle + ' — ' + r.me.branch + ' ' + r.me.no + '</h1><table><thead><tr><th>' + r.head[0] + '</th><th>' + r.head[1] + '</th><th>' + r.head[2] + '</th><th>' + r.head[3] + '</th><th>' + r.head[4] + '</th></tr></thead><tbody>';
  r.rows.forEach(function (row) { h += '<tr><td>' + row[0] + '</td><td>' + row[1] + '</td><td class="n">' + fmt(row[2]) + '</td><td class="n">' + fmt(row[3]) + '</td><td class="n">' + fmt(row[4]) + '</td></tr>'; });
  h += '</tbody></table></body></html>';
  var w = window.open('', '_blank'); if (!w) return;
  w.document.write(h); w.document.close(); w.focus();
  setTimeout(function () { try { w.print(); } catch (e) {} }, 400);
};
App.onDlFormat = function (e) { App.setState({ dlFormat: e.target.value }); };
App.dlRun = function () { var f = App.state.dlFormat; if (f === 'pdf') App.dlPdf(); else if (f === 'txt') App.dlTxt(); else App.dlCsv(); };
App.onMeisaiType = function (e) { App.setState({ meisaiType: e.target.value }); };
App.onMeisaiFrom = function (e) { App.setState({ meisaiFrom: e.target.value }); };
App.onMeisaiTo = function (e) { App.setState({ meisaiTo: e.target.value }); };
App.meisaiClear = function () { App.setState({ meisaiType: 'all', meisaiFrom: '', meisaiTo: '' }); };
App.toggleMeisaiPick = function () { App.setState(function (s) { return { meisaiPickOpen: !s.meisaiPickOpen }; }); };
App.pickMeisaiAcct = function (no) { return function () { App.loadMeisai(no); App.setState({ meisaiAcct: no, meisaiPickOpen: false, meisaiType: 'all', meisaiFrom: '', meisaiTo: '' }); }; };

/* ============================================================
   Additional account opening (settings)
   ============================================================ */
App.naStart = function () { App.setState(function (s) { return { page: 'newacct', pageStack: s.pageStack.concat([s.page]), showUserSettings: false, naStep: 1, naType: '普通', naStore: '001', naPw: '', naErr: null, naResult: null, naSaveTerm: '6', naSaveMonthly: '30000' }; }); };
App.onNaType = function (e) { App.setState({ naType: e.target.value }); };
App.onNaStore = function (e) { App.setState({ naStore: e.target.value }); };
App.onNaPw = function (e) { App.setState({ naPw: e.target.value }); };
App.onNaTerm = function (e) { App.setState({ naSaveTerm: e.target.value }); };
App.onNaMonthly = function (e) { App.setState({ naSaveMonthly: e.target.value }); };
App.naConfirm = function () { var T = App.T(); if (!App.state.naPw) return App.setState({ naErr: T.su_err_req }); App.setState({ naErr: null, naStep: 2 }); };
App.naBack = function () { App.setState({ naStep: 1, naErr: null }); };
App.naExecute = function () {
  var s = App.state, me = App.me(), store = STORES.find(function (x) { return x.code === s.naStore; }) || STORES[0];
  // 追加口座も同じ SIGNUP.cbl で DB 開設(名義は本人を踏襲)。
  var body = 'kanji=' + encodeURIComponent(me.kanji || '') + '&kana=' + encodeURIComponent(me.kana || '') +
    '&type=' + encodeURIComponent(s.naType) + '&branch=' + encodeURIComponent(store.code) + '&pw=' + encodeURIComponent(s.naPw);
  fetch('/api/signup', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: body })
    .then(function (r) { return r.json(); })
    .then(function (d) {
      if (!d || !d.ok || !d.kouza) return App.setState({ naErr: App.T().su_err_req });
      var no = String(d.kouza);
      var acc = { no: no, kanji: me.kanji, kana: me.kana, type: s.naType, balance: 0, status: '正常', branch: store.name, bcode: store.code, pw: s.naPw, prof: me.prof };
      App.setState({ accounts: App.state.accounts.concat([acc]), ownNos: App.state.ownNos.concat([no]), naResult: { tenban: store.code, store: store.name, no: no, type: s.naType }, naStep: 3 });
    })
    .catch(function () { App.setState({ naErr: App.T().su_err_req }); });
};
App.naToHome = function () { App.setState({ page: 'home', pageStack: [] }); };

/* ============================================================
   Small view helpers
   ============================================================ */
function stepIndicator(cur, labels) {
  return '<div class="step-row">' + labels.map(function (label, i) {
    var n = i + 1, cls = 'step-item' + (n < cur ? ' is-done' : '') + (n === cur ? ' is-active' : '');
    return '<div class="' + cls + '"><span class="step-num">' + n + '</span>' + esc(label) + '</div>';
  }).join('') + '</div>';
}
function typeDisp(type) { return App.T().typeMap[type] || type; }
function breakdownRow(label, val) {
  return '<div class="row" style="justify-content:space-between;padding:8px 13px;font-size:12.5px;border-bottom:1px solid #f2f4f8"><span style="color:#5f7285">' + esc(label) + '</span><span style="font-family:\'IBM Plex Mono\',monospace">' + val + '</span></div>';
}
function buildResvOptions(T) {
  var wd = ['日', '月', '火', '水', '木', '金', '土'];
  var opts = [{ value: 'today', label: T.tr_resv_today }];
  for (var i = 1; i <= 14; i++) { var d = new Date(); d.setDate(d.getDate() + i); opts.push({ value: 'd' + i, label: (d.getMonth() + 1) + '月' + d.getDate() + '日（' + wd[d.getDay()] + '）' }); }
  return opts;
}
function tile(handler, svg, label) {
  return '<button class="tile" data-click="' + onClick(handler) + '">' + svg + '<span class="tile-label">' + esc(label) + '</span></button>';
}
function iconMeisai() { return '<svg width="38" height="38" viewBox="0 0 24 24" fill="none" stroke="#1a1a1a" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M16 13H8"/><path d="M16 17H8"/><path d="M10 9H8"/></svg>'; }
function iconSoukin() { return '<svg width="38" height="38" viewBox="0 0 24 24" fill="none" stroke="#1a1a1a" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M8 3 4 7l4 4"/><path d="M4 7h16"/><path d="m16 21 4-4-4-4"/><path d="M20 17H4"/></svg>'; }
function iconLoan() { return '<svg width="38" height="38" viewBox="0 0 24 24" fill="none" stroke="#1a1a1a" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><line x1="3" x2="21" y1="22" y2="22"/><line x1="6" x2="6" y1="18" y2="11"/><line x1="10" x2="10" y1="18" y2="11"/><line x1="14" x2="14" y1="18" y2="11"/><line x1="18" x2="18" y1="18" y2="11"/><polygon points="12 2 20 7 4 7"/></svg>'; }
function loanEmptyIcon() { return '<svg width="46" height="46" viewBox="0 0 24 24" fill="none" stroke="#c3ccdb" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><line x1="3" x2="21" y1="22" y2="22"/><line x1="6" x2="6" y1="18" y2="11"/><line x1="10" x2="10" y1="18" y2="11"/><line x1="14" x2="14" y1="18" y2="11"/><line x1="18" x2="18" y1="18" y2="11"/><polygon points="12 2 20 7 4 7"/></svg>'; }
function bellSvg() { return '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#1a1a1a" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.268 21a2 2 0 0 0 3.464 0"/><path d="M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326"/></svg>'; }
function trashSvg() { return '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><line x1="10" x2="10" y1="11" y2="17"/><line x1="14" x2="14" y1="11" y2="17"/></svg>'; }

/* ============================================================
   Auth templates (login / signup)
   ============================================================ */
function tplLogin() {
  var T = App.T(), s = App.state;
  return '<div class="flex-center"><div style="width:100%;max-width:400px;display:flex;flex-direction:column;gap:20px">' +
    '<div style="display:flex;flex-direction:column;align-items:center;gap:12px"><div class="logo-mark" style="width:54px;height:54px;border-radius:15px;font-size:20px">KS</div></div>' +
    '<div class="card-box">' +
    '<div style="font-size:16px;font-weight:900">' + esc(T.login_title) + '</div>' +
    (s.loginErr ? '<div class="err-box">⚠ ' + esc(s.loginErr) + '</div>' : '') +
    '<div class="row" style="gap:10px;align-items:flex-end">' +
    '<div style="width:104px"><label class="f-label" style="display:block;margin-bottom:4px">' + esc(T.login_branch) + '（' + esc(T.digits3) + '）</label>' +
    '<input value="' + esc(s.loginBranch) + '" data-onchange="' + onChange(App.onLoginBranch) + '" inputmode="numeric" maxlength="3" placeholder="001" style="width:100%;padding:11px 12px;border:1px solid #d3dbe8;border-radius:9px;font-size:15px;font-family:\'IBM Plex Mono\',monospace;text-align:center;letter-spacing:.15em"></div>' +
    '<div style="flex:1"><label class="f-label" style="display:block;margin-bottom:4px">' + esc(T.login_acct) + '（' + esc(T.digits7) + '）</label>' +
    '<input value="' + esc(s.loginAcct) + '" data-onchange="' + onChange(App.onLoginAcct) + '" inputmode="numeric" maxlength="7" placeholder="1234567" style="width:100%;padding:11px 12px;border:1px solid #d3dbe8;border-radius:9px;font-size:15px;font-family:\'IBM Plex Mono\',monospace;letter-spacing:.12em"></div>' +
    '</div>' +
    '<input type="password" value="' + esc(s.loginPw) + '" data-onchange="' + onChange(App.onLoginPw) + '" placeholder="' + esc(T.login_pw) + '" class="inp-full">' +
    '<div class="row" style="gap:10px">' +
    '<button data-click="' + onClick(App.doLogin) + '" class="btn-primary" style="flex:1">' + esc(T.login_btn) + '</button>' +
    '<button data-click="' + onClick(App.goSignup) + '" style="flex:1;background:#fff;color:#a06e00;border:1px solid #ffcc00;padding:13px;border-radius:11px;font-size:14px;font-weight:800;cursor:pointer">' + esc(T.login_signup) + '</button>' +
    '</div>' +
    '<div class="hint-box">' + esc(T.login_hint) + '</div>' +
    '</div>' +
    '<div style="font-size:10.5px;color:#b0bacb;text-align:center;line-height:1.7">' + esc(T.login_note) + '</div>' +
    '<div class="row" style="gap:18px;justify-content:center;font-size:11.5px"><a href="#" style="color:#a06e00;text-decoration:none;font-weight:600">' + esc(T.ft_sec1) + '</a><a href="#" style="color:#a06e00;text-decoration:none;font-weight:600">' + esc(T.ft_sec2) + '</a></div>' +
    '</div></div>';
}

function fld(label, inputHtml) { return '<label class="f-label">' + esc(label) + '</label>' + inputHtml; }
function typeOptionsHtml(T, includeSave) {
  var h = '<option value="普通">' + esc(T.acct_futsu) + '</option><option value="当座">' + esc(T.acct_toza) + '</option>';
  if (includeSave) h += '<option value="積立">' + esc(T.typeMap['積立']) + '</option><option value="定期">' + esc(T.typeMap['定期']) + '</option>';
  return h;
}
function projectionBox(T, proj, extraLabel) {
  return '<div style="background:#fffbe9;border:1px solid #f0d98a;border-radius:12px;padding:14px 16px;display:flex;flex-direction:column;gap:8px' + (extraLabel === undefined ? ';grid-column:1/-1;margin-top:14px' : '') + '">' +
    '<div style="font-size:12px;font-weight:800">' + esc(T.na_proj) + (extraLabel ? extraLabel : '') + '</div>' +
    '<div class="row" style="gap:24px;flex-wrap:wrap">' +
    '<div><div style="font-size:11px;color:#6b7a90">' + esc(T.na_principal) + '</div><div style="font-size:18px;font-weight:900;font-family:\'IBM Plex Mono\',monospace">' + App._f(proj.principal) + '</div></div>' +
    '<div><div style="font-size:11px;color:#6b7a90">' + esc(T.na_interest) + '</div><div style="font-size:18px;font-weight:900;color:#1f7a4d;font-family:\'IBM Plex Mono\',monospace">' + App._f(proj.interest) + '</div></div>' +
    '<div><div style="font-size:11px;color:#6b7a90">' + esc(T.na_maturity) + '</div><div style="font-size:18px;font-weight:900;color:#a06e00;font-family:\'IBM Plex Mono\',monospace">' + App._f(proj.maturity) + '</div></div>' +
    '</div></div>';
}

function tplSuStep1() {
  var T = App.T(), s = App.state;
  var isSave = s.suType === '積立' || s.suType === '定期';
  var amtLabel = s.suType === '積立' ? T.na_monthly : T.na_deposit;
  var m = parseInt((s.suSaveMonthly || '').replace(/[^0-9]/g, ''), 10) || 0;
  var n = parseInt(s.suSaveTerm, 10) || 0;
  var proj = App._saveProject(s.suType, m, n);
  var rateDisp = App.rateOf(s.suType) + ' %';
  var grid = '<div style="display:grid;grid-template-columns:150px 1fr;gap:13px 16px;align-items:center">' +
    fld(T.su_name, '<input value="' + esc(s.suName) + '" data-onchange="' + onChange(App.suChg('suName')) + '" placeholder="山田 太郎" class="inp-full">') +
    fld(T.su_kana, '<input value="' + esc(s.suKana) + '" data-onchange="' + onChange(App.suChg('suKana')) + '" placeholder="ヤマダ タロウ" class="inp-full">') +
    fld(T.su_birth, '<input type="date" value="' + esc(s.suBirth) + '" data-onchange="' + onChange(App.suChg('suBirth')) + '" class="inp-full">') +
    fld(T.su_sex, '<select data-value="' + esc(s.suSex) + '" data-onchange="' + onChange(App.suChg('suSex')) + '" style="padding:10px 13px;border:1px solid #d3dbe8;border-radius:9px;font-size:14px;width:100%;max-width:200px"><option value="男性">' + esc(T.su_sex_m) + '</option><option value="女性">' + esc(T.su_sex_f) + '</option><option value="その他">' + esc(T.su_sex_o) + '</option></select>') +
    fld(T.su_zip, '<input value="' + esc(s.suZip) + '" data-onchange="' + onChange(App.suZipChg) + '" inputmode="numeric" maxlength="7" placeholder="1000001" style="padding:10px 13px;border:1px solid #d3dbe8;border-radius:9px;font-size:14px;width:100%;max-width:180px;font-family:\'IBM Plex Mono\',monospace">') +
    fld(T.su_addr, '<input value="' + esc(s.suAddr) + '" data-onchange="' + onChange(App.suChg('suAddr')) + '" placeholder="東京都千代田区…" class="inp-full">') +
    fld(T.su_phone, '<input value="' + esc(s.suPhone) + '" data-onchange="' + onChange(App.suPhoneChg) + '" inputmode="numeric" placeholder="090-1234-5678" style="padding:10px 13px;border:1px solid #d3dbe8;border-radius:9px;font-size:14px;width:100%;max-width:220px;font-family:\'IBM Plex Mono\',monospace">') +
    fld(T.su_email, '<input value="' + esc(s.suEmail) + '" data-onchange="' + onChange(App.suChg('suEmail')) + '" placeholder="taro@example.jp" class="inp-full">') +
    fld(T.su_job, '<input value="' + esc(s.suJob) + '" data-onchange="' + onChange(App.suChg('suJob')) + '" placeholder="会社員" class="inp-full">') +
    fld(T.su_type, '<select data-value="' + esc(s.suType) + '" data-onchange="' + onChange(App.suChg('suType')) + '" style="padding:10px 13px;border:1px solid #d3dbe8;border-radius:9px;font-size:14px;width:100%;max-width:200px">' + typeOptionsHtml(T, true) + '</select>') +
    fld(T.su_store, '<select data-value="' + esc(s.suStore) + '" data-onchange="' + onChange(App.suChg('suStore')) + '" style="padding:10px 13px;border:1px solid #d3dbe8;border-radius:9px;font-size:14px;width:100%;max-width:260px">' + STORES.map(function (o) { return '<option value="' + o.code + '">' + o.code + ' ' + esc(o.name) + '</option>'; }).join('') + '</select>') +
    (isSave ? (
      fld(T.na_term, '<select data-value="' + s.suSaveTerm + '" data-onchange="' + onChange(App.suChg('suSaveTerm')) + '" style="padding:10px 13px;border:1px solid #d3dbe8;border-radius:9px;font-size:14px;width:100%;max-width:160px"><option value="3">3 ' + esc(T.na_months) + '</option><option value="6">6 ' + esc(T.na_months) + '</option><option value="12">12 ' + esc(T.na_months) + '</option></select>') +
      fld(amtLabel, '<div class="row" style="gap:8px"><input value="' + esc(s.suSaveMonthly) + '" data-onchange="' + onChange(App.suChg('suSaveMonthly')) + '" inputmode="numeric" class="inp"><span style="font-size:13px;color:#6b7a90">' + esc(T.yen) + '</span></div>')
    ) : '') +
    fld(T.su_pw, '<input type="password" value="' + esc(s.suPw) + '" data-onchange="' + onChange(App.suChg('suPw')) + '" class="inp-full">') +
    fld(T.su_pw2, '<input type="password" value="' + esc(s.suPw2) + '" data-onchange="' + onChange(App.suChg('suPw2')) + '" class="inp-full">') +
    '</div>';
  var projBox = isSave ? projectionBox(T, proj, '（' + esc(T.hold_rate) + ' ' + rateDisp + '）') : '';
  var agreeBox = '<div style="border-top:1px solid #eef2f6;padding-top:14px;display:flex;flex-direction:column;gap:8px">' +
    '<div data-click="' + onClick(App.suAgreeToggle) + '" class="row" style="gap:10px;cursor:pointer"><span class="checkbox-box' + (s.suAgree ? ' is-on' : '') + '">✓</span><span style="font-size:13px;font-weight:700">' + esc(T.su_agree) + '</span></div>' +
    '<div style="font-size:11px;color:#8a97b0;line-height:1.6">' + esc(T.su_terms) + '</div>' +
    '</div>';
  return '<div class="card-box">' + grid + projBox + agreeBox +
    '<div class="row" style="gap:10px"><button class="btn-back" data-click="' + onClick(App.goLoginPage) + '">' + esc(T.backBtn) + '</button><button class="btn-primary" data-click="' + onClick(App.suConfirm) + '">' + esc(T.su_next) + '</button></div>' +
    '</div>';
}
function tplSuStep2() {
  var T = App.T(), s = App.state;
  var storeName = (STORES.find(function (x) { return x.code === s.suStore; }) || STORES[0]).name;
  var rows = [
    [T.su_name, s.suName], [T.su_kana, s.suKana], [T.su_birth, s.suBirth], [T.su_sex, s.suSex],
    [T.su_zip, s.suZip], [T.su_addr, s.suAddr], [T.su_phone, s.suPhone], [T.su_email, s.suEmail],
    [T.su_job, s.suJob], [T.su_type, typeDisp(s.suType)]
  ].map(function (p) { return '<div class="amt-label">' + esc(p[0]) + '</div><div class="amt-cell">' + esc(p[1]) + '</div>'; }).join('');
  rows += '<div class="amt-label-strong">' + esc(T.su_store) + '</div><div class="amt-cell-strong">' + esc(s.suStore) + ' ' + esc(storeName) + '</div>';
  return '<div class="card-box">' +
    '<div style="font-size:13px;color:#4a5a6a">' + esc(T.confirmLead) + '</div>' +
    '<div class="tbl-box"><div class="rowgrid">' + rows + '</div></div>' +
    '<div class="row" style="gap:10px"><button class="btn-back" data-click="' + onClick(App.suBack) + '">' + esc(T.backBtn) + '</button><button class="btn-exec" data-click="' + onClick(App.suExecute) + '">' + esc(T.su_submit) + '</button></div>' +
    '</div>';
}
function tplSuStep3() {
  var T = App.T(), r = App.state.suResult;
  return '<div class="done-box">' +
    '<div class="done-icon">✓</div>' +
    '<div style="font-size:17px;font-weight:900;color:#a06e00">' + esc(T.su_done) + '</div>' +
    '<div style="font-size:12.5px;color:#6b7a90;max-width:420px;line-height:1.7">' + esc(T.su_done_msg) + '</div>' +
    '<div style="border:1px solid #eef1f6;border-radius:12px;overflow:hidden;width:100%;max-width:440px"><div class="rowgrid">' +
    '<div class="amt-label">' + esc(T.su_result_store) + '</div><div class="amt-cell-bold">' + esc(r ? (r.tenban + ' ' + r.store) : '') + '</div>' +
    '<div class="amt-label-strong">' + esc(T.su_result_no) + '</div><div class="amt-cell-strong">' + esc(r ? r.no : '') + '</div>' +
    '<div class="amt-label">' + esc(T.su_result_type) + '</div><div class="amt-cell">' + esc(r ? typeDisp(r.type) : '') + '</div>' +
    '</div></div>' +
    '<button class="btn-primary" data-click="' + onClick(App.suToLogin) + '">' + esc(T.su_toLogin) + '</button>' +
    '</div>';
}
function tplSignup() {
  var T = App.T(), s = App.state;
  var steps = stepIndicator(s.suStep, [T.su_step1, T.su_step2, T.su_step3]);
  var body = s.suStep === 1 ? tplSuStep1() : s.suStep === 2 ? tplSuStep2() : tplSuStep3();
  return '<div class="flex-center"><div style="width:100%;max-width:640px;display:flex;flex-direction:column;gap:18px">' +
    '<div class="row" style="gap:12px"><div class="logo-mark" style="width:44px;height:44px;border-radius:12px;font-size:16px">KS</div><div><div style="font-size:18px;font-weight:900">' + esc(T.su_title) + '</div><div style="font-size:11px;color:#8a97b0">' + esc(T.bankName) + '</div></div></div>' +
    steps +
    (s.suErr ? '<div class="err-box">⚠ ' + esc(s.suErr) + '</div>' : '') +
    body +
    '</div></div>';
}
function tplAuth() { return App.state.authPage === 'login' ? tplLogin() : tplSignup(); }

/* ============================================================
   Header + settings popover
   ============================================================ */
function tplHeader() {
  var T = App.T(), s = App.state, me = App.me();
  var popover = '';
  if (s.showUserSettings) {
    popover = '<div class="popover-backdrop" data-click="' + onClick(App.onToggleUserSettings) + '"></div>' +
      '<div class="popover">' +
      '<div class="row" style="justify-content:space-between;align-items:center;margin-bottom:13px"><span style="font-size:13px;font-weight:800">' + esc(T.us_title) + '</span><button data-click="' + onClick(App.onToggleUserSettings) + '" style="background:none;border:none;cursor:pointer;font-size:16px;color:#8a97a6;padding:2px 4px">×</button></div>' +
      '<button class="popover-item" data-click="' + onClick(App.goMember) + '"><span>' + esc(T.us_member) + '</span><span style="color:#c3a24a;font-size:16px">›</span></button>' +
      '<button class="popover-item" data-click="' + onClick(App.goHoldings) + '"><span>' + esc(T.us_holdings) + '</span><span style="color:#c3a24a;font-size:16px">›</span></button>' +
      '<button class="popover-item" data-click="' + onClick(App.naStart) + '" style="margin-bottom:14px"><span>' + esc(T.us_newacct) + '</span><span style="color:#c3a24a;font-size:16px">›</span></button>' +
      '<div style="font-size:11px;color:#6a7787;font-weight:700;margin-bottom:6px">' + esc(T.us_lang) + '</div>' +
      '<select class="inp-full" data-value="' + s.lang + '" data-onchange="' + onChange(App.onLangSelect) + '"><option value="ja">日本語</option><option value="ko">한국어</option></select>' +
      '</div>';
  }
  return '<header class="app-header"><div class="app-header-inner">' +
    '<div class="row" style="gap:12px;cursor:pointer" data-click="' + onClick(App.goHome) + '">' +
    '<div class="logo-mark">KS</div>' +
    '<div><div style="font-size:17px;font-weight:900">' + esc(T.bankName) + '</div><div style="font-size:10.5px;color:#8a97b0">' + esc(T.bankSub) + '</div></div>' +
    '</div>' +
    '<div class="row" style="gap:16px;flex-wrap:wrap">' +
    '<div style="text-align:right"><div style="font-size:13.5px;font-weight:700">' + esc(me.kanji) + ' ' + esc(T.sama) + '</div><div style="font-size:10.5px;color:#8a97b0">' + esc(T.lastLogin) + '：2026/07/02 09:14</div></div>' +
    '<div style="position:relative"><button class="gear-btn' + (s.showUserSettings ? ' is-open' : '') + '" data-click="' + onClick(App.onToggleUserSettings) + '">⚙</button>' + popover + '</div>' +
    '<button data-click="' + onClick(App.doLogout) + '" style="background:#fff;border:1px solid #cfd8ea;color:#a06e00;padding:8px 15px;border-radius:9px;font-size:12.5px;font-weight:700;cursor:pointer">' + esc(T.logout) + '</button>' +
    '</div>' +
    '</div></header>';
}

/* ============================================================
   Home
   ============================================================ */
function tplHomeCard() {
  var T = App.T(), s = App.state;
  var no = s.ownNos.indexOf(s.homeView) < 0 ? s.ownNos[0] : s.homeView;
  var a = App._find(no) || {};
  var isRep = no === s.repAcct;
  var balDisp = s.balHidden ? '¥ ******' : App._f(a.balance);
  var carMulti = s.ownNos.length > 1;
  var carPos = ((s.ownNos.indexOf(s.homeView) < 0 ? 0 : s.ownNos.indexOf(s.homeView)) + 1) + ' / ' + s.ownNos.length;
  return '<div class="row" style="align-items:stretch;gap:10px">' +
    (carMulti ? '<button class="car-arrow" data-click="' + onClick(App.homeCar(-1)) + '">‹</button>' : '') +
    '<div class="acct-card">' +
    '<div class="row" style="justify-content:space-between;gap:12px;flex-wrap:wrap;margin-bottom:20px">' +
    '<div class="row" style="gap:10px;flex-wrap:wrap">' +
    '<span class="star' + (isRep ? ' is-rep' : '') + '" data-click="' + onClick(App.setRep(no)) + '" title="' + esc(T.set_rep) + '">★</span>' +
    '<span class="pill">' + esc(typeDisp(a.type)) + '</span>' +
    (isRep ? '<span class="pill-outline">' + esc(T.rep_label) + '</span>' : '') +
    '<span style="font-size:12.5px;color:#6b7a90">' + esc(a.branch) + '（' + esc(a.bcode) + '）</span>' +
    '<span style="font-size:12.5px;color:#6b7a90;font-family:\'IBM Plex Mono\',monospace">' + esc(a.no) + '</span>' +
    '</div>' +
    '<button data-click="' + onClick(App.onToggleBal) + '" style="background:#f5f7fa;border:1px solid #e2e7f0;color:#5b6b85;font-size:11.5px;padding:5px 13px;border-radius:8px;cursor:pointer;font-weight:700">' + esc(s.balHidden ? T.showBal : T.hideBal) + '</button>' +
    '</div>' +
    '<div style="font-size:12px;color:#8a97b0;margin-bottom:4px">' + esc(T.balanceLabel) + '</div>' +
    '<div style="font-size:42px;font-weight:900;font-family:\'IBM Plex Mono\',monospace;letter-spacing:-1px">' + balDisp + '</div>' +
    (carMulti ? '<div style="margin-top:16px;text-align:center;font-size:11.5px;color:#a6b0c0;font-family:\'IBM Plex Mono\',monospace">' + carPos + '</div>' : '') +
    '</div>' +
    (carMulti ? '<button class="car-arrow" data-click="' + onClick(App.homeCar(1)) + '">›</button>' : '') +
    '</div>';
}
function tplHomeTiles() {
  var T = App.T();
  return '<div class="tile-grid">' +
    tile(App.goMeisai, iconMeisai(), T.ic_meisai) +
    tile(App.goSoukin, iconSoukin(), T.ic_soukin) +
    tile(App.goLoan, iconLoan(), T.ic_loan) +
    '</div>';
}
function tplNotices() {
  var T = App.T(), s = App.state;
  var base = s.dbNotices.map(function (n, i) { return { date: n.date, tag: n.tag, title: n.title, files: [], body: '', _kind: 'base', _idx: i }; }).filter(function (n) { return s.hiddenBase.indexOf(n._idx) === -1; });
  var extra = s.extraNotices.map(function (n, i) { return { date: n.date, tag: n.tag, title: n.title, files: n.files || [], body: n.body || '', _kind: 'extra', _idx: i }; });
  var all = extra.concat(base);
  var itemsHtml = all.map(function (n) {
    var openId = onClick(function () { App.openNotice(n); });
    var delId = onClick(function (e) { if (e && e.stopPropagation) e.stopPropagation(); App.deleteNotice(n._kind, n._idx); });
    var filesHtml = (n.files && n.files.length) ? '<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:2px">' + n.files.map(function (f) { return '<span class="file-chip">📎 ' + esc(f) + '</span>'; }).join('') + '</div>' : '';
    return '<div class="notice-item" data-click="' + openId + '">' +
      '<div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:4px">' +
      '<div class="row" style="gap:8px"><span style="font-size:10.5px;color:#9aa6bb;font-family:\'IBM Plex Mono\',monospace">' + esc(n.date) + '</span><span class="notice-tag">' + esc(n.tag) + '</span></div>' +
      '<div style="font-size:12.5px;color:#3a4a66;line-height:1.5;font-weight:600">' + esc(n.title) + '</div>' +
      filesHtml +
      '</div>' +
      '<button data-click="' + delId + '" title="delete" style="background:none;border:none;cursor:pointer;padding:4px;flex:none;color:#c0392b;display:flex;align-items:center">' + trashSvg() + '</button>' +
      '<span class="chev">›</span>' +
      '</div>';
  }).join('');
  return '<div class="plain-card" style="padding:0;overflow:hidden">' +
    '<div style="padding:14px 20px;font-size:13px;font-weight:800;display:flex;align-items:center;justify-content:space-between;gap:8px;border-bottom:1px solid #eef1f6">' +
    '<span class="row" style="gap:8px">' + bellSvg() + esc(T.oshirase) + '</span>' +
    '<button data-click="' + onClick(App.goNoticeNew) + '" title="' + esc(T.nc_title) + '" style="width:28px;height:28px;border-radius:8px;background:#ffcc00;border:none;font-size:18px;line-height:1;cursor:pointer">+</button>' +
    '</div>' + itemsHtml +
    '</div>';
}
function tplHome() { return tplHomeCard() + tplHomeTiles() + tplNotices(); }


/* ============================================================
   Transfer (振込)
   ============================================================ */
function tplTrBank() {
  var T = App.T(), s = App.state;
  var q = s.trBankQuery || '';
  var list = BANKS.filter(function (n) { return n.indexOf(q) !== -1; });
  var tiles = list.map(function (name) {
    var mt = BANK_META[name] || { c: '#fff3c4', t: '#1a1a1a', m: '?' };
    var fontSize = mt.m.length > 2 ? '11px' : '13px';
    return '<button class="bank-tile" data-click="' + onClick(function () { App.trPickBank(name); }) + '">' +
      '<span class="bank-mark" style="background:' + mt.c + ';color:' + mt.t + ';font-size:' + fontSize + '">' + esc(mt.m) + '</span>' +
      '<span style="font-size:12.5px;font-weight:700;text-align:center;line-height:1.3">' + esc(name) + '</span>' +
      '</button>';
  }).join('');
  return '<div class="card-box">' +
    '<div style="font-size:14px;font-weight:800">' + esc(T.tr_selBank) + '</div>' +
    '<input value="' + esc(q) + '" data-onchange="' + onChange(App.onTrBankQuery) + '" placeholder="' + esc(T.tr_searchBank) + '" class="inp-full">' +
    '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:10px">' + tiles + '</div>' +
    (list.length === 0 ? '<div style="font-size:12.5px;color:#8a97b0;text-align:center;padding:12px">' + esc(T.tr_noResult) + '</div>' : '') +
    '</div>';
}
function tplTrBranch() {
  var T = App.T(), s = App.state;
  var q = s.trBranchQuery || '';
  var list = BRANCHES2.filter(function (b) { return b.code.indexOf(q) !== -1 || b.name.indexOf(q) !== -1; });
  var rows = list.map(function (b) {
    return '<button class="branch-row" data-click="' + onClick(function () { App.trPickBranch(b); }) + '">' +
      '<span style="font-family:\'IBM Plex Mono\',monospace;font-weight:700;color:#a06e00;min-width:44px">' + b.code + '</span>' +
      '<span style="font-size:13px">' + esc(b.name) + '</span><span style="margin-left:auto;color:#c3ccdb;font-size:18px">›</span>' +
      '</button>';
  }).join('');
  return '<div class="card-box">' +
    '<div class="row" style="gap:8px;flex-wrap:wrap"><span style="font-size:12px;color:#6b7a90">' + esc(T.toLabel) + '</span><span class="pill">' + esc(s.trBank) + '</span></div>' +
    '<div style="font-size:14px;font-weight:800">' + esc(T.tr_selBranch) + '</div>' +
    '<input value="' + esc(q) + '" data-onchange="' + onChange(App.onTrBranchQuery) + '" placeholder="' + esc(T.tr_searchBranch) + '" class="inp-full">' +
    '<div style="border:1px solid #eef1f6;border-radius:10px;overflow:hidden">' + rows + '</div>' +
    (list.length === 0 ? '<div style="font-size:12.5px;color:#8a97b0;text-align:center;padding:12px">' + esc(T.tr_noResult) + '</div>' : '') +
    '<div class="row" style="gap:10px"><button class="btn-back" data-click="' + onClick(App.trStageBack) + '">' + esc(T.backBtn) + '</button></div>' +
    '</div>';
}
function tplTrAccount() {
  var T = App.T(), s = App.state, me = App.me();
  var trAmtN = App._amt(s.trAmt);
  var trOver = trAmtN > 0 && (trAmtN + TRANSFER_FEE > me.balance);
  var opts = buildResvOptions(T).map(function (o) { return '<option value="' + o.value + '">' + esc(o.label) + '</option>'; }).join('');
  return '<div class="card-box">' +
    '<div class="tbl-box"><div style="display:grid;grid-template-columns:110px 1fr;font-size:13px">' +
    '<div class="c-label">' + esc(T.toLabel) + '</div><div class="c-val">' + esc(s.trBank) + '</div>' +
    '<div class="c-label">' + esc(T.l_branch) + '</div><div class="c-val">' + esc(s.trBranch) + '（' + esc(s.trBcode) + '）</div>' +
    '</div></div>' +
    '<div class="row" style="justify-content:space-between;background:#fffbe9;border:1px solid #f0d98a;border-radius:10px;padding:11px 15px"><span style="font-size:12px;color:#8a6d00;font-weight:700">' + esc(T.fromLabel) + ' ' + esc(T.balanceLabel) + '</span><span style="font-size:17px;font-weight:900;font-family:\'IBM Plex Mono\',monospace">' + App._f(me.balance) + '</span></div>' +
    '<div style="display:grid;grid-template-columns:130px 1fr;gap:14px 16px;align-items:center;max-width:520px">' +
    '<label class="f-label">' + esc(T.l_accno) + '</label><input value="' + esc(s.trTo) + '" data-onchange="' + onChange(App.chg('trTo')) + '" inputmode="numeric" placeholder="0000000" style="padding:10px 13px;border:1px solid #d3dbe8;border-radius:9px;font-size:14px;width:100%;font-family:\'IBM Plex Mono\',monospace;max-width:220px">' +
    '<label class="f-label">' + esc(T.l_amount) + '</label><div class="row" style="gap:8px"><input value="' + esc(s.trAmt) + '" data-onchange="' + onChange(App.chg('trAmt')) + '" inputmode="numeric" placeholder="0" class="inp"><span style="font-size:13px;color:#6b7a90">' + esc(T.yen) + '</span></div>' +
    '<label class="f-label">' + esc(T.tr_resv) + '</label><select data-value="' + s.trResvDate + '" data-onchange="' + onChange(App.onTrResv) + '" style="padding:10px 13px;border:1px solid #d3dbe8;border-radius:9px;font-size:14px;width:100%;max-width:240px">' + opts + '</select>' +
    '</div>' +
    (trOver ? '<div style="color:#c0392b;font-size:12.5px;font-weight:700">⚠ ' + esc(T.tr_err_live) + '（' + esc(T.balanceLabel) + ' ' + App._f(me.balance) + ' ／ ' + esc(T.totalLabel) + ' ' + App._f(trAmtN + TRANSFER_FEE) + '）</div>' : '') +
    '<div class="note-txt">' + esc(T.note_fee) + '<br>' + esc(T.note_atomic) + '</div>' +
    '<div class="row" style="gap:10px"><button class="btn-back" data-click="' + onClick(App.trStageBack) + '">' + esc(T.backBtn) + '</button><button class="btn-primary" ' + (trOver ? 'disabled' : '') + ' data-click="' + onClick(App.trConfirm) + '">' + esc(T.confirmBtn) + '</button></div>' +
    '</div>';
}
function tplTrConfirm() {
  var T = App.T(), s = App.state, me = App.me();
  var toAcc = App._find((s.trTo || '').replace(/[^0-9]/g, '').padStart(7, '0'));
  var trAmtN = App._amt(s.trAmt);
  var resvLabel = (buildResvOptions(T).find(function (o) { return o.value === s.trResvDate; }) || { label: '' }).label;
  return '<div class="card-box">' +
    '<div style="font-size:13px;color:#4a5a6a">' + esc(T.confirmLead) + '</div>' +
    '<div class="tbl-box"><div style="display:grid;grid-template-columns:150px 1fr;font-size:13px">' +
    '<div class="c-label">' + esc(T.fromLabel) + '</div><div class="c-val">' + esc(typeDisp(me.type)) + ' ' + esc(me.branch) + ' ' + esc(me.no) + '</div>' +
    '<div class="c-label">' + esc(T.toLabel) + '</div><div class="c-val">' + esc(s.trBank) + ' ' + esc(s.trBranch) + '（' + esc(s.trBcode) + '）<br><span style="font-family:\'IBM Plex Mono\',monospace">' + esc(s.trTo) + '</span> <span style="color:#7a8a99">' + (toAcc ? esc(toAcc.kanji + ' ' + T.sama) : '') + '</span></div>' +
    '</div></div>' +
    '<div class="tbl-box"><div class="rowgrid">' +
    '<div class="amt-label">' + esc(T.l_amount) + '</div><div class="amt-cell">' + App._f(trAmtN) + '</div>' +
    '<div class="amt-label">' + esc(T.feeLabel) + '</div><div class="amt-cell">' + App._f(TRANSFER_FEE) + '</div>' +
    '<div class="amt-label">' + esc(T.tr_resv) + '</div><div class="amt-cell">' + esc(resvLabel) + '</div>' +
    '<div class="amt-label-strong">' + esc(T.totalLabel) + '</div><div class="amt-cell-strong">' + App._f(trAmtN + TRANSFER_FEE) + '</div>' +
    '</div></div>' +
    '<div class="note-txt">' + esc(T.note_fee) + '</div>' +
    '<div class="row" style="gap:10px"><button class="btn-back" data-click="' + onClick(App.trBack) + '">' + esc(T.backBtn) + '</button><button class="btn-exec" data-click="' + onClick(App.trExecute) + '">' + esc(T.executeBtn) + '</button></div>' +
    '</div>';
}
function tplTrDone() {
  var T = App.T(), s = App.state, r = s.trReceipt;
  var trAmtN = App._amt(s.trAmt);
  var resvLabel = (buildResvOptions(T).find(function (o) { return o.value === s.trResvDate; }) || { label: '' }).label;
  return '<div class="done-box">' +
    '<div class="done-icon">✓</div>' +
    '<div style="font-size:17px;font-weight:900;color:#a06e00">' + esc(T.doneMsgTr) + '</div>' +
    '<div style="border:1px solid #eef1f6;border-radius:12px;overflow:hidden;width:100%;max-width:480px"><div class="rowgrid">' +
    '<div class="amt-label">' + esc(T.receiptLabel) + '</div><div class="amt-cell-bold">' + esc(r ? r.no : '') + '</div>' +
    '<div class="amt-label">' + esc(T.dtLabel) + '</div><div class="amt-cell">' + esc(r ? r.dt : '') + '</div>' +
    '<div class="amt-label">' + esc(T.toLabel) + '</div><div class="amt-cell">' + esc(s.trBank) + ' ' + esc(s.trBranch) + '（' + esc(s.trBcode) + '） ' + esc(s.trTo) + '</div>' +
    '<div class="amt-label">' + esc(T.l_amount) + '</div><div class="amt-cell">' + App._f(trAmtN) + '</div>' +
    '<div class="amt-label">' + esc(T.feeLabel) + '</div><div class="amt-cell">' + App._f(TRANSFER_FEE) + '</div>' +
    '<div class="amt-label">' + esc(T.tr_resv) + '</div><div class="amt-cell">' + esc(resvLabel) + '</div>' +
    '<div class="amt-label-strong">' + esc(T.afterBal) + '</div><div class="amt-cell-strong">' + App._f(App.me().balance) + '</div>' +
    '</div></div>' +
    '<button class="btn-primary" data-click="' + onClick(App.goHome) + '">' + esc(T.toHome) + '</button>' +
    '</div>';
}
function tplTransfer() {
  var T = App.T(), s = App.state;
  var steps = stepIndicator(s.trStep, [T.trStep1, T.trStep2, T.trStep3]);
  var body;
  if (s.trStep === 1) body = (s.trStage === 'bank') ? tplTrBank() : (s.trStage === 'branch') ? tplTrBranch() : tplTrAccount();
  else if (s.trStep === 2) body = tplTrConfirm();
  else body = tplTrDone();
  return '<button class="back-link" data-click="' + onClick(App.trStageBack) + '">‹ ' + esc(T.backBtn) + '</button>' +
    '<div style="font-size:21px;font-weight:900">' + esc(T.fr_title) + '</div>' + steps +
    (s.trErr ? '<div class="err-box">⚠ ' + esc(s.trErr) + '</div>' : '') + body;
}

/* ============================================================
   Loan
   ============================================================ */
function tplLoanStatus() {
  var T = App.T(), s = App.state;
  if (s.loans.length === 0) {
    return '<div class="plain-card" style="display:flex;flex-direction:column;align-items:center;text-align:center;padding:40px 24px;gap:18px">' +
      loanEmptyIcon() +
      '<div style="font-size:14px;color:#6b7a90;font-weight:600">' + esc(T.loan_none) + '</div>' +
      '<button class="btn-primary" data-click="' + onClick(App.loanApply) + '">' + esc(T.loan_apply_btn) + '</button>' +
      '</div>';
  }
  var sum = s.loans.reduce(function (a, l) { return a + l.amt; }, 0);
  var remainPay = s.loans.reduce(function (a, l) { return a + l.bal; }, 0);
  var remainAvail = LOAN_AVAIL - remainPay;
  var listHtml = s.loans.map(function (l, i) {
    var methodName = l.method === 'C' ? T.loan_mC : (l.method === 'B' ? T.loan_mB : T.loan_mA);
    var label = (s.lang === 'ko' ? '대출계약 No.' : 'ローン契約 No.') + (i + 1);
    return '<div class="loan-row" data-click="' + onClick(App.loanOpenDetail(i)) + '">' +
      '<span class="pill">' + esc(label) + '</span>' +
      '<span style="font-size:12.5px;color:#8a97b0">' + esc(methodName) + '</span>' +
      '<span style="margin-left:auto;display:flex;gap:14px;align-items:baseline;font-size:12px;color:#6b7a90">' + esc(T.loan_remainPay) + '<b style="color:#1a1a1a;font-family:\'IBM Plex Mono\',monospace">' + App._f(l.bal) + '</b></span>' +
      '<span class="chev">›</span>' +
      '</div>';
  }).join('');
  return '<div class="gradient-card">' +
    '<div style="font-size:12.5px;color:rgba(0,0,0,.55)">' + esc(T.loan_totalBorrow) + '</div>' +
    '<div style="font-size:32px;font-weight:900;font-family:\'IBM Plex Mono\',monospace">' + App._f(sum) + '</div>' +
    '<div style="font-size:12px;color:rgba(0,0,0,.6);margin-top:2px">' + esc(T.loan_remainPay) + ' <b>' + App._f(remainPay) + '</b></div>' +
    '<div style="font-size:11.5px;color:rgba(0,0,0,.5);margin-top:8px">' + esc(T.loan_availLeft) + ' <b>' + App._f(remainAvail) + '</b></div>' +
    '</div>' + listHtml;
}
function tplLoanDetail() {
  var T = App.T(), s = App.state, l = s.loans[s.loanDetailIdx];
  if (!l) return '';
  var methodName = l.method === 'C' ? T.loan_mC : (l.method === 'B' ? T.loan_mB : T.loan_mA);
  var label = (s.lang === 'ko' ? '대출계약 No.' : 'ローン契約 No.') + (s.loanDetailIdx + 1);
  return '<div class="plain-card" style="display:flex;flex-direction:column;gap:14px">' +
    '<div class="row" style="gap:8px"><span class="pill">' + esc(label) + '</span><span style="font-size:12.5px;color:#8a97b0">' + esc(methodName) + '</span></div>' +
    '<div class="gradient-card">' +
    '<div style="font-size:12px;color:rgba(0,0,0,.55)">' + esc(T.loan_totalBorrow) + '</div>' +
    '<div style="font-size:28px;font-weight:900;font-family:\'IBM Plex Mono\',monospace">' + App._f(l.amt) + '</div>' +
    '<div style="font-size:12px;color:rgba(0,0,0,.6);margin-top:2px">' + esc(T.loan_remainPay) + ' <b>' + App._f(l.bal) + '</b></div>' +
    '</div>' +
    '<div class="tbl-box"><div class="rowgrid">' +
    '<div class="amt-label">' + esc(T.loan_rate) + '</div><div class="amt-cell">年 ' + (LOAN_RATE * 100) + '%</div>' +
    '<div class="amt-label">' + esc(T.loan_term) + '</div><div class="amt-cell">' + esc(l.years) + ' ' + esc(T.loan_years) + '</div>' +
    '<div class="amt-label">' + esc(T.loan_method) + '</div><div class="amt-cell">' + esc(methodName) + '</div>' +
    '<div class="amt-label-strong">' + esc(T.loan_bal) + '</div><div class="amt-cell-strong">' + App._f(l.bal) + '</div>' +
    '</div></div>' +
    '<div class="row" style="gap:10px"><button class="btn-back" data-click="' + onClick(App.loanCloseDetail) + '">' + esc(T.backBtn) + '</button><button class="btn-exec" data-click="' + onClick(App.loanRepayStart(s.loanDetailIdx)) + '">' + esc(T.loan_repay_btn) + '</button></div>' +
    '</div>';
}
function tplLoanRepayInput() {
  var T = App.T(), s = App.state, l = s.loans[s.repayIdx];
  if (!l) return '';
  var label = (s.lang === 'ko' ? '대출계약 No.' : 'ローン契約 No.') + (s.repayIdx + 1);
  var principal = App._amt(s.repayAmt);
  var interest = Math.round(l.bal * LOAN_RATE / 12);
  var total = principal + interest + REPAY_FEE;
  return '<div style="display:flex;flex-direction:column;gap:14px">' +
    '<div style="font-size:16px;font-weight:900">' + esc(T.repay_title) + ' <span class="pill-outline" style="margin-left:6px">' + esc(label) + '</span></div>' +
    (s.repayErr ? '<div class="err-box">⚠ ' + esc(s.repayErr) + '</div>' : '') +
    '<div class="plain-card" style="border-radius:16px;display:flex;flex-direction:column;gap:16px">' +
    '<div class="tbl-box"><div class="rowgrid">' +
    '<div style="padding:11px 14px;font-size:13px;font-weight:800">' + esc(T.repay_bal) + '</div><div style="padding:11px 14px;text-align:right;font-family:\'IBM Plex Mono\',monospace;font-weight:900;font-size:16px">' + App._f(l.bal) + '</div>' +
    '</div></div>' +
    '<div style="display:flex;flex-direction:column;gap:6px">' +
    '<label class="f-label">' + esc(T.repay_principal) + '</label>' +
    '<div class="row" style="gap:8px"><input value="' + esc(s.repayAmt) + '" data-onchange="' + onChange(App.onRepayAmt) + '" inputmode="numeric" placeholder="0" class="inp"><span style="font-size:13px;color:#6b7a90">' + esc(T.yen) + '</span><button data-click="' + onClick(App.loanRepayAll) + '" style="background:#fff;border:1px solid #f0d98a;color:#a06e00;font-size:11.5px;font-weight:800;padding:7px 12px;border-radius:8px;cursor:pointer">' + esc(T.repay_all) + '</button></div>' +
    '</div>' +
    '<div style="border:1px solid #eef1f6;border-radius:10px;overflow:hidden">' +
    breakdownRow(T.repay_principal, App._f(principal)) +
    breakdownRow(T.repay_interest, App._f(interest)) +
    breakdownRow(T.repay_fee, App._f(REPAY_FEE)) +
    '<div class="row" style="justify-content:space-between;padding:9px 13px;font-size:13px;background:#fff8db"><span style="font-weight:800">' + esc(T.repay_total) + '</span><span style="font-family:\'IBM Plex Mono\',monospace;font-weight:900">' + App._f(total) + '</span></div>' +
    '</div>' +
    '<div class="row" style="gap:10px"><button class="btn-back" data-click="' + onClick(App.loanRepayCancel) + '">' + esc(T.backBtn) + '</button><button class="btn-exec" data-click="' + onClick(App.loanRepayExecute) + '">' + esc(T.repay_exec) + '</button></div>' +
    '</div></div>';
}
function tplLoanRepayDone() {
  var T = App.T(), r = App.state.repayReceipt;
  return '<div class="done-box">' +
    '<div class="done-icon">✓</div>' +
    '<div style="font-size:17px;font-weight:900;color:#a06e00">' + esc(T.repay_done) + '</div>' +
    '<div style="border:1px solid #eef1f6;border-radius:12px;overflow:hidden;width:100%;max-width:440px"><div class="rowgrid">' +
    '<div class="amt-label">' + esc(T.receiptLabel) + '</div><div class="amt-cell-bold">' + esc(r.no) + '</div>' +
    '<div class="amt-label">' + esc(T.dtLabel) + '</div><div class="amt-cell">' + esc(r.dt) + '</div>' +
    '<div class="amt-label">' + esc(r.label) + '</div><div class="amt-cell">' + App._f(r.afterBal) + '</div>' +
    '<div class="amt-label">' + esc(T.repay_principal) + '</div><div class="amt-cell">' + App._f(r.principal) + '</div>' +
    '<div class="amt-label">' + esc(T.repay_interest) + '</div><div class="amt-cell">' + App._f(r.interest) + '</div>' +
    '<div class="amt-label">' + esc(T.repay_fee) + '</div><div class="amt-cell">' + App._f(r.fee) + '</div>' +
    '<div class="amt-label-strong">' + esc(T.repay_total) + '</div><div class="amt-cell-strong">' + App._f(r.total) + '</div>' +
    '</div></div>' +
    '<button class="btn-primary" data-click="' + onClick(App.loanRepayCancel) + '">' + esc(T.backBtn) + '</button>' +
    '</div>';
}
function tplLoanApply() {
  var T = App.T(), s = App.state;
  var remain = LOAN_AVAIL - s.loans.reduce(function (a, l) { return a + l.bal; }, 0);
  var lc = App.loanCalc();
  var sel = s.loanMethod === 'C' ? lc.C : (s.loanMethod === 'B' ? lc.B : lc.A);
  var methodName = s.loanMethod === 'C' ? T.loan_mC : (s.loanMethod === 'B' ? T.loan_mB : T.loan_mA);
  var methodCap = s.loanMethod === 'C' ? T.loan_capC : (s.loanMethod === 'B' ? T.loan_capB : T.loan_capA);
  var compareNote = sel.total > 0 ? T.loan_cmp3(App._f(lc.A.interest), App._f(lc.B.interest), App._f(lc.C.interest)) : '';
  var acctOpts = s.accounts.filter(function (a) { return a.status !== '凍結'; }).map(function (a) {
    return '<option value="' + a.no + '">' + esc(typeDisp(a.type) + ' ' + a.branch + '（' + a.bcode + '） ' + a.no) + '</option>';
  }).join('');
  function mTab(method, label, handler) { return '<button class="tab-btn' + (s.loanMethod === method ? ' is-on' : '') + '" data-click="' + onClick(handler) + '">' + esc(label) + '</button>'; }
  return '<div class="gradient-card row" style="justify-content:space-between;gap:14px;flex-wrap:wrap">' +
    '<div><div style="font-size:12.5px;color:rgba(0,0,0,.55)">' + esc(T.loan_availLeft) + '</div><div style="font-size:30px;font-weight:900;font-family:\'IBM Plex Mono\',monospace;margin-top:2px">' + App._f(remain) + '</div></div>' +
    '<div style="text-align:right"><div style="font-size:12px;color:rgba(0,0,0,.55)">' + esc(T.loan_rate) + '</div><div style="font-size:20px;font-weight:800">年 ' + (LOAN_RATE * 100) + '%</div></div>' +
    '</div>' +
    '<div class="card-box">' +
    '<div style="display:grid;grid-template-columns:130px 1fr;gap:14px 16px;align-items:center;max-width:520px">' +
    '<label class="f-label">' + esc(T.loan_amt) + '</label><div class="row" style="gap:8px"><input value="' + esc(s.loanAmt) + '" data-onchange="' + onChange(App.onLoanAmt) + '" inputmode="numeric" placeholder="1000000" class="inp"><span style="font-size:13px;color:#6b7a90">' + esc(T.yen) + '</span></div>' +
    '<label class="f-label">' + esc(T.loan_term) + '</label><select data-value="' + s.loanTermY + '" data-onchange="' + onChange(App.onLoanTerm) + '" style="padding:10px 13px;border:1px solid #d3dbe8;border-radius:9px;font-size:14px;width:100%;max-width:180px"><option value="1">1 ' + esc(T.loan_years) + '</option><option value="3">3 ' + esc(T.loan_years) + '</option><option value="5">5 ' + esc(T.loan_years) + '</option><option value="10">10 ' + esc(T.loan_years) + '</option><option value="15">15 ' + esc(T.loan_years) + '</option></select>' +
    '<label class="f-label">' + esc(T.loan_method) + '</label><div class="row" style="gap:8px;flex-wrap:wrap">' + mTab('A', T.loan_mA, App.setLoanA) + mTab('B', T.loan_mB, App.setLoanB) + mTab('C', T.loan_mC, App.setLoanC) + '</div>' +
    '<label class="f-label">' + esc(T.loan_acct) + '</label><select data-value="' + s.loanAcct + '" data-onchange="' + onChange(App.onLoanAcct) + '" style="padding:10px 13px;border:1px solid #d3dbe8;border-radius:9px;font-size:14px;width:100%;max-width:320px">' + acctOpts + '</select>' +
    '</div>' +
    '<div style="background:#fffbe9;border:1px solid #f0d98a;border-radius:12px;padding:16px 18px;display:flex;flex-direction:column;gap:14px">' +
    '<div style="font-size:12px;font-weight:800">' + esc(methodName) + ' · ' + esc(T.loan_sim) + '</div>' +
    '<div style="font-size:11px;color:#8a6d00">' + esc(methodCap) + '</div>' +
    '<div class="row" style="gap:26px;flex-wrap:wrap">' +
    '<div><div style="font-size:11.5px;color:#6b7a90">' + esc(T.loan_monthly) + '</div><div style="font-size:24px;font-weight:900;font-family:\'IBM Plex Mono\',monospace">' + App._f(sel.monthly) + '</div></div>' +
    '<div><div style="font-size:11.5px;color:#6b7a90">' + esc(T.loan_total) + '</div><div style="font-size:24px;font-weight:900;color:#a06e00;font-family:\'IBM Plex Mono\',monospace">' + App._f(sel.total) + '</div></div>' +
    '<div><div style="font-size:11.5px;color:#6b7a90">' + esc(T.loan_interest) + '</div><div style="font-size:24px;font-weight:900;color:#c0392b;font-family:\'IBM Plex Mono\',monospace">' + App._f(sel.interest) + '</div></div>' +
    '</div>' +
    (compareNote ? '<div style="font-size:11.5px;color:#8a6414;background:#fdf6e9;border:1px solid #e6c983;border-radius:8px;padding:9px 12px">' + esc(compareNote) + '</div>' : '') +
    '</div>' +
    '<div class="row" style="gap:10px"><button class="btn-back" data-click="' + onClick(App.loanStepBack) + '">' + esc(T.backBtn) + '</button><button class="btn-primary" data-click="' + onClick(App.loanConfirm) + '">' + esc(T.confirmBtn) + '</button></div>' +
    '</div>';
}
function tplLoanConfirm() {
  var T = App.T(), s = App.state;
  var lc = App.loanCalc();
  var sel = s.loanMethod === 'C' ? lc.C : (s.loanMethod === 'B' ? lc.B : lc.A);
  var methodName = s.loanMethod === 'C' ? T.loan_mC : (s.loanMethod === 'B' ? T.loan_mB : T.loan_mA);
  var loanAmtN = App._amt(s.loanAmt);
  return '<div class="card-box">' +
    '<div style="font-size:13px;color:#4a5a6a">' + esc(T.confirmLead) + '</div>' +
    '<div class="tbl-box"><div class="rowgrid">' +
    '<div class="amt-label">' + esc(T.loan_amt) + '</div><div class="amt-cell-bold">' + App._f(loanAmtN) + '</div>' +
    '<div class="amt-label">' + esc(T.loan_term) + '</div><div class="amt-cell">' + esc(s.loanTermY) + ' ' + esc(T.loan_years) + '</div>' +
    '<div class="amt-label">' + esc(T.loan_method) + '</div><div class="amt-cell">' + esc(methodName) + '</div>' +
    '<div class="amt-label">' + esc(T.loan_rate) + '</div><div class="amt-cell">年 ' + (LOAN_RATE * 100) + '%</div>' +
    '<div class="amt-label">' + esc(T.loan_monthly) + '</div><div class="amt-cell">' + App._f(sel.monthly) + '</div>' +
    '<div class="amt-label">' + esc(T.loan_interest) + '</div><div class="amt-cell">' + App._f(sel.interest) + '</div>' +
    '<div class="amt-label-strong">' + esc(T.loan_total) + '</div><div class="amt-cell-strong">' + App._f(sel.total) + '</div>' +
    '</div></div>' +
    '<div class="row" style="gap:10px"><button class="btn-back" data-click="' + onClick(App.loanStepBack) + '">' + esc(T.backBtn) + '</button><button class="btn-exec" data-click="' + onClick(App.loanExecute) + '">' + esc(T.loan_apply) + '</button></div>' +
    '</div>';
}
function tplLoanDone() {
  var T = App.T(), s = App.state, r = s.loanReceipt;
  var lc = App.loanCalc();
  var sel = s.loanMethod === 'C' ? lc.C : (s.loanMethod === 'B' ? lc.B : lc.A);
  var loanAmtN = App._amt(s.loanAmt);
  return '<div class="done-box">' +
    '<div class="done-icon">✓</div>' +
    '<div style="font-size:17px;font-weight:900;color:#a06e00">' + esc(T.loan_done) + '</div>' +
    '<div style="border:1px solid #eef1f6;border-radius:12px;overflow:hidden;width:100%;max-width:440px"><div class="rowgrid">' +
    '<div class="amt-label">' + esc(T.receiptLabel) + '</div><div class="amt-cell-bold">' + esc(r ? r.no : '') + '</div>' +
    '<div class="amt-label">' + esc(T.dtLabel) + '</div><div class="amt-cell">' + esc(r ? r.dt : '') + '</div>' +
    '<div class="amt-label">' + esc(T.loan_amt) + '</div><div class="amt-cell">' + App._f(loanAmtN) + '</div>' +
    '<div class="amt-label-strong">' + esc(T.loan_monthly) + '</div><div class="amt-cell-strong">' + App._f(sel.monthly) + '</div>' +
    '</div></div>' +
    '<button class="btn-primary" data-click="' + onClick(App.goHome) + '">' + esc(T.toHome) + '</button>' +
    '</div>';
}
function tplLoan() {
  var T = App.T(), s = App.state;
  var inStatusRoot = s.loanStep === 0 && s.repayIdx === null && !s.repayReceipt && s.loanDetailIdx === null;
  var titleBtn = (inStatusRoot && s.loans.length > 0) ? '<div style="margin-left:auto"><button class="btn-primary" data-click="' + onClick(App.loanApply) + '">' + esc(T.loan_apply_btn) + '</button></div>' : '';
  var steps = s.loanStep >= 1 ? stepIndicator(s.loanStep, [T.loan_step1, T.loan_step2, T.loan_step3]) : '';
  var body;
  if (s.loanStep === 0) {
    if (s.repayReceipt) body = tplLoanRepayDone();
    else if (s.repayIdx !== null) body = tplLoanRepayInput();
    else if (s.loanDetailIdx !== null) body = tplLoanDetail();
    else body = tplLoanStatus();
  } else if (s.loanStep === 1) body = tplLoanApply();
  else if (s.loanStep === 2) body = tplLoanConfirm();
  else body = tplLoanDone();
  return '<button class="back-link" data-click="' + onClick(App.goHome) + '">‹ ' + esc(T.toHome) + '</button>' +
    '<div class="row" style="gap:10px;flex-wrap:wrap"><div style="font-size:21px;font-weight:900">' + esc(T.loan_title) + '</div>' + titleBtn + '</div>' +
    steps +
    (s.loanErr ? '<div class="err-box">⚠ ' + esc(s.loanErr) + '</div>' : '') +
    body;
}

/* ============================================================
   Meisai (transaction history)
   ============================================================ */
function tplMeisai() {
  var T = App.T(), s = App.state;
  var mView = App._meisaiAcct();
  var raw = App._meisaiRaw();
  var tagOf = function (ty) {
    var map = { '入金': { c: '#1f7a4d', b: '#e6f6ec', br: '#b7e0c6' }, '出金': { c: '#c0392b', b: '#fdecec', br: '#f3c0c0' }, '振込': { c: '#a06e00', b: '#fff3c4', br: '#f0d98a' }, '手数料': { c: '#8a6d00', b: '#fff8db', br: '#f0d98a' }, '融資実行': { c: '#1a5fb4', b: '#e7f0fb', br: '#bcd5f0' }, '融資返済': { c: '#1a5fb4', b: '#e7f0fb', br: '#bcd5f0' } };
    return map[ty] || { c: '#5f7285', b: '#f5f7fa', br: '#e2e7f0' };
  };
  var rowsHtml = raw.rows.map(function (r) {
    var tg = tagOf(r[5]);
    var kind = T.txnMap[r[5]] || r[5];
    return '<div class="meisai-row">' +
      '<div style="font-family:\'IBM Plex Mono\',monospace;color:#8a97b0;white-space:nowrap">' + esc(r[0]) + '</div>' +
      '<div style="color:#20303f">' + esc(r[1]) + '</div>' +
      '<div style="text-align:center"><span class="kind-tag" style="color:' + tg.c + ';background:' + tg.b + ';border:1px solid ' + tg.br + '">' + esc(kind) + '</span></div>' +
      '<div style="text-align:right;font-family:\'IBM Plex Mono\',monospace;font-variant-numeric:tabular-nums;color:#c0392b">' + (r[2] === '' ? '—' : App._f(r[2])) + '</div>' +
      '<div style="text-align:right;font-family:\'IBM Plex Mono\',monospace;font-variant-numeric:tabular-nums;color:#1f7a4d">' + (r[3] === '' ? '—' : App._f(r[3])) + '</div>' +
      '<div style="text-align:right;font-family:\'IBM Plex Mono\',monospace;font-variant-numeric:tabular-nums;font-weight:700">' + App._f(r[4]) + '</div>' +
      '</div>';
  }).join('');
  var empty = raw.rows.length === 0;
  var pickHtml = '';
  if (s.meisaiPickOpen) {
    var opts = s.ownNos.map(function (no) {
      var a = App._find(no) || {};
      var active = no === mView.no;
      return '<button data-click="' + onClick(App.pickMeisaiAcct(no)) + '" style="width:100%;display:flex;align-items:center;gap:8px;padding:12px 16px;border:none;border-bottom:1px solid #f2f4f8;background:#fff;cursor:pointer;text-align:left;font-size:12.5px">' +
        '<span style="font-family:\'IBM Plex Mono\',monospace;color:#a06e00;font-weight:700">' + esc(no) + '</span>' +
        '<span style="color:#5f7285">' + esc(typeDisp(a.type) + ' ' + a.branch + '（' + a.bcode + '） ' + no) + '</span>' +
        (active ? '<span style="margin-left:auto;color:#c3a24a;font-weight:900">✓</span>' : '') +
        '</button>';
    }).join('');
    pickHtml = '<div class="popover-backdrop" style="z-index:30" data-click="' + onClick(App.toggleMeisaiPick) + '"></div>' +
      '<div style="position:absolute;top:calc(100% + 6px);left:0;right:0;z-index:40;background:#fff;border:1px solid #e2e7f0;border-radius:12px;box-shadow:0 16px 40px rgba(10,36,114,.16);overflow:hidden;max-height:320px;overflow-y:auto">' + opts + '</div>';
  }
  var typeOpts = [
    ['all', T.typeAll], ['入金', T.txnMap['入金']], ['出金', T.txnMap['出金']], ['振込', T.txnMap['振込']],
    ['融資実行', T.txnMap['融資実行']], ['融資返済', T.txnMap['融資返済']]
  ].map(function (p) { return '<option value="' + p[0] + '">' + esc(p[1]) + '</option>'; }).join('');
  return '<button class="back-link" data-click="' + onClick(App.back) + '">‹ ' + esc(T.backBtn) + '</button>' +
    '<div style="font-size:21px;font-weight:900">' + esc(T.meisaiTitle) + '</div>' +
    '<div style="position:relative">' +
    '<button data-click="' + onClick(App.toggleMeisaiPick) + '" style="width:100%;background:#fff;border:1px solid #e9edf3;border-radius:16px;padding:18px 22px;display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:12px;box-shadow:0 2px 10px rgba(10,36,114,.05);cursor:pointer;text-align:left">' +
    '<div class="row" style="gap:10px;flex-wrap:wrap"><span class="pill">' + esc(typeDisp(mView.type)) + '</span><span style="font-size:12.5px;color:#6b7a90">' + esc(mView.branch) + '（' + esc(mView.bcode) + '）</span><span style="font-size:12.5px;color:#6b7a90;font-family:\'IBM Plex Mono\',monospace">' + esc(mView.no) + '</span><span style="color:#c3a24a;font-size:13px">▾</span></div>' +
    '<div style="text-align:right"><span style="font-size:11.5px;color:#8a97b0;margin-right:8px">' + esc(T.balanceLabel) + '</span><span style="font-size:20px;font-weight:900;font-family:\'IBM Plex Mono\',monospace">' + (s.balHidden ? '¥ ******' : App._f(mView.balance)) + '</span></div>' +
    '</button>' + pickHtml +
    '</div>' +
    '<div class="row" style="align-items:flex-end;gap:10px;flex-wrap:wrap;background:#fff;border:1px solid #e9edf3;border-radius:12px;padding:14px 16px">' +
    '<div class="col" style="gap:4px"><label style="font-size:10.5px;color:#8a97b0;font-weight:700">' + esc(T.mf_kind) + '</label><select data-value="' + s.meisaiType + '" data-onchange="' + onChange(App.onMeisaiType) + '" style="padding:8px 11px;border:1px solid #d3dbe8;border-radius:8px;font-size:13px;background:#fff">' + typeOpts + '</select></div>' +
    '<div class="col" style="gap:4px"><label style="font-size:10.5px;color:#8a97b0;font-weight:700">' + esc(T.mf_from) + '</label><input type="date" value="' + esc(s.meisaiFrom) + '" data-onchange="' + onChange(App.onMeisaiFrom) + '" style="padding:7px 10px;border:1px solid #d3dbe8;border-radius:8px;font-size:13px"></div>' +
    '<div class="col" style="gap:4px"><label style="font-size:10.5px;color:#8a97b0;font-weight:700">' + esc(T.mf_to) + '</label><input type="date" value="' + esc(s.meisaiTo) + '" data-onchange="' + onChange(App.onMeisaiTo) + '" style="padding:7px 10px;border:1px solid #d3dbe8;border-radius:8px;font-size:13px"></div>' +
    '<button data-click="' + onClick(App.meisaiClear) + '" style="background:#f5f7fa;border:1px solid #e2e7f0;color:#5b6b85;font-size:12px;font-weight:700;padding:9px 14px;border-radius:8px;cursor:pointer">' + esc(T.mf_clear) + '</button>' +
    '</div>' +
    '<div class="plain-card" style="padding:0;overflow:hidden">' +
    '<div class="meisai-head"><div>' + esc(T.th_date) + '</div><div>' + esc(T.th_type) + '</div><div style="text-align:center">' + esc(T.mf_kind) + '</div><div style="text-align:right">' + esc(T.th_out) + '</div><div style="text-align:right">' + esc(T.th_in) + '</div><div style="text-align:right">' + esc(T.afterBal) + '</div></div>' +
    '<div style="max-height:462px;overflow-y:auto">' + rowsHtml + '</div>' +
    (empty ? '<div style="padding:28px;text-align:center;font-size:12.5px;color:#8a97b0">' + esc(T.mf_none) + '</div>' : '') +
    '</div>' +
    '<div class="row" style="justify-content:flex-end;gap:10px;flex-wrap:wrap">' +
    '<span style="font-size:12px;color:#8a97b0;font-weight:700">' + esc(T.dl_title) + '</span>' +
    '<select data-value="' + s.dlFormat + '" data-onchange="' + onChange(App.onDlFormat) + '" style="padding:9px 13px;border:1px solid #f0d98a;border-radius:9px;font-size:13px;font-weight:700;color:#a06e00;background:#fff;max-width:130px"><option value="csv">CSV</option><option value="pdf">PDF</option><option value="txt">TXT</option></select>' +
    '<button data-click="' + onClick(App.dlRun) + '" style="display:inline-flex;align-items:center;gap:5px;background:#ffcc00;border:none;color:#1a1a1a;font-size:13px;font-weight:800;padding:9px 18px;border-radius:9px;cursor:pointer">⭳ ' + esc(T.dl_btn) + '</button>' +
    '</div>';
}

/* ============================================================
   Member / Holdings / New account
   ============================================================ */
function tplMember() {
  var T = App.T(), me = App.me(), p = me.prof || {};
  var rows = [
    [T.su_name, me.kanji], [T.su_kana, me.kana], [T.su_birth, p.birth || '—'], [T.su_sex, p.sex || '—'],
    [T.su_zip, p.zip || '—'], [T.su_addr, p.addr || '—'], [T.su_phone, p.phone || '—'], [T.su_email, p.email || '—'], [T.su_job, p.job || '—']
  ].map(function (r) { return '<div class="amt-label">' + esc(r[0]) + '</div><div class="amt-cell">' + esc(r[1]) + '</div>'; }).join('');
  return '<button class="back-link" data-click="' + onClick(App.back) + '">‹ ' + esc(T.backBtn) + '</button>' +
    '<div style="font-size:21px;font-weight:900">' + esc(T.us_member) + '</div>' +
    '<div class="card-box">' +
    '<div style="border:1px solid #eef1f6;border-radius:12px;overflow:hidden"><div class="rowgrid">' + rows + '</div></div>' +
    '<div style="font-size:11px;color:#8a97b0">' + esc(T.us_holdings_hint) + '</div>' +
    '<div class="row"><button class="btn-back" data-click="' + onClick(App.back) + '">' + esc(T.backBtn) + '</button></div>' +
    '</div>';
}
function tplHoldings() {
  var T = App.T(), s = App.state;
  var cards = s.ownNos.map(function (no) {
    var a = App._find(no) || {};
    var isRep = no === s.repAcct;
    var balDisp = s.balHidden ? '¥ ******' : App._f(a.balance);
    var rateDisp = App.rateOf(a.type) + ' %';
    return '<div class="plain-card" style="display:flex;flex-direction:column;gap:12px">' +
      '<div class="row" style="gap:8px;flex-wrap:wrap">' +
      '<span class="star' + (isRep ? ' is-rep' : '') + '" style="font-size:17px" data-click="' + onClick(App.setRep(no)) + '" title="' + esc(T.set_rep) + '">★</span>' +
      '<span style="font-size:14px;font-weight:800">' + esc(typeDisp(a.type)) + '</span>' +
      (isRep ? '<span class="pill-outline" style="padding:1px 8px">' + esc(T.rep_label) + '</span>' : '') +
      '<span style="margin-left:auto;font-size:18px;font-weight:900;font-family:\'IBM Plex Mono\',monospace">' + balDisp + '</span>' +
      '</div>' +
      '<div style="border:1px solid #eef1f6;border-radius:10px;overflow:hidden"><div class="rowgrid" style="font-size:12.5px">' +
      '<div class="amt-label">' + esc(T.su_store) + '</div><div class="amt-cell">' + esc(a.branch) + '（' + esc(a.bcode) + '）</div>' +
      '<div class="amt-label">' + esc(T.su_result_no) + '</div><div class="amt-cell">' + esc(a.no) + '</div>' +
      '<div class="amt-label-strong">' + esc(T.hold_rate) + '</div><div class="amt-cell-strong">' + rateDisp + '</div>' +
      '</div></div>' +
      '</div>';
  }).join('');
  var rateNote = s.lang === 'ko' ? '보통예금 0.20% · 당좌예금 0.05% · 적금 0.30% · 정기예금 0.35%' : '普通預金 0.20% · 当座預金 0.05% · 積立 0.30% · 定期 0.35%';
  return '<button class="back-link" data-click="' + onClick(App.back) + '">‹ ' + esc(T.backBtn) + '</button>' +
    '<div style="font-size:21px;font-weight:900">' + esc(T.hold_title) + '</div>' + cards +
    '<div style="background:#fffbe9;border:1px solid #f0d98a;border-radius:12px;padding:13px 16px;font-size:12px;color:#8a6414;line-height:1.7">' + esc(rateNote) + '<br>' + esc(T.hold_note) + '</div>' +
    '<div class="row" style="gap:10px"><button class="btn-back" data-click="' + onClick(App.back) + '">' + esc(T.backBtn) + '</button><button class="btn-primary" data-click="' + onClick(App.naStart) + '">' + esc(T.us_newacct) + '</button></div>';
}
function tplNaStep1() {
  var T = App.T(), s = App.state, me = App.me();
  var isSave = s.naType === '積立' || s.naType === '定期';
  var amtLabel = s.naType === '積立' ? T.na_monthly : T.na_deposit;
  var m = parseInt((s.naSaveMonthly || '').replace(/[^0-9]/g, ''), 10) || 0, n = parseInt(s.naSaveTerm, 10) || 0;
  var proj = App._saveProject(s.naType, m, n);
  var rateDisp = App.rateOf(s.naType) + ' %';
  var storeOpts = STORES.map(function (o) { return '<option value="' + o.code + '">' + o.code + ' ' + esc(o.name) + '</option>'; }).join('');
  return '<div class="card-box">' +
    '<div style="border:1px solid #eef1f6;border-radius:10px;overflow:hidden"><div class="rowgrid" style="font-size:12.5px">' +
    '<div class="amt-label">' + esc(T.su_name) + '</div><div class="amt-cell">' + esc(me.kanji) + '</div>' +
    '<div class="amt-label">' + esc(T.su_birth) + '</div><div class="amt-cell">' + esc((me.prof && me.prof.birth) || '—') + '</div>' +
    '<div class="amt-label">' + esc(T.su_sex) + '</div><div class="amt-cell">' + esc((me.prof && me.prof.sex) || '—') + '</div>' +
    '</div></div>' +
    '<div style="font-size:11px;color:#8a97b0;margin-top:-6px">' + esc(T.na_fixed_note) + '</div>' +
    '<div style="display:grid;grid-template-columns:130px 1fr;gap:14px 16px;align-items:center;max-width:520px">' +
    '<label class="f-label">' + esc(T.su_type) + '</label><select data-value="' + s.naType + '" data-onchange="' + onChange(App.onNaType) + '" style="padding:10px 13px;border:1px solid #d3dbe8;border-radius:9px;font-size:14px;width:100%;max-width:220px">' + typeOptionsHtml(T, true) + '</select>' +
    '<label class="f-label">' + esc(T.su_store) + '</label><select data-value="' + s.naStore + '" data-onchange="' + onChange(App.onNaStore) + '" style="padding:10px 13px;border:1px solid #d3dbe8;border-radius:9px;font-size:14px;width:100%;max-width:260px">' + storeOpts + '</select>' +
    '<label class="f-label">' + esc(T.hold_rate) + '</label><div style="font-size:14px;font-weight:800;color:#a06e00;font-family:\'IBM Plex Mono\',monospace">' + rateDisp + '</div>' +
    (isSave ? (
      '<label class="f-label">' + esc(T.na_term) + '</label><select data-value="' + s.naSaveTerm + '" data-onchange="' + onChange(App.onNaTerm) + '" style="padding:10px 13px;border:1px solid #d3dbe8;border-radius:9px;font-size:14px;width:100%;max-width:160px"><option value="3">3 ' + esc(T.na_months) + '</option><option value="6">6 ' + esc(T.na_months) + '</option><option value="12">12 ' + esc(T.na_months) + '</option></select>' +
      '<label class="f-label">' + esc(amtLabel) + '</label><div class="row" style="gap:8px"><input value="' + esc(s.naSaveMonthly) + '" data-onchange="' + onChange(App.onNaMonthly) + '" inputmode="numeric" class="inp"><span style="font-size:13px;color:#6b7a90">' + esc(T.yen) + '</span></div>'
    ) : '') +
    '<label class="f-label">' + esc(T.su_pw) + '</label><input type="password" value="' + esc(s.naPw) + '" data-onchange="' + onChange(App.onNaPw) + '" class="inp-full" style="max-width:220px">' +
    '</div>' +
    (isSave ? projectionBox(T, proj) : '') +
    '<div class="row" style="gap:10px"><button class="btn-back" data-click="' + onClick(App.back) + '">' + esc(T.backBtn) + '</button><button class="btn-primary" data-click="' + onClick(App.naConfirm) + '">' + esc(T.su_next) + '</button></div>' +
    '</div>';
}
function tplNaStep2() {
  var T = App.T(), s = App.state, me = App.me();
  var isSave = s.naType === '積立' || s.naType === '定期';
  var storeName = (STORES.find(function (x) { return x.code === s.naStore; }) || STORES[0]).name;
  var m = parseInt((s.naSaveMonthly || '').replace(/[^0-9]/g, ''), 10) || 0, n = parseInt(s.naSaveTerm, 10) || 0;
  var proj = App._saveProject(s.naType, m, n);
  var rows = '<div class="amt-label">' + esc(T.su_name) + '</div><div class="amt-cell">' + esc(me.kanji) + '</div>' +
    '<div class="amt-label">' + esc(T.su_type) + '</div><div class="amt-cell">' + esc(typeDisp(s.naType)) + '</div>' +
    '<div class="amt-label">' + esc(T.su_store) + '</div><div class="amt-cell">' + esc(s.naStore) + ' ' + esc(storeName) + '</div>' +
    '<div class="amt-label">' + esc(T.hold_rate) + '</div><div class="amt-cell">' + App.rateOf(s.naType) + ' %</div>' +
    (isSave ? '<div class="amt-label">' + esc(T.na_term) + '</div><div class="amt-cell">' + esc(s.naSaveTerm) + ' ' + esc(T.na_months) + '</div><div class="amt-label-strong">' + esc(T.na_maturity) + '</div><div class="amt-cell-strong">' + App._f(proj.maturity) + '</div>' : '');
  return '<div class="card-box">' +
    '<div style="font-size:13px;color:#4a5a6a">' + esc(T.confirmLead) + '</div>' +
    '<div style="border:1px solid #eef1f6;border-radius:12px;overflow:hidden"><div class="rowgrid">' + rows + '</div></div>' +
    '<div class="row" style="gap:10px"><button class="btn-back" data-click="' + onClick(App.naBack) + '">' + esc(T.backBtn) + '</button><button class="btn-exec" data-click="' + onClick(App.naExecute) + '">' + esc(T.na_submit) + '</button></div>' +
    '</div>';
}
function tplNaStep3() {
  var T = App.T(), r = App.state.naResult;
  return '<div class="done-box">' +
    '<div class="done-icon">✓</div>' +
    '<div style="font-size:17px;font-weight:900;color:#a06e00">' + esc(T.na_done) + '</div>' +
    '<div style="font-size:12.5px;color:#6b7a90;max-width:420px;line-height:1.7">' + esc(T.na_done_msg) + '</div>' +
    '<div style="border:1px solid #eef1f6;border-radius:12px;overflow:hidden;width:100%;max-width:440px"><div class="rowgrid">' +
    '<div class="amt-label">' + esc(T.su_result_store) + '</div><div class="amt-cell-bold">' + esc(r ? (r.tenban + ' ' + r.store) : '') + '</div>' +
    '<div class="amt-label-strong">' + esc(T.su_result_no) + '</div><div class="amt-cell-strong">' + esc(r ? r.no : '') + '</div>' +
    '<div class="amt-label">' + esc(T.su_result_type) + '</div><div class="amt-cell">' + esc(r ? typeDisp(r.type) : '') + '</div>' +
    '</div></div>' +
    '<button class="btn-primary" data-click="' + onClick(App.naToHome) + '">' + esc(T.toHome) + '</button>' +
    '</div>';
}
function tplNewAcct() {
  var T = App.T(), s = App.state;
  var steps = stepIndicator(s.naStep, [T.na_step1, T.na_step2, T.na_step3]);
  var body = s.naStep === 1 ? tplNaStep1() : s.naStep === 2 ? tplNaStep2() : tplNaStep3();
  return '<button class="back-link" data-click="' + onClick(App.back) + '">‹ ' + esc(T.backBtn) + '</button>' +
    '<div style="font-size:21px;font-weight:900">' + esc(T.na_title) + '</div>' + steps +
    (s.naErr ? '<div class="err-box">⚠ ' + esc(s.naErr) + '</div>' : '') + body;
}

/* ============================================================
   Notices
   ============================================================ */
function tplNoticeNew() {
  var T = App.T(), s = App.state;
  var files = s.ncFiles.length ? '<div class="row" style="gap:6px;flex-wrap:wrap;margin-top:4px">' + s.ncFiles.map(function (f) { return '<span class="file-chip" style="background:#fff8db;color:#a06e00;border-color:#f0d98a">📎 ' + esc(f) + '</span>'; }).join('') + '</div>' : '';
  return '<button class="back-link" data-click="' + onClick(App.goHome) + '">‹ ' + esc(T.toHome) + '</button>' +
    '<div style="font-size:21px;font-weight:900">' + esc(T.nc_title) + '</div>' +
    '<div class="card-box">' +
    '<div style="display:flex;flex-direction:column;gap:6px"><label class="f-label">' + esc(T.nc_f_title) + '</label><input value="' + esc(s.ncTitle) + '" data-onchange="' + onChange(App.onNcTitle) + '" class="inp-full"></div>' +
    '<div style="display:flex;flex-direction:column;gap:6px"><label class="f-label">' + esc(T.nc_f_body) + '</label><textarea rows="5" data-onchange="' + onChange(App.onNcBody) + '" style="padding:10px 13px;border:1px solid #d3dbe8;border-radius:9px;font-size:14px;width:100%;resize:vertical;font-family:inherit">' + esc(s.ncBody) + '</textarea></div>' +
    '<div style="display:flex;flex-direction:column;gap:6px"><label class="f-label">' + esc(T.nc_f_file) + '</label><input type="file" multiple data-onchange="' + onChange(App.onNcFile) + '" style="font-size:13px">' + files + '</div>' +
    '<div class="note-txt">' + esc(T.nc_note) + '</div>' +
    '<div class="row" style="gap:10px"><button class="btn-back" data-click="' + onClick(App.goHome) + '">' + esc(T.backBtn) + '</button><button class="btn-primary" data-click="' + onClick(App.submitNotice) + '">' + esc(T.nc_submit) + '</button></div>' +
    '</div>';
}
function tplNoticeDetail() {
  var T = App.T(), n = App.state.selNotice || {};
  var body = n.body ? '<div style="font-size:13.5px;color:#3a4a66;line-height:1.85;white-space:pre-wrap">' + esc(n.body) + '</div>' : '';
  var files = (n.files && n.files.length) ? '<div style="display:flex;flex-direction:column;gap:7px"><div style="font-size:11.5px;color:#8a97b0;font-weight:700">' + esc(T.nc_f_file) + '</div><div class="row" style="gap:7px;flex-wrap:wrap">' + n.files.map(function (f) { return '<span class="file-chip" style="background:#fff8db;color:#a06e00;border-color:#f0d98a;font-size:12px;padding:5px 11px">📎 ' + esc(f) + '</span>'; }).join('') + '</div></div>' : '';
  return '<button class="back-link" data-click="' + onClick(App.back) + '">‹ ' + esc(T.backBtn) + '</button>' +
    '<div class="card-box">' +
    '<div class="row" style="gap:8px"><span style="font-size:11px;color:#9aa6bb;font-family:\'IBM Plex Mono\',monospace">' + esc(n.date) + '</span><span class="notice-tag">' + esc(n.tag) + '</span></div>' +
    '<div style="font-size:19px;font-weight:900;line-height:1.4">' + esc(n.title) + '</div>' +
    '<div style="height:1px;background:#eef1f6"></div>' +
    body + files +
    '<div class="row" style="gap:10px"><button class="btn-back" data-click="' + onClick(App.back) + '">' + esc(T.backBtn) + '</button></div>' +
    '</div>';
}

/* ============================================================
   Root render
   ============================================================ */
function pageBody() {
  var s = App.state;
  switch (s.page) {
    case 'home': return tplHome();
    case 'transfer': return tplTransfer();
    case 'loan': return tplLoan();
    case 'meisai': return tplMeisai();
    case 'member': return tplMember();
    case 'holdings': return tplHoldings();
    case 'newacct': return tplNewAcct();
    case 'notice_new': return tplNoticeNew();
    case 'notice_detail': return tplNoticeDetail();
    default: return tplHome();
  }
}
function tplOnline() { return tplHeader() + '<main class="app-main">' + pageBody() + '</main>'; }
function tplRoot() { return App.state.isLoggedIn ? tplOnline() : tplAuth(); }

function morphChildren(oldParent, newParent) {
  var oc = Array.prototype.slice.call(oldParent.childNodes);
  var nc = Array.prototype.slice.call(newParent.childNodes);
  var max = Math.max(oc.length, nc.length);
  for (var i = 0; i < max; i++) {
    if (i >= nc.length) { oc[i].remove(); continue; }
    if (i >= oc.length) { oldParent.appendChild(nc[i]); continue; }
    morph(oc[i], nc[i]);
  }
}

var rootEl = null;
function render() {
  REG = { click: {}, change: {} };
  var html = tplRoot();
  var wrap = buildDom(html);
  morphChildren(rootEl, wrap);
}
function delegateClick(el) {
  el.addEventListener('click', function (e) {
    var t = e.target.closest('[data-click]');
    if (!t || !el.contains(t)) return;
    var fn = REG.click[t.getAttribute('data-click')];
    if (fn) fn(e);
  });
}
function delegateChange(el, evtName) {
  el.addEventListener(evtName, function (e) {
    var t = e.target.closest('[data-onchange]');
    if (!t || !el.contains(t)) return;
    var fn = REG.change[t.getAttribute('data-onchange')];
    if (fn) fn(e);
  });
}

document.addEventListener('DOMContentLoaded', function () {
  rootEl = document.getElementById('app');
  delegateClick(rootEl);
  delegateChange(rootEl, 'input');
  delegateChange(rootEl, 'change');
  render();
});

window.App = App; window._appDebug = { esc: esc, fmtYen: fmtYen };
})();
