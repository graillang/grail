"""Generate layout-distinct generic-instance pressure, not caller-root specialization."""

from pathlib import Path

HERE = Path(__file__).resolve().parent


def generate(out: Path, count: int) -> None:
    out.mkdir(parents=True, exist_ok=True)
    header = (HERE / "api.h").read_text().removesuffix("#endif\n")
    mono = (HERE / "specialized.c").read_text()
    stress = '#include "api.h"\n#include <stdlib.h>\n'
    for i in range(count):
        header += (
            f"typedef struct{{uint64_t words[{1 + i % 8}];}} P{i};DECLARE(P{i},p{i})\n"
        )
        mono += f"DEFINE(P{i},p{i},(void)x)\n"
        stress += f"#if ERASED\nstatic const Type t{i}={{sizeof(P{i}),_Alignof(P{i}),0}};\n#endif\n"
    stress += "uint64_t stress(void){uint64_t sum=0;\n"
    for i in range(count):
        stress += f"{{Vec v={{0}};P{i} value={{0}},out;value.words[0]={i};\n"
        stress += (
            f"#if ERASED\ne_push(&v,&value,&t{i});sum+=((P{i}*)e_get(&v,0,&t{i}))->words[0];"
            f"if(!e_pop(&v,&out,&t{i}))abort();e_drop(&v,&t{i});\n#else\n"
            f"m_push_p{i}(&v,value);sum+=m_get_p{i}(&v,0)->words[0];if(!m_pop_p{i}(&v,&out))abort();m_drop_p{i}(&v);\n#endif\n"
            "sum+=out.words[0];}\n"
        )
    stress += "return sum;}\n"
    (out / "api.h").write_text(header + "#endif\n")
    (out / "specialized.c").write_text(mono)
    (out / "stress.c").write_text(stress)
    for name in ["erased.c", "bench.c"]:
        (out / name).write_text((HERE / name).read_text())
