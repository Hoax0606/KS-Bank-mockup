/* UTF2SJIS - GnuCOBOL callable bridge: UTF-8 bytes -> Shift-JIS(CP932) bytes.
 * COBOL: CALL "UTF2SJIS" USING IN(Xn) INLEN(9(4)disp) OUT(Xn) OUTLEN(9(4)disp)
 *   IN/INLEN  : 変換元 UTF-8 バイトとその長さ(最大 8000)。
 *   OUT/OUTLEN: 呼び出し前に OUTLEN へ OUT バッファの容量を入れておくこと。
 *               戻り値では実際に書いたバイト数に上書きされる。
 * RETURN-CODE: 0=成功 / 1=iconv 初期化失敗(CP932 未対応環境) /
 *              2=不正な UTF-8 または CP932 で表現できない文字を含む(OUTLEN=0)。
 *
 * 旧 JEFCONV.c(127.0.0.1:9099 常駐サービスに接続する EBCDIC/JEF ブリッジ、
 * 2026-07-30 削除)と同じ長さ渡し規約(PIC 9(4) DISPLAY をテキスト数字として
 * rd4/wr4 で読み書き — バイナリ COMP のレイアウト不一致を避ける、このコード
 * ベース既存の慣例)を踏襲するが、ネットワーク往復は無い。Shift-JIS(CP932) は
 * glibc が標準で提供する変換なので常駐サービスは不要。 */
#include <iconv.h>

static int rd4(const char *p) {
    return (p[0]-'0')*1000 + (p[1]-'0')*100 + (p[2]-'0')*10 + (p[3]-'0');
}

static void wr4(char *p, int v) {
    if (v < 0) v = 0;
    if (v > 9999) v = 9999;
    p[0] = '0' + (v/1000)%10;
    p[1] = '0' + (v/100)%10;
    p[2] = '0' + (v/10)%10;
    p[3] = '0' + v%10;
}

int UTF2SJIS(char *in, char *inlen, char *out, char *outlen) {
    int n = rd4(inlen);
    if (n < 0) n = 0;
    if (n > 8000) n = 8000;
    int cap = rd4(outlen);
    if (cap <= 0 || cap > 8000) cap = 8000;

    iconv_t cd = iconv_open("CP932", "UTF-8");
    if (cd == (iconv_t)-1) {
        wr4(outlen, 0);
        return 1;
    }

    char *inp = in;
    size_t inleft = (size_t)n;
    char *outp = out;
    size_t outleft = (size_t)cap;

    size_t r = iconv(cd, &inp, &inleft, &outp, &outleft);
    iconv_close(cd);

    if (r == (size_t)-1 || inleft != 0) {
        wr4(outlen, 0);
        return 2;
    }

    wr4(outlen, (int)(cap - outleft));
    return 0;
}
