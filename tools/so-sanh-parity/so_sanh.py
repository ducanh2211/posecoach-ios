#!/usr/bin/env python3
"""So hai tệp số đo ảnh mẫu (bước 6a) — xem README.md cùng thư mục.

    python3 so_sanh.py A.json B.json [--dung-sai 1e-9] [--tuyet-doi] [--ten-a iOS --ten-b Android]

In báo cáo Markdown ra stdout. `--tuyet-doi`: thoát mã 1 nếu có BẤT KỲ khác biệt nào ở phần tính (dùng khi hai tệp
tính từ CÙNG landmark — phải trùng tuyệt đối).
"""
import argparse
import json
import math
import statistics
import sys

# Mốc nhóm góc máy ±15° — `nhomTuGoc` (NhanDienNhap.kt / NhanDienNhap.swift).
MOC_NHOM_GOC = 15.0
# Landmark coi là "thấy" khi tin cậy từ mức này (chỉ để so toạ độ; không phải ngưỡng của app).
VIS_SO = 0.5


def chuan(s):
    """Tên enum theo quy tắc 3b của AGENTS.md: bỏ `_`, không phân biệt hoa thường (`LEFT_SHOULDER` == `leftShoulder`)."""
    return s.replace("_", "").lower() if isinstance(s, str) else s


def nhom_goc(pitch):
    if pitch is None:
        return None
    if pitch <= -MOC_NHOM_GOC:
        return "tren"
    if pitch >= MOC_NHOM_GOC:
        return "duoi"
    return "ngang"


def doc(path):
    with open(path, encoding="utf-8") as f:
        return {it["file"]: it for it in json.load(f)}


def phang(m, tien_to=""):
    """Trải `measurement` thành {tên trường: số | None}. Khoá dict enum được chuẩn hoá."""
    out = {}
    if not isinstance(m, dict):
        return out
    for k, v in m.items():
        ten = tien_to + k
        if isinstance(v, dict):
            for k2, v2 in v.items():
                if isinstance(v2, list):
                    for i, x in enumerate(v2):
                        out[f"{ten}.{chuan(k2)}[{i}]"] = x
                else:
                    out[f"{ten}.{chuan(k2)}"] = v2
        elif isinstance(v, str):
            continue  # framing — so ở phần phân loại
        else:
            out[ten] = v
    return out


