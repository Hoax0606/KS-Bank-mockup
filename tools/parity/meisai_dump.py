#!/usr/bin/env python3
"""COBOL MEISAI.RPT (98byte 고정 + COMP-3) -> 정규화 텍스트.

Java 측 ReportWriter 가 쓰는 MEISAI.TXT 와 **같은 포맷**으로 출력하므로,
그대로 diff 할 수 있다.

    D kouza=1000123 dt=20260801090000 kbn=1 kingaku=30000 zandakaGo=545510 meigi=山田太郎
    T kouza=1000123 risoku=1 tesuryoGoukei=110 kakuteiZan=523401

레이아웃 정본: backend-cobol/cobol/copy/WMEISAI.cpy
    D: X(1) + 9(10) + X(60)UTF8 + X(14) + X(1) + COMP-3(6) + COMP-3(6) = 98
    T: X(1) + 9(10) + COMP-3(6)×3 + X(69)공백                          = 98

사용:
    python meisai_dump.py MEISAI.RPT [> out.txt]
"""
import sys

REC_LEN = 98

# ★출력은 반드시 UTF-8 + LF.
#   Windows 에서 stdout 을 파일로 리다이렉트하면 Python 은 로케일 인코딩(예: cp949)과
#   CRLF 를 쓴다. 그러면 名義(일본어)가 Java 측 UTF-8 파일과 바이트가 달라져
#   값이 같은데도 diff 가 깨진다. COBOL 이 쓰는 MEISAI.RPT 의 名義 자체는 UTF-8 이다.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", newline="\n")


def comp3(b: bytes) -> int:
    """COMP-3(팩10진) -> int. 마지막 바이트의 하위 니블이 부호(D=음수)."""
    digits = []
    for byte in b[:-1]:
        digits.append(byte >> 4)
        digits.append(byte & 0x0F)
    last = b[-1]
    digits.append(last >> 4)
    if any(d > 9 for d in digits):
        raise ValueError(f"invalid packed decimal: {b.hex()}")
    value = int("".join(str(d) for d in digits) or "0")
    return -value if (last & 0x0F) == 0x0D else value


def dump(path: str, out=sys.stdout) -> int:
    """정규화 텍스트를 출력하고, 이상 레코드 수를 돌려준다."""
    with open(path, "rb") as f:
        data = f.read()

    bad = 0
    if len(data) % REC_LEN:
        print(f"? file length {len(data)} is not a multiple of {REC_LEN}",
              file=sys.stderr)
        bad += 1

    for off in range(0, len(data) - (REC_LEN - 1), REC_LEN):
        rec = data[off:off + REC_LEN]
        kubun = rec[0:1].decode("ascii", "replace")
        kouza = rec[1:11].decode("ascii", "replace")
        if kubun == "D":
            meigi = rec[11:71].decode("utf-8", "replace").rstrip()
            dt = rec[71:85].decode("ascii", "replace")
            kbn = rec[85:86].decode("ascii", "replace")
            print(f"D kouza={int(kouza)}"
                  f" dt={dt}"
                  f" kbn={kbn}"
                  f" kingaku={comp3(rec[86:92])}"
                  f" zandakaGo={comp3(rec[92:98])}"
                  f" meigi={meigi}", file=out)
        elif kubun == "T":
            print(f"T kouza={int(kouza)}"
                  f" risoku={comp3(rec[11:17])}"
                  f" tesuryoGoukei={comp3(rec[17:23])}"
                  f" kakuteiZan={comp3(rec[23:29])}", file=out)
        else:
            # 레이아웃 회귀를 조용히 넘기지 않는다
            bad += 1
            print(f"? unknown kubun={kubun!r} at offset {off}", file=out)
    return bad


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    try:
        bad = dump(sys.argv[1])
    except OSError as e:
        print(f"? cannot read: {e}", file=sys.stderr)
        return 2
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