def thong_ke(ds):
    if not ds:
        return "—"
    return f"max {max(ds):.3g} · trung vị {statistics.median(ds):.3g}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("a")
    ap.add_argument("b")
    ap.add_argument("--dung-sai", type=float, default=0.0, help="lệch số đo tối đa coi là trùng (mặc định 0)")
    ap.add_argument("--tuyet-doi", action="store_true", help="thoát mã 1 nếu phần tính có khác biệt")
    ap.add_argument("--ten-a", default="A")
    ap.add_argument("--ten-b", default="B")
    o = ap.parse_args()

    A, B = doc(o.a), doc(o.b)
    ta, tb = o.ten_a, o.ten_b
    chung = sorted(set(A) & set(B))
    p = print
    p(f"# So sánh số đo ảnh mẫu — {ta} vs {tb}\n")
    p(f"- {ta}: `{o.a}` ({len(A)} ảnh) · {tb}: `{o.b}` ({len(B)} ảnh) · chung **{len(chung)}**")
    for ten, chi in ((ta, set(A) - set(B)), (tb, set(B) - set(A))):
        if chi:
            p(f"- Chỉ có ở {ten}: {', '.join(sorted(chi))}")
    p("")

    khac_tinh = 0

    # ---------- 1. Số liệu thô ----------
    p("## 1. Số liệu thô (lệch runtime)\n")
    lech_lm, mat_nguoi, lech_vis = [], [], []
    geo = {"pitchDeg": [], "rollDeg": [], "vfovDeg": []}
    doi_nhom, mat_geo = [], []
    mat_khac, lech_yaw_mat = [], []
    for f in chung:
        a, b = A[f], B[f]
        la, lb = a.get("landmarks") or [], b.get("landmarks") or []
        if bool(la) != bool(lb):
            mat_nguoi.append(f)
        elif la and lb:
            d = [max(abs(x[0] - y[0]), abs(x[1] - y[1]))
                 for x, y in zip(la, lb) if x[2] >= VIS_SO and y[2] >= VIS_SO]
            if d:
                lech_lm.append((max(d), f))
            lech_vis.append(max(abs(x[2] - y[2]) for x, y in zip(la, lb)))
        ga, gb = a.get("geocalib"), b.get("geocalib")
        if bool(ga) != bool(gb):
            mat_geo.append(f)
        elif ga and gb:
            for k in geo:
                geo[k].append(abs(ga[k] - gb[k]))
            na, nb = nhom_goc(ga["pitchDeg"]), nhom_goc(gb["pitchDeg"])
            if na != nb:
                doi_nhom.append(f"{f} ({na} → {nb}; {ga['pitchDeg']:.1f}° / {gb['pitchDeg']:.1f}°)")
        fa, fb = a.get("face"), b.get("face")
        if bool(fa) != bool(fb):
            mat_khac.append(f)
        elif fa and fb and fa.get("yawDeg") is not None and fb.get("yawDeg") is not None:
            lech_yaw_mat.append(abs(fa["yawDeg"] - fb["yawDeg"]))

    p("| Đại lượng | Lệch | Ghi chú |\n|---|---|---|")
    p(f"| Landmark x/y (điểm thấy cả hai bên) | {thong_ke([d for d, _ in lech_lm])} | đơn vị khung (0..1) |")
    p(f"| Độ tin cậy landmark | {thong_ke(lech_vis)} | |")
    p(f"| Thấy người một bên, bên kia không | **{len(mat_nguoi)}** ảnh | {', '.join(mat_nguoi[:8])} |")
    for k, v in geo.items():
        p(f"| GeoCalib `{k}` | {thong_ke(v)} | độ |")
    p(f"| GeoCalib chạy một bên | **{len(mat_geo)}** ảnh | {', '.join(mat_geo[:8])} |")
    p(f"| Thấy mặt một bên | **{len(mat_khac)}** ảnh | {', '.join(mat_khac[:8])} |")
    p(f"| Góc mặt `yawDeg` | {thong_ke(lech_yaw_mat)} | độ |")
    if lech_lm:
        p("\nLandmark lệch nhiều nhất: " + ", ".join(f"{f} ({d:.3f})" for d, f in sorted(lech_lm, reverse=True)[:5]))
    p(f"\n**Nhóm góc máy (±{MOC_NHOM_GOC:g}°) đổi: {len(doi_nhom)} ảnh**")
    for x in doi_nhom:
        p(f"- {x}")
    p("")

    # ---------- 2. Phân loại ----------
    p("## 2. Phân loại (đổi kết quả người dùng thấy)\n")
    doi = {"cổng 🔴/🟡/🟢": [], "lớp khung hình": [], "cảnh báo cổng": [], "lý do từ chối": [],
           "tiêu chí bật": [], "tiêu chí bỏ qua": [], "nhóm dáng": [], "kiểu chụp trên": []}
    for f in chung:
        ga, gb = A[f].get("gate") or {}, B[f].get("gate") or {}
        pa, pb = A[f].get("profile") or {}, B[f].get("profile") or {}
        cap = [
            ("cổng 🔴/🟡/🟢", ga.get("level"), gb.get("level")),
            ("lớp khung hình", chuan(ga.get("framing")), chuan(gb.get("framing"))),
            ("cảnh báo cổng", sorted(ga.get("warnings") or []), sorted(gb.get("warnings") or [])),
            ("lý do từ chối", ga.get("reason"), gb.get("reason")),
            ("tiêu chí bật", sorted(pa.get("active") or []), sorted(pb.get("active") or [])),
            ("tiêu chí bỏ qua", sorted((pa.get("skipped") or {}).items()), sorted((pb.get("skipped") or {}).items())),
            ("nhóm dáng", sorted(map(chuan, pa.get("poseGroups") or [])), sorted(map(chuan, pb.get("poseGroups") or []))),
            ("kiểu chụp trên", chuan(pa.get("kieuChupTren")), chuan(pb.get("kieuChupTren"))),
        ]
        for ten, x, y in cap:
            if x != y:
                doi[ten].append(f"{f}: {x} → {y}")
    p("| Mục | Số ảnh đổi |\n|---|---|")
    for k, v in doi.items():
        p(f"| {k} | **{len(v)}** |")
        khac_tinh += len(v)
    for k, v in doi.items():
        if v:
            p(f"\n### {k}\n")
            for x in v[:30]:
                p(f"- {x}")
    p("")

    # ---------- 3. Số đo ----------
    p(f"## 3. Số đo (`measurement`, dung sai {o.dung_sai:g})\n")
    truong = {}
    for f in chung:
        ma, mb = phang(A[f].get("measurement")), phang(B[f].get("measurement"))
        for k in set(ma) | set(mb):
            x, y = ma.get(k), mb.get(k)
            t = truong.setdefault(k, {"lech": [], "vuot": [], "mot_ben": []})
            if (x is None) != (y is None):
                t["mot_ben"].append(f)
            elif x is not None and y is not None:
                d = abs(x - y)
                t["lech"].append(d)
                if d > o.dung_sai or math.isnan(d):
                    t["vuot"].append((d, f))
    p("| Trường | So được | Lệch | Vượt dung sai | Đo được một bên |\n|---|---|---|---|---|")
    for k in sorted(truong):
        t = truong[k]
        if not t["lech"] and not t["mot_ben"]:
            continue
        khac_tinh += len(t["vuot"]) + len(t["mot_ben"])
        vuot = len(t["vuot"])
        p(f"| `{k}` | {len(t['lech'])} | {thong_ke(t['lech'])} | {'**' + str(vuot) + '**' if vuot else 0} "
          f"| {'**' + str(len(t['mot_ben'])) + '**' if t['mot_ben'] else 0} |")
    p("")
    p(f"**Tổng khác biệt ở phần tính: {khac_tinh}**")
    if o.tuyet_doi and khac_tinh:
        sys.exit(1)


if __name__ == "__main__":
    main()
